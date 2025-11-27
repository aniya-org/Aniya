import 'package:dartotsu_extension_bridge/ExtensionManager.dart';
import 'package:dartotsu_extension_bridge/Extensions/Extensions.dart';
import 'package:dartotsu_extension_bridge/Models/Source.dart';

import '../models/extension_model.dart';
import '../models/source_model.dart';
import '../models/media_model.dart';
import '../../error/exceptions.dart';
import '../../utils/logger.dart';
import '../../domain/services/lazy_extension_loader.dart';

// Re-export ItemType from bridge for convenience
export 'package:dartotsu_extension_bridge/Models/Source.dart' show ItemType;

/// Data source for managing extensions via DartotsuExtensionBridge
/// Supports CloudStream, Aniyomi, Mangayomi, and LnReader extension types
abstract class ExtensionDataSource {
  /// Get all available extensions for a specific type and item type
  /// [repos] - Optional list of repository URLs to fetch extensions from
  Future<List<ExtensionModel>> getAvailableExtensions(
    ExtensionType type,
    ItemType itemType, {
    List<String>? repos,
  });

  /// Get all installed extensions for a specific type and item type
  Future<List<ExtensionModel>> getInstalledExtensions(
    ExtensionType type,
    ItemType itemType,
  );

  /// Install an extension
  Future<void> installExtension(Source source, ExtensionType type);

  /// Uninstall an extension
  Future<void> uninstallExtension(Source source, ExtensionType type);

  /// Update an extension
  Future<void> updateExtension(Source source, ExtensionType type);

  /// Check for extension updates
  Future<List<ExtensionModel>> checkForUpdates(
    ExtensionType type,
    ItemType itemType,
  );

  /// Get all supported extension types
  List<ExtensionType> getSupportedTypes();

  /// Search for media in an extension
  /// [query] - The search query string
  /// [extensionId] - The ID of the extension to search in
  /// [extensionType] - The type of extension
  /// [itemType] - The type of items to search for
  /// [page] - The page number for pagination
  Future<List<MediaModel>> searchMedia({
    required String query,
    required String extensionId,
    required ExtensionType extensionType,
    required ItemType itemType,
    required int page,
  });

  /// Get sources for a media item from an extension
  /// [mediaId] - The ID of the media
  /// [extensionId] - The ID of the extension
  /// [extensionType] - The type of extension
  /// [itemType] - The type of item
  /// [episodeNumber] - The episode/chapter number
  Future<List<SourceModel>> getSources({
    required String mediaId,
    required String extensionId,
    required ExtensionType extensionType,
    required ItemType itemType,
    required int episodeNumber,
  });
}

class ExtensionDataSourceImpl implements ExtensionDataSource {
  final LazyExtensionLoader lazyLoader;

  ExtensionDataSourceImpl({required this.lazyLoader});

  /// Get the extension manager for a specific type (with lazy loading)
  /// Uses LazyExtensionLoader to get extension managers from GetX
  Future<Extension> _getExtensionManager(ExtensionType type) async {
    return await lazyLoader.getOrLoadExtension(type);
  }

