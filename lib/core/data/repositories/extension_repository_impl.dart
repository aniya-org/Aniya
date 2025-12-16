import 'package:dartz/dartz.dart';
import 'package:dartotsu_extension_bridge/ExtensionManager.dart' as bridge;
import 'package:dartotsu_extension_bridge/Models/Source.dart';

import '../../domain/entities/extension_entity.dart' as domain;
import '../../domain/repositories/extension_repository.dart';
import '../../error/failures.dart';
import '../../error/exceptions.dart';
import '../../constants/default_repositories.dart';
import '../datasources/extension_data_source.dart';

/// Implementation of ExtensionRepository
/// Handles extension management with validation and error handling
class ExtensionRepositoryImpl implements ExtensionRepository {
  final ExtensionDataSource dataSource;

  ExtensionRepositoryImpl({required this.dataSource});

  @override
  Future<Either<Failure, List<domain.ExtensionEntity>>> getAvailableExtensions(
    domain.ExtensionType type, {
    List<String>? repos,
  }) async {
    try {
      final extensions = <domain.ExtensionEntity>[];
      final bridgeType = _mapEntityTypeToBridgeType(type);

      // Use default repository URLs for Aniyomi if none provided
      List<String>? reposToUse = repos;
      if ((repos == null || repos.isEmpty) && type == domain.ExtensionType.aniyomi) {
        reposToUse = [DefaultRepositories.aniyomiAnimeRepo];
      }

      // Get available extensions for all item types
      // Pass repository URLs to fetch extensions from configured repos
      for (final itemType in ItemType.values) {
        try {
          final results = await dataSource.getAvailableExtensions(
            bridgeType,
            itemType,
            repos: reposToUse,
          );
          extensions.addAll(results.map((e) => e.toEntity()));
        } catch (e) {
          // Continue with other item types if one fails
          continue;
        }
      }

      return Right(extensions);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ExtensionException catch (e) {
      return Left(ExtensionFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get available extensions: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, List<domain.ExtensionEntity>>> getInstalledExtensions(
    domain.ExtensionType type,
  ) async {
    try {
      final extensions = <domain.ExtensionEntity>[];
      final bridgeType = _mapEntityTypeToBridgeType(type);

      // Get installed extensions for all item types
      for (final itemType in ItemType.values) {
        try {
          final results = await dataSource.getInstalledExtensions(
            bridgeType,
            itemType,
          );
          extensions.addAll(results.map((e) => e.toEntity()));
        } catch (e) {
          // Continue with other item types if one fails
          continue;
        }
      }

      return Right(extensions);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on ExtensionException catch (e) {
      return Left(ExtensionFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get installed extensions: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, Unit>> installExtension(
    String extensionId,
    domain.ExtensionType type,
  ) async {
    try {
      // Validate extension before installation
      final validationResult = await _validateExtension(extensionId, type);
      if (validationResult != null) {
        return Left(validationResult);
      }

      // Find the extension source with repository URLs
      final source = await _findExtensionSource(extensionId, type);
      if (source == null) {
        return Left(ExtensionFailure('Extension not found: $extensionId'));
      }

      final bridgeType = _mapEntityTypeToBridgeType(type);

      // Install the extension
      await dataSource.installExtension(source, bridgeType);

      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on ExtensionException catch (e) {
      return Left(ExtensionFailure(e.message));
    } on ValidationException catch (e) {
      return Left(ValidationFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to install extension: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, Unit>> uninstallExtension(String extensionId) async {
    try {
      // Find the installed extension
      final result = await _findInstalledExtension(extensionId);
      if (result == null) {
        return Left(ExtensionFailure('Extension not installed: $extensionId'));
      }

      final source = result.$1;
      final bridgeType = result.$2;

      // Uninstall the extension
      await dataSource.uninstallExtension(source, bridgeType);

      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on ExtensionException catch (e) {
      return Left(ExtensionFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to uninstall extension: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, Unit>> updateExtension(String extensionId) async {
    try {
      // Find the installed extension
      final result = await _findInstalledExtension(extensionId);
      if (result == null) {
        return Left(ExtensionFailure('Extension not installed: $extensionId'));
      }

      final source = result.$1;
      final bridgeType = result.$2;

      // Check if update is available
      if (source.hasUpdate != true) {
        return Left(
          ExtensionFailure('No update available for extension: $extensionId'),
        );
      }

      // Update the extension
      await dataSource.updateExtension(source, bridgeType);

      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on ExtensionException catch (e) {
      return Left(ExtensionFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to update extension: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, List<domain.ExtensionEntity>>>
  checkForUpdates() async {
    try {
      final extensionsWithUpdates = <domain.ExtensionEntity>[];

      // Check for updates across all extension types and item types
      for (final extensionType in dataSource.getSupportedTypes()) {
        for (final itemType in ItemType.values) {
          try {
            final results = await dataSource.checkForUpdates(
              extensionType,
              itemType,
            );
            extensionsWithUpdates.addAll(results.map((e) => e.toEntity()));
          } catch (e) {
            // Continue with other types if one fails
            continue;
          }
        }
      }

      return Right(extensionsWithUpdates);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to check for updates: ${e.toString()}'),
      );
    }
  }

  /// Map entity ExtensionType to bridge ExtensionType
  bridge.ExtensionType _mapEntityTypeToBridgeType(domain.ExtensionType type) {
    switch (type) {
      case domain.ExtensionType.cloudstream:
        return bridge.ExtensionType.cloudstream;
      case domain.ExtensionType.aniyomi:
        return bridge.ExtensionType.aniyomi;
      case domain.ExtensionType.mangayomi:
        return bridge.ExtensionType.mangayomi;
      case domain.ExtensionType.lnreader:
        return bridge.ExtensionType.lnreader;
      case domain.ExtensionType.aniya:
        return bridge.ExtensionType.aniya;
    }
  }

  /// Validate extension before installation
  /// Returns null if valid, or a Failure if invalid
  Future<Failure?> _validateExtension(
    String extensionId,
    domain.ExtensionType type,
  ) async {
    try {
      // Check if extension is already installed
      final installed = await _findInstalledExtension(extensionId);
      if (installed != null) {
        return ExtensionFailure('Extension already installed: $extensionId');
      }

      // Additional validation can be added here
      // - Check extension compatibility
      // - Verify extension manifest
      // - Check required permissions

      return null;
    } catch (e) {
      return ValidationFailure('Extension validation failed: ${e.toString()}');
    }
  }

  /// Find an extension source from available extensions
  Future<Source?> _findExtensionSource(
    String extensionId,
    domain.ExtensionType type,
  ) async {
    try {
      final bridgeType = _mapEntityTypeToBridgeType(type);
      
      // Use default repository URLs for Aniyomi if none configured
      List<String>? repos;
      if (type == domain.ExtensionType.aniyomi) {
        repos = [DefaultRepositories.aniyomiAnimeRepo];
      }

      for (final itemType in ItemType.values) {
        try {
          final extensions = await dataSource.getAvailableExtensions(
            bridgeType,
            itemType,
            repos: repos,
          );

          for (final extension in extensions) {
            if (extension.id == extensionId) {
              return Source(
                id: extension.id,
                name: extension.name,
                version: extension.version,
                lang: extension.language,
                isNsfw: extension.isNsfw,
                iconUrl: extension.iconUrl,
              );
            }
          }
        } catch (e) {
          continue;
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Find an installed extension and its type
  /// Returns a tuple of (Source, bridge.ExtensionType) or null if not found
  Future<(Source, bridge.ExtensionType)?> _findInstalledExtension(
    String extensionId,
  ) async {
    try {
      for (final extensionType in dataSource.getSupportedTypes()) {
        for (final itemType in ItemType.values) {
          try {
            final extensions = await dataSource.getInstalledExtensions(
              extensionType,
              itemType,
            );

            for (final extension in extensions) {
              if (extension.id == extensionId) {
                // Create a Source object from the extension
                final source = Source(
                  id: extension.id,
                  name: extension.name,
                  version: extension.version,
                  lang: extension.language,
                  isNsfw: extension.isNsfw,
                  iconUrl: extension.iconUrl,
                );
                return (source, extensionType);
              }
            }
          } catch (e) {
            continue;
          }
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }
}
