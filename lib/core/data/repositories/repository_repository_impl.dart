import 'dart:convert';
import 'package:dartz/dartz.dart';
import 'package:http/http.dart' as http;

import '../../domain/entities/extension_entity.dart';
import '../../domain/repositories/repository_repository.dart';
import '../../error/failures.dart';
import '../../error/exceptions.dart';
import '../../utils/logger.dart';
import '../datasources/repository_local_data_source.dart';
import '../models/repository_config_model.dart';
import '../models/extension_model.dart';
import '../models/cloudstream_repository_model.dart';

/// Implementation of RepositoryRepository
/// Handles repository configuration persistence and extension fetching
class RepositoryRepositoryImpl implements RepositoryRepository {
  final RepositoryLocalDataSource localDataSource;
  final http.Client httpClient;

  /// Timeout for HTTP requests
  static const Duration _requestTimeout = Duration(seconds: 30);

  RepositoryRepositoryImpl({
    required this.localDataSource,
    required this.httpClient,
  });

  @override
  Future<Either<Failure, RepositoryConfig>> getRepositoryConfig(
    ExtensionType type,
  ) async {
    try {
      final config = await localDataSource.getRepositoryConfig(type);
      return Right(config ?? const RepositoryConfig.empty());
    } on StorageException catch (e) {
      Logger.error(
        'Failed to get repository config',
        tag: 'RepositoryRepository',
        error: e,
      );
      return Left(StorageFailure(e.message));
    } catch (e) {
      Logger.error(
        'Unexpected error getting repository config',
        tag: 'RepositoryRepository',
        error: e,
      );
      return Left(UnknownFailure('Failed to get repository config: $e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> saveRepositoryConfig(
    ExtensionType type,
    RepositoryConfig config,
  ) async {
    try {
      await localDataSource.saveRepositoryConfig(type, config);
      Logger.info(
        'Saved repository config for ${type.name}',
        tag: 'RepositoryRepository',
      );
      return const Right(unit);
    } on StorageException catch (e) {
      Logger.error(
        'Failed to save repository config',
        tag: 'RepositoryRepository',
        error: e,
      );
      return Left(StorageFailure(e.message));
    } catch (e) {
      Logger.error(
        'Unexpected error saving repository config',
        tag: 'RepositoryRepository',
        error: e,
      );
      return Left(UnknownFailure('Failed to save repository config: $e'));
    }
  }

  @override
  Future<Either<Failure, List<ExtensionEntity>>> fetchExtensionsFromRepo(
    String repoUrl,
    ItemType itemType,
    ExtensionType extensionType,
  ) async {
    try {
      // Validate URL
      final uri = Uri.tryParse(repoUrl);
      if (uri == null || !uri.hasScheme) {
        return Left(ValidationFailure('Invalid repository URL: $repoUrl'));
      }

      Logger.info(
        'Fetching extensions from $repoUrl',
        tag: 'RepositoryRepository',
      );

      // Make HTTP request
      final response = await httpClient.get(uri).timeout(_requestTimeout);

      // Handle HTTP errors
      if (response.statusCode != 200) {
        final errorMessage = _getHttpErrorMessage(response.statusCode);
        Logger.error(
          'HTTP error fetching extensions: ${response.statusCode}',
          tag: 'RepositoryRepository',
        );
        return Left(
          ServerFailure('$errorMessage (HTTP ${response.statusCode})'),
        );
      }

      // Parse JSON response
      final extensions = _parseExtensionsJson(
        response.body,
        itemType,
        extensionType,
      );

      Logger.info(
        'Fetched ${extensions.length} extensions from $repoUrl',
        tag: 'RepositoryRepository',
      );

      return Right(extensions);
    } on FormatException catch (e) {
      Logger.error('JSON parsing error', tag: 'RepositoryRepository', error: e);
      return Left(ValidationFailure('Invalid JSON response: ${e.message}'));
    } on http.ClientException catch (e) {
      Logger.error('HTTP client error', tag: 'RepositoryRepository', error: e);
      return Left(NetworkFailure('Network error: ${e.message}'));
    } catch (e) {
      Logger.error(
        'Unexpected error fetching extensions',
        tag: 'RepositoryRepository',
        error: e,
      );
      return Left(UnknownFailure('Failed to fetch extensions: $e'));
    }
  }

  @override
  List<ExtensionEntity> aggregateExtensions(
    List<List<ExtensionEntity>> extensionLists,
  ) {
    final seenIds = <String>{};
    final aggregated = <ExtensionEntity>[];

    for (final list in extensionLists) {
      for (final extension in list) {
        if (!seenIds.contains(extension.id)) {
          seenIds.add(extension.id);
          aggregated.add(extension);
        }
      }
    }

    return aggregated;
  }

  /// Parse extensions from JSON response
  List<ExtensionEntity> _parseExtensionsJson(
    String jsonString,
    ItemType itemType,
    ExtensionType extensionType,
  ) {
    final dynamic decoded = jsonDecode(jsonString);
    final extensions = <ExtensionEntity>[];

    // Handle different JSON formats
    if (decoded is List) {
      // Direct array of extensions (CloudStream plugin list format)
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          // Check if this is a CloudStream plugin format
          if (extensionType == ExtensionType.cloudstream &&
              item.containsKey('internalName')) {
            final plugin = CloudStreamPluginModel.fromJson(item);
            if (plugin.isActive) {
              extensions.add(plugin.toExtensionEntity());
            }
          } else {
            final extension = _parseExtensionItem(
              item,
              itemType,
              extensionType,
            );
            if (extension != null) {
              extensions.add(extension);
            }
          }
        }
      }
    } else if (decoded is Map<String, dynamic>) {
      // CloudStream repository manifest format with pluginLists
      if (decoded.containsKey('pluginLists')) {
        // This is a CloudStream repository manifest
        // The pluginLists need to be fetched separately
        // Return empty here - use fetchCloudStreamRepository instead
        Logger.info(
          'CloudStream repository manifest detected, use fetchCloudStreamRepository',
          tag: 'RepositoryRepository',
        );
      } else if (decoded.containsKey('extensions')) {
        final extensionsList = decoded['extensions'] as List?;
        if (extensionsList != null) {
          for (final item in extensionsList) {
            if (item is Map<String, dynamic>) {
              final extension = _parseExtensionItem(
                item,
                itemType,
                extensionType,
              );
              if (extension != null) {
                extensions.add(extension);
              }
            }
          }
        }
      }
    }

    return extensions;
  }

  /// Fetches extensions from a CloudStream repository
  ///
  /// CloudStream repositories have a manifest format with pluginLists
  /// that point to separate JSON files containing the actual plugins.
  ///
  /// Requirements: 12.1
  Future<Either<Failure, List<ExtensionEntity>>> fetchCloudStreamRepository(
    String repoUrl,
  ) async {
    try {
      // Validate URL
      final uri = Uri.tryParse(repoUrl);
      if (uri == null || !uri.hasScheme) {
        return Left(ValidationFailure('Invalid repository URL: $repoUrl'));
      }

      Logger.info(
        'Fetching CloudStream repository from $repoUrl',
        tag: 'RepositoryRepository',
      );

      // Fetch the repository manifest
      final response = await httpClient.get(uri).timeout(_requestTimeout);

      if (response.statusCode != 200) {
        final errorMessage = _getHttpErrorMessage(response.statusCode);
        return Left(
          ServerFailure('$errorMessage (HTTP ${response.statusCode})'),
        );
      }

      final dynamic decoded = jsonDecode(response.body);

      // Check if this is a CloudStream repository manifest
      if (decoded is Map<String, dynamic> &&
          decoded.containsKey('pluginLists')) {
        final manifest = CloudStreamRepositoryModel.fromJson(decoded);

        if (!manifest.isValid) {
          return Left(
            ValidationFailure('Invalid CloudStream repository manifest'),
          );
        }

        // Fetch all plugin lists
        final allExtensions = <ExtensionEntity>[];

        for (final pluginListUrl in manifest.pluginLists) {
          try {
            final pluginsResult = await _fetchCloudStreamPluginList(
              pluginListUrl,
            );
            pluginsResult.fold((failure) {
              Logger.warning(
                'Failed to fetch plugin list from $pluginListUrl: $failure',
                tag: 'RepositoryRepository',
              );
            }, (extensions) => allExtensions.addAll(extensions));
          } catch (e) {
            Logger.warning(
              'Error fetching plugin list from $pluginListUrl: $e',
              tag: 'RepositoryRepository',
            );
          }
        }

        Logger.info(
          'Fetched ${allExtensions.length} CloudStream extensions from $repoUrl',
          tag: 'RepositoryRepository',
        );

        return Right(allExtensions);
      } else if (decoded is List) {
        // Direct plugin list format
        final extensions = _parseExtensionsJson(
          response.body,
          ItemType.anime, // Default, will be determined by tvTypes
          ExtensionType.cloudstream,
        );
        return Right(extensions);
      }

      return Left(
        ValidationFailure('Unrecognized CloudStream repository format'),
      );
    } on FormatException catch (e) {
      Logger.error(
        'JSON parsing error for CloudStream repository',
        tag: 'RepositoryRepository',
        error: e,
      );
      return Left(ValidationFailure('Invalid JSON response: ${e.message}'));
    } on http.ClientException catch (e) {
      Logger.error(
        'HTTP client error for CloudStream repository',
        tag: 'RepositoryRepository',
        error: e,
      );
      return Left(NetworkFailure('Network error: ${e.message}'));
    } catch (e) {
      Logger.error(
        'Unexpected error fetching CloudStream repository',
        tag: 'RepositoryRepository',
        error: e,
      );
      return Left(UnknownFailure('Failed to fetch CloudStream repository: $e'));
    }
  }

  /// Fetches a CloudStream plugin list from a URL
  ///
  /// Plugin lists are JSON arrays of CloudStreamPluginModel objects.
  Future<Either<Failure, List<ExtensionEntity>>> _fetchCloudStreamPluginList(
    String pluginListUrl,
  ) async {
    try {
      final uri = Uri.tryParse(pluginListUrl);
      if (uri == null || !uri.hasScheme) {
        return Left(
          ValidationFailure('Invalid plugin list URL: $pluginListUrl'),
        );
      }

      final response = await httpClient.get(uri).timeout(_requestTimeout);

      if (response.statusCode != 200) {
        final errorMessage = _getHttpErrorMessage(response.statusCode);
        return Left(
          ServerFailure('$errorMessage (HTTP ${response.statusCode})'),
        );
      }

      final dynamic decoded = jsonDecode(response.body);

      if (decoded is! List) {
        return Left(ValidationFailure('Plugin list must be a JSON array'));
      }

      final extensions = <ExtensionEntity>[];

      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          try {
            final plugin = CloudStreamPluginModel.fromJson(item);
            if (plugin.isActive && plugin.url.isNotEmpty) {
              extensions.add(plugin.toExtensionEntity());
            }
          } catch (e) {
            Logger.warning(
              'Failed to parse CloudStream plugin: $e',
              tag: 'RepositoryRepository',
            );
          }
        }
      }

      return Right(extensions);
    } catch (e) {
      Logger.error(
        'Error fetching CloudStream plugin list',
        tag: 'RepositoryRepository',
        error: e,
      );
      return Left(UnknownFailure('Failed to fetch plugin list: $e'));
    }
  }

  /// Parse a single extension item from JSON
  ExtensionEntity? _parseExtensionItem(
    Map<String, dynamic> json,
    ItemType itemType,
    ExtensionType extensionType,
  ) {
    try {
      // Handle different JSON field names from various sources
      final id = json['id'] ?? json['internalName'] ?? json['pkg'] ?? '';
      final name = json['name'] ?? json['title'] ?? '';
      final version =
          json['version']?.toString() ??
          json['versionName']?.toString() ??
          '1.0.0';
      final language = json['language'] ?? json['lang'] ?? 'en';
      final iconUrl = json['iconUrl'] ?? json['icon'];
      final apkUrl = json['url'] ?? json['apkUrl'] ?? json['apk'];
      final description = json['description'];
      final isNsfw = json['isNsfw'] ?? json['nsfw'] ?? false;

      if (id.isEmpty || name.isEmpty) {
        return null;
      }

      return ExtensionModel(
        id: id.toString(),
        name: name.toString(),
        version: version,
        type: extensionType,
        itemType: itemType,
        language: language.toString(),
        isInstalled: false,
        isNsfw: isNsfw is bool ? isNsfw : false,
        iconUrl: iconUrl?.toString(),
        apkUrl: apkUrl?.toString(),
        description: description?.toString(),
      );
    } catch (e) {
      Logger.warning(
        'Failed to parse extension item: $e',
        tag: 'RepositoryRepository',
      );
      return null;
    }
  }

  /// Get human-readable error message for HTTP status codes
  String _getHttpErrorMessage(int statusCode) {
    switch (statusCode) {
      case 400:
        return 'Bad request';
      case 401:
        return 'Unauthorized';
      case 403:
        return 'Forbidden';
      case 404:
        return 'Repository not found';
      case 500:
        return 'Server error';
      case 502:
        return 'Bad gateway';
      case 503:
        return 'Service unavailable';
      default:
        return 'Request failed';
    }
  }
}
