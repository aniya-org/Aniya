import 'package:dartotsu_extension_bridge/ExtensionManager.dart';
import 'package:dartotsu_extension_bridge/Extensions/Extensions.dart';
import 'package:dartotsu_extension_bridge/Models/Source.dart';

import '../models/extension_model.dart';
import '../../error/exceptions.dart';
import '../../utils/logger.dart';
import '../../domain/services/lazy_extension_loader.dart';

/// Data source for managing extensions via DartotsuExtensionBridge
/// Supports CloudStream, Aniyomi, Mangayomi, and LnReader extension types
abstract class ExtensionDataSource {
  /// Get all available extensions for a specific type and item type
  Future<List<ExtensionModel>> getAvailableExtensions(
    ExtensionType type,
    ItemType itemType,
  );

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
}

class ExtensionDataSourceImpl implements ExtensionDataSource {
  final ExtensionManager? extensionManager;
  final LazyExtensionLoader lazyLoader;

  ExtensionDataSourceImpl({this.extensionManager, required this.lazyLoader});

  /// Get the extension manager for a specific type (with lazy loading)
  Future<Extension> _getExtensionManager(ExtensionType type) async {
    if (extensionManager == null) {
      throw ServerException('Extension manager not initialized');
    }
    return await lazyLoader.getOrLoadExtension(type);
  }

  @override
  Future<List<ExtensionModel>> getAvailableExtensions(
    ExtensionType type,
    ItemType itemType,
  ) async {
    try {
      final manager = await _getExtensionManager(type);

      // Fetch available extensions based on item type
      List<Source> sources;
      switch (itemType) {
        case ItemType.anime:
          await manager.fetchAvailableAnimeExtensions(null);
          sources = manager.availableAnimeExtensions.value;
          break;
        case ItemType.manga:
          await manager.fetchAvailableMangaExtensions(null);
          sources = manager.availableMangaExtensions.value;
          break;
        case ItemType.novel:
          await manager.fetchAvailableNovelExtensions(null);
          sources = manager.availableNovelExtensions.value;
          break;
        case ItemType.movie:
          await manager.fetchAvailableMovieExtensions(null);
          sources = manager.availableMovieExtensions.value;
          break;
        case ItemType.tvShow:
          await manager.fetchAvailableTvShowExtensions(null);
          sources = manager.availableTvShowExtensions.value;
          break;
        default:
          sources = [];
      }

      return sources
          .map((source) => ExtensionModel.fromSource(source, type))
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

      // Get installed extensions based on item type
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
        default:
          sources = [];
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
        default:
          sources = [];
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
}