  @override
  Future<List<ExtensionModel>> getAvailableExtensions(
    ExtensionType type,
    ItemType itemType, {
    List<String>? repos,
  }) async {
    try {
      final manager = await _getExtensionManager(type);

      // Fetch available extensions based on item type
      // Pass repository URLs to fetch extensions from configured repos
      // Supports all CloudStream content types (Requirements 12.4)
      List<Source> sources;
      switch (itemType) {
        case ItemType.anime:
          await manager.fetchAvailableAnimeExtensions(repos);
          sources = manager.availableAnimeExtensions.value;
          break;
        case ItemType.manga:
          await manager.fetchAvailableMangaExtensions(repos);
          sources = manager.availableMangaExtensions.value;
          break;
        case ItemType.novel:
          await manager.fetchAvailableNovelExtensions(repos);
          sources = manager.availableNovelExtensions.value;
          break;
        case ItemType.movie:
          await manager.fetchAvailableMovieExtensions(repos);
          sources = manager.availableMovieExtensions.value;
          break;
        case ItemType.tvShow:
          await manager.fetchAvailableTvShowExtensions(repos);
          sources = manager.availableTvShowExtensions.value;
          break;
        case ItemType.cartoon:
          await manager.fetchAvailableCartoonExtensions(repos);
          sources = manager.availableCartoonExtensions.value;
          break;
        case ItemType.documentary:
          await manager.fetchAvailableDocumentaryExtensions(repos);
          sources = manager.availableDocumentaryExtensions.value;
          break;
        case ItemType.livestream:
          await manager.fetchAvailableLivestreamExtensions(repos);
          sources = manager.availableLivestreamExtensions.value;
          break;
        case ItemType.nsfw:
          await manager.fetchAvailableNsfwExtensions(repos);
          sources = manager.availableNsfwExtensions.value;
          break;
      }

      return sources
          .map(
            (source) =>
                ExtensionModel.fromSource(source, type, isInstalled: false),
          )
          .toList();
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to get available extensions for type: $type, itemType: $itemType',
        tag: 'ExtensionDataSource',
        error: e,
        stackTrace: stackTrace,
      );
      throw ServerException(
        'Failed to get available extensions: ${e.toString()}',
      );
    }
  }

  @override
  Future<List<ExtensionModel>> getInstalledExtensions(
    ExtensionType type,
    ItemType itemType,
  ) async {
    try {
      final manager = await _getExtensionManager(type);

      // Fetch installed extensions from device
      List<Source> sources;
      switch (itemType) {
        case ItemType.anime:
          sources = await manager.getInstalledAnimeExtensions();
          break;
        case ItemType.manga:
          sources = await manager.getInstalledMangaExtensions();
          break;
        case ItemType.novel:
          sources = await manager.getInstalledNovelExtensions();
          break;
        case ItemType.movie:
          sources = await manager.getInstalledMovieExtensions();
          break;
        case ItemType.tvShow:
          sources = await manager.getInstalledTvShowExtensions();
          break;
        case ItemType.cartoon:
          sources = await manager.getInstalledCartoonExtensions();
          break;
        case ItemType.documentary:
          sources = await manager.getInstalledDocumentaryExtensions();
          break;
        case ItemType.livestream:
          sources = await manager.getInstalledLivestreamExtensions();
          break;
        case ItemType.nsfw:
          sources = await manager.getInstalledNsfwExtensions();
          break;
      }

      return sources
          .map((source) => ExtensionModel.fromSource(source, type))
          .toList();
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to get installed extensions for type: $type, itemType: $itemType',
        tag: 'ExtensionDataSource',
        error: e,
        stackTrace: stackTrace,
      );
      throw ServerException(
        'Failed to get installed extensions: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> installExtension(Source source, ExtensionType type) async {
    try {
      final manager = await _getExtensionManager(type);
      await manager.installSource(source);
      Logger.info(
        'Successfully installed extension: ${source.id}',
        tag: 'ExtensionDataSource',
      );
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to install extension: ${source.id}',
        tag: 'ExtensionDataSource',
        error: e,
        stackTrace: stackTrace,
      );
      throw ServerException('Failed to install extension: ${e.toString()}');
    }
  }

  @override
  Future<void> uninstallExtension(Source source, ExtensionType type) async {
    try {
      final manager = await _getExtensionManager(type);
      await manager.uninstallSource(source);
      Logger.info(
        'Successfully uninstalled extension: ${source.id}',
        tag: 'ExtensionDataSource',
      );
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to uninstall extension: ${source.id}',
        tag: 'ExtensionDataSource',
        error: e,
        stackTrace: stackTrace,
      );
      throw ServerException('Failed to uninstall extension: ${e.toString()}');
    }
  }

  @override
  Future<void> updateExtension(Source source, ExtensionType type) async {
    try {
      final manager = await _getExtensionManager(type);

      // Check if update is available
      if (source.hasUpdate == true) {
        await manager.updateSource(source);
        Logger.info(
          'Successfully updated extension: ${source.id}',
          tag: 'ExtensionDataSource',
        );
      } else {
        throw ServerException(
          'No update available for extension: ${source.id}',
        );
      }
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to update extension: ${source.id}',
        tag: 'ExtensionDataSource',
        error: e,
        stackTrace: stackTrace,
      );
      throw ServerException('Failed to update extension: ${e.toString()}');
    }
  }

  @override
  Future<List<ExtensionModel>> checkForUpdates(
    ExtensionType type,
    ItemType itemType,
  ) async {
    try {
      final manager = await _getExtensionManager(type);

      // Get installed extensions based on item type
      // Supports all CloudStream content types (Requirements 12.4)
      List<Source> sources;
      switch (itemType) {
        case ItemType.anime:
          sources = manager.installedAnimeExtensions.value;
          break;
        case ItemType.manga:
          sources = manager.installedMangaExtensions.value;
          break;
        case ItemType.novel:
          sources = manager.installedNovelExtensions.value;
          break;
        case ItemType.movie:
          sources = manager.installedMovieExtensions.value;
          break;
        case ItemType.tvShow:
          sources = manager.installedTvShowExtensions.value;
          break;
        case ItemType.cartoon:
          sources = manager.installedCartoonExtensions.value;
          break;
        case ItemType.documentary:
          sources = manager.installedDocumentaryExtensions.value;
          break;
        case ItemType.livestream:
          sources = manager.installedLivestreamExtensions.value;
          break;
        case ItemType.nsfw:
          sources = manager.installedNsfwExtensions.value;
          break;
      }

      final sourcesWithUpdates = sources
          .where((source) => source.hasUpdate == true)
          .toList();

      return sourcesWithUpdates
          .map((source) => ExtensionModel.fromSource(source, type))
          .toList();
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to check for updates for type: $type, itemType: $itemType',
        tag: 'ExtensionDataSource',
        error: e,
        stackTrace: stackTrace,
      );
      throw ServerException('Failed to check for updates: ${e.toString()}');
    }
  }

  @override
  List<ExtensionType> getSupportedTypes() {
    return getSupportedExtensions;
  }

  @override
  Future<List<MediaModel>> searchMedia({
    required String query,
    required String extensionId,
    required ExtensionType extensionType,
    required ItemType itemType,
    required int page,
  }) async {
    try {
      // Search for media in the extension
      // This would call the extension's search method
      // For now, return empty list as this requires extension-specific implementation
      Logger.warning(
        'searchMedia not yet fully implemented for extension: $extensionId',
        tag: 'ExtensionDataSource',
      );
      return [];
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to search media in extension: $extensionId',
        tag: 'ExtensionDataSource',
        error: e,
        stackTrace: stackTrace,
      );
      throw ServerException('Failed to search media: ${e.toString()}');
    }
  }

  @override
  Future<List<SourceModel>> getSources({
    required String mediaId,
    required String extensionId,
    required ExtensionType extensionType,
    required ItemType itemType,
    required int episodeNumber,
  }) async {
    try {
      // Get sources for a media item from the extension
      // This would call the extension's getSources method
      // For now, return empty list as this requires extension-specific implementation
      Logger.warning(
        'getSources not yet fully implemented for extension: $extensionId',
        tag: 'ExtensionDataSource',
      );
      return [];
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to get sources from extension: $extensionId',
        tag: 'ExtensionDataSource',
        error: e,
        stackTrace: stackTrace,
      );
      throw ServerException('Failed to get sources: ${e.toString()}');
    }
  }
}
