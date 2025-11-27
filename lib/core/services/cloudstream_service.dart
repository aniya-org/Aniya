import 'dart:convert';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../domain/entities/extension_entity.dart';
import '../data/models/cloudstream_repository_model.dart';
import '../error/failures.dart';
import '../utils/logger.dart';

/// Service for handling CloudStream-specific operations
///
/// This service provides methods for:
/// - Fetching CloudStream repositories and plugin lists
/// - Downloading and installing .cs3 extension files
/// - Managing CloudStream extension lifecycle
///
/// Requirements: 12.1, 12.2, 12.3, 12.4
class CloudStreamService {
  final http.Client httpClient;

  /// Timeout for HTTP requests
  static const Duration _requestTimeout = Duration(seconds: 30);

  /// Directory name for CloudStream extensions
  static const String _extensionsDir = 'cloudstream_extensions';

  CloudStreamService({required this.httpClient});

  /// Fetches a CloudStream repository manifest
  ///
  /// [repoUrl] - URL to the CloudStream repository manifest
  ///
  /// Returns the repository model or a failure
  /// Requirements: 12.1
  Future<Either<Failure, CloudStreamRepositoryModel>> fetchRepository(
    String repoUrl,
  ) async {
    try {
      final uri = Uri.tryParse(repoUrl);
      if (uri == null || !uri.hasScheme) {
        return Left(ValidationFailure('Invalid repository URL: $repoUrl'));
      }

      Logger.info(
        'Fetching CloudStream repository from $repoUrl',
        tag: 'CloudStreamService',
      );

      final response = await httpClient.get(uri).timeout(_requestTimeout);

      if (response.statusCode != 200) {
        return Left(
          ServerFailure(
            'Failed to fetch repository (HTTP ${response.statusCode})',
          ),
        );
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return Left(ValidationFailure('Invalid repository format'));
      }

      final repository = CloudStreamRepositoryModel.fromJson(decoded);

      if (!repository.isValid) {
        return Left(ValidationFailure('Repository has no plugin lists'));
      }

      Logger.info(
        'Fetched CloudStream repository: ${repository.name}',
        tag: 'CloudStreamService',
      );

      return Right(repository);
    } on FormatException catch (e) {
      Logger.error('JSON parsing error', tag: 'CloudStreamService', error: e);
      return Left(ValidationFailure('Invalid JSON: ${e.message}'));
    } on http.ClientException catch (e) {
      Logger.error('HTTP client error', tag: 'CloudStreamService', error: e);
      return Left(NetworkFailure('Network error: ${e.message}'));
    } catch (e) {
      Logger.error(
        'Unexpected error fetching repository',
        tag: 'CloudStreamService',
        error: e,
      );
      return Left(UnknownFailure('Failed to fetch repository: $e'));
    }
  }

  /// Fetches plugins from a CloudStream plugin list URL
  ///
  /// [pluginListUrl] - URL to the plugin list JSON
  ///
  /// Returns a list of plugins or a failure
  /// Requirements: 12.1
  Future<Either<Failure, List<CloudStreamPluginModel>>> fetchPluginList(
    String pluginListUrl,
  ) async {
    try {
      final uri = Uri.tryParse(pluginListUrl);
      if (uri == null || !uri.hasScheme) {
        return Left(
          ValidationFailure('Invalid plugin list URL: $pluginListUrl'),
        );
      }

      Logger.info(
        'Fetching CloudStream plugin list from $pluginListUrl',
        tag: 'CloudStreamService',
      );

      final response = await httpClient.get(uri).timeout(_requestTimeout);

      if (response.statusCode != 200) {
        return Left(
          ServerFailure(
            'Failed to fetch plugin list (HTTP ${response.statusCode})',
          ),
        );
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! List) {
        return Left(ValidationFailure('Plugin list must be a JSON array'));
      }

      final plugins = <CloudStreamPluginModel>[];

      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          try {
            final plugin = CloudStreamPluginModel.fromJson(item);
            if (plugin.isActive) {
              plugins.add(plugin);
            }
          } catch (e) {
            Logger.warning(
              'Failed to parse plugin: $e',
              tag: 'CloudStreamService',
            );
          }
        }
      }

      Logger.info(
        'Fetched ${plugins.length} CloudStream plugins',
        tag: 'CloudStreamService',
      );

      return Right(plugins);
    } on FormatException catch (e) {
      Logger.error('JSON parsing error', tag: 'CloudStreamService', error: e);
      return Left(ValidationFailure('Invalid JSON: ${e.message}'));
    } on http.ClientException catch (e) {
      Logger.error('HTTP client error', tag: 'CloudStreamService', error: e);
      return Left(NetworkFailure('Network error: ${e.message}'));
    } catch (e) {
      Logger.error(
        'Unexpected error fetching plugin list',
        tag: 'CloudStreamService',
        error: e,
      );
      return Left(UnknownFailure('Failed to fetch plugin list: $e'));
    }
  }

  /// Downloads a CloudStream extension (.cs3 file)
  ///
  /// [plugin] - The plugin to download
  ///
  /// Returns the path to the downloaded file or a failure
  /// Requirements: 12.2, 12.3
  Future<Either<Failure, String>> downloadExtension(
    CloudStreamPluginModel plugin,
  ) async {
    try {
      if (plugin.url.isEmpty) {
        return Left(ValidationFailure('Plugin URL is empty'));
      }

      final uri = Uri.tryParse(plugin.url);
      if (uri == null || !uri.hasScheme) {
        return Left(ValidationFailure('Invalid plugin URL: ${plugin.url}'));
      }

      Logger.info(
        'Downloading CloudStream extension: ${plugin.name}',
        tag: 'CloudStreamService',
      );

      final response = await httpClient.get(uri).timeout(_requestTimeout);

      if (response.statusCode != 200) {
        return Left(
          ServerFailure(
            'Failed to download extension (HTTP ${response.statusCode})',
          ),
        );
      }

      // Get the extensions directory
      final appDir = await getApplicationDocumentsDirectory();
      final extensionsDir = Directory(path.join(appDir.path, _extensionsDir));

      if (!await extensionsDir.exists()) {
        await extensionsDir.create(recursive: true);
      }

      // Determine filename from URL or plugin name
      final filename = plugin.url.split('/').last.isNotEmpty
          ? plugin.url.split('/').last
          : '${plugin.internalName}.cs3';

      final filePath = path.join(extensionsDir.path, filename);
      final file = File(filePath);

      await file.writeAsBytes(response.bodyBytes);

      Logger.info(
        'Downloaded CloudStream extension to: $filePath',
        tag: 'CloudStreamService',
      );

      return Right(filePath);
    } on http.ClientException catch (e) {
      Logger.error(
        'HTTP client error downloading extension',
        tag: 'CloudStreamService',
        error: e,
      );
      return Left(NetworkFailure('Network error: ${e.message}'));
    } catch (e) {
      Logger.error(
        'Unexpected error downloading extension',
        tag: 'CloudStreamService',
        error: e,
      );
      return Left(UnknownFailure('Failed to download extension: $e'));
    }
  }

  /// Installs a CloudStream extension from a downloaded file
  ///
  /// [filePath] - Path to the downloaded .cs3 file
  /// [plugin] - The plugin metadata
  ///
  /// Returns success or a failure
  /// Requirements: 12.2, 12.3
  Future<Either<Failure, Unit>> installExtension(
    String filePath,
    CloudStreamPluginModel plugin,
  ) async {
    try {
      final file = File(filePath);

      if (!await file.exists()) {
        return Left(ValidationFailure('Extension file not found: $filePath'));
      }

      // The actual installation is handled by the extension bridge
      // This method prepares the file for the bridge to install
      Logger.info(
        'CloudStream extension ready for installation: ${plugin.name}',
        tag: 'CloudStreamService',
      );

      return const Right(unit);
    } catch (e) {
      Logger.error(
        'Error installing CloudStream extension',
        tag: 'CloudStreamService',
        error: e,
      );
      return Left(UnknownFailure('Failed to install extension: $e'));
    }
  }

  /// Uninstalls a CloudStream extension
  ///
  /// [extensionId] - The extension ID to uninstall
  ///
  /// Returns success or a failure
  Future<Either<Failure, Unit>> uninstallExtension(String extensionId) async {
    try {
      // Get the extensions directory
      final appDir = await getApplicationDocumentsDirectory();
      final extensionsDir = Directory(path.join(appDir.path, _extensionsDir));

      if (!await extensionsDir.exists()) {
        return const Right(unit); // Nothing to uninstall
      }

      // Find and delete the extension file
      final files = await extensionsDir.list().toList();
      for (final entity in files) {
        if (entity is File) {
          final filename = path.basename(entity.path);
          if (filename.contains(extensionId)) {
            await entity.delete();
            Logger.info(
              'Deleted CloudStream extension file: $filename',
              tag: 'CloudStreamService',
            );
          }
        }
      }

      return const Right(unit);
    } catch (e) {
      Logger.error(
        'Error uninstalling CloudStream extension',
        tag: 'CloudStreamService',
        error: e,
      );
      return Left(UnknownFailure('Failed to uninstall extension: $e'));
    }
  }

  /// Gets all extensions from a CloudStream repository
  ///
  /// [repoUrl] - URL to the CloudStream repository
  ///
  /// Returns a list of extension entities or a failure
  /// Requirements: 12.1, 12.4
  Future<Either<Failure, List<ExtensionEntity>>> getExtensionsFromRepository(
    String repoUrl,
  ) async {
    try {
      // First, try to fetch as a repository manifest
      final repoResult = await fetchRepository(repoUrl);

      return await repoResult.fold(
        (failure) async {
          // If it's not a manifest, try to fetch as a direct plugin list
          final pluginsResult = await fetchPluginList(repoUrl);
          return pluginsResult.fold(
            (failure) => Left(failure),
            (plugins) =>
                Right(plugins.map((p) => p.toExtensionEntity()).toList()),
          );
        },
        (repository) async {
          // Fetch all plugin lists from the repository
          final allExtensions = <ExtensionEntity>[];

          for (final pluginListUrl in repository.pluginLists) {
            final pluginsResult = await fetchPluginList(pluginListUrl);
            pluginsResult.fold(
              (failure) {
                Logger.warning(
                  'Failed to fetch plugin list: $pluginListUrl',
                  tag: 'CloudStreamService',
                );
              },
              (plugins) {
                allExtensions.addAll(plugins.map((p) => p.toExtensionEntity()));
              },
            );
          }

          return Right(allExtensions);
        },
      );
    } catch (e) {
      Logger.error(
        'Error getting extensions from repository',
        tag: 'CloudStreamService',
        error: e,
      );
      return Left(UnknownFailure('Failed to get extensions: $e'));
    }
  }

  /// Maps CloudStream tvTypes to ItemType
  ///
  /// Supports all CloudStream content types:
  /// - anime, movie, tv_show, cartoon, documentary, livestream
  ///
  /// Requirements: 12.4
  static ItemType mapTvTypeToItemType(String tvType) {
    switch (tvType.toLowerCase()) {
      case 'anime':
      case 'animemovie':
      case 'ova':
        return ItemType.anime;
      case 'movie':
        return ItemType.movie;
      case 'tvseries':
      case 'tvshow':
      case 'tv_show':
        return ItemType.tvShow;
      case 'cartoon':
        return ItemType.cartoon;
      case 'documentary':
        return ItemType.documentary;
      case 'live':
      case 'livestream':
        return ItemType.livestream;
      case 'manga':
        return ItemType.manga;
      case 'novel':
        return ItemType.novel;
      case 'nsfw':
        return ItemType.nsfw;
      default:
        return ItemType.anime; // Default to anime for video content
    }
  }
}
