import 'package:dartotsu_extension_bridge/ExtensionManager.dart';
import 'package:dartotsu_extension_bridge/Extensions/Extensions.dart';
import 'package:dartotsu_extension_bridge/Models/Source.dart';

import '../domain/entities/extension_entity.dart' as domain;
import '../domain/services/lazy_extension_loader.dart';
import '../utils/logger.dart';
import '../utils/version_comparator.dart';

/// Result of extension discovery operation
class ExtensionDiscoveryResult {
  /// All discovered installed extensions
  final List<domain.ExtensionEntity> discoveredExtensions;

  /// Extensions that have updates available
  final List<domain.ExtensionEntity> extensionsWithUpdates;

  /// Any errors that occurred during discovery
  final List<String> errors;

  /// Whether the discovery was successful
  final bool success;

  const ExtensionDiscoveryResult({
    required this.discoveredExtensions,
    required this.extensionsWithUpdates,
    required this.errors,
    required this.success,
  });

  /// Creates an empty result
  factory ExtensionDiscoveryResult.empty() {
    return const ExtensionDiscoveryResult(
      discoveredExtensions: [],
      extensionsWithUpdates: [],
      errors: [],
      success: true,
    );
  }

  /// Creates a failure result
  factory ExtensionDiscoveryResult.failure(String error) {
    return ExtensionDiscoveryResult(
      discoveredExtensions: [],
      extensionsWithUpdates: [],
      errors: [error],
      success: false,
    );
  }
}

/// Service for discovering installed extensions on app initialization
///
/// This service scans for installed extension packages across all supported
/// extension types (CloudStream, Aniyomi, Mangayomi, LnReader) and determines
/// their type from package metadata.
///
/// Requirements: 10.1, 10.2, 10.3, 10.4
class ExtensionDiscoveryService {
  final LazyExtensionLoader _lazyLoader;

  ExtensionDiscoveryService({required LazyExtensionLoader lazyLoader})
    : _lazyLoader = lazyLoader;

  /// Discovers all installed extensions across all supported extension types
  ///
  /// Scans for installed extension packages on init (Requirement 10.1)
  /// Adds discovered extensions to the installed list (Requirement 10.2)
  /// Determines extension type from package metadata (Requirement 10.3)
  ///
  /// Returns [ExtensionDiscoveryResult] containing all discovered extensions
  Future<ExtensionDiscoveryResult> discoverInstalledExtensions() async {
    Logger.info(
      'Starting extension discovery...',
      tag: 'ExtensionDiscoveryService',
    );

    final List<domain.ExtensionEntity> allDiscovered = [];
    final List<String> errors = [];

    // Get all supported extension types
    final supportedTypes = getSupportedExtensions;

    for (final extensionType in supportedTypes) {
      try {
        final discovered = await _discoverExtensionsForType(extensionType);
        allDiscovered.addAll(discovered);

        Logger.info(
          'Discovered ${discovered.length} extensions for type: $extensionType',
          tag: 'ExtensionDiscoveryService',
        );
      } catch (e, stackTrace) {
        final errorMsg =
            'Failed to discover extensions for type $extensionType: $e';
        errors.add(errorMsg);
        Logger.error(
          errorMsg,
          tag: 'ExtensionDiscoveryService',
          error: e,
          stackTrace: stackTrace,
        );
        // Continue with other types even if one fails
      }
    }

    Logger.info(
      'Extension discovery complete. Found ${allDiscovered.length} extensions.',
      tag: 'ExtensionDiscoveryService',
    );

    return ExtensionDiscoveryResult(
      discoveredExtensions: allDiscovered,
      extensionsWithUpdates: [],
      errors: errors,
      success: errors.isEmpty,
    );
  }

  /// Discovers installed extensions for a specific extension type
  ///
  /// Requirement 10.3: Determines extension type from package metadata
  Future<List<domain.ExtensionEntity>> _discoverExtensionsForType(
    ExtensionType extensionType,
  ) async {
    final List<domain.ExtensionEntity> discovered = [];

    try {
      // Get the extension manager for this type
      final manager = await _lazyLoader.getOrLoadExtension(extensionType);

      // Ensure the manager is initialized
      if (!manager.isInitialized.value) {
        await manager.initialize();
      }

      // Scan all item types for installed extensions
      for (final itemType in ItemType.values) {
        try {
          final sources = await _getInstalledSourcesForItemType(
            manager,
            itemType,
          );

          for (final source in sources) {
            final entity = _sourceToEntity(source, extensionType, itemType);
            discovered.add(entity);
          }
        } catch (e) {
          // Continue with other item types if one fails
          Logger.warning(
            'Failed to discover $itemType extensions for $extensionType: $e',
            tag: 'ExtensionDiscoveryService',
          );
        }
      }
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to get extension manager for type: $extensionType',
        tag: 'ExtensionDiscoveryService',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }

    return discovered;
  }

  /// Gets installed sources for a specific item type from the extension manager
  Future<List<Source>> _getInstalledSourcesForItemType(
    Extension manager,
    ItemType itemType,
  ) async {
    switch (itemType) {
      case ItemType.anime:
        return manager.installedAnimeExtensions.value;
      case ItemType.manga:
        return manager.installedMangaExtensions.value;
      case ItemType.novel:
        return manager.installedNovelExtensions.value;
      case ItemType.movie:
        return manager.installedMovieExtensions.value;
      case ItemType.tvShow:
        return manager.installedTvShowExtensions.value;
      case ItemType.cartoon:
        return manager.installedCartoonExtensions.value;
      case ItemType.documentary:
        return manager.installedDocumentaryExtensions.value;
      case ItemType.livestream:
        return manager.installedLivestreamExtensions.value;
      case ItemType.nsfw:
        return manager.installedNsfwExtensions.value;
    }
  }

  /// Converts a Source to an ExtensionEntity
  ///
  /// Requirement 10.3: Determines extension type from package metadata
  domain.ExtensionEntity _sourceToEntity(
    Source source,
    ExtensionType extensionType,
    ItemType itemType,
  ) {
    return domain.ExtensionEntity(
      id: source.id ?? '',
      name: source.name ?? 'Unknown',
      version: source.version ?? '0.0.0',
      versionLast: source.versionLast,
      type: _mapBridgeTypeToEntityType(extensionType),
      itemType: _mapBridgeItemTypeToEntityItemType(itemType),
      language: source.lang ?? 'en',
      isInstalled: true,
      isNsfw: source.isNsfw ?? false,
      hasUpdate: source.hasUpdate ?? false,
      iconUrl: source.iconUrl,
      apkUrl: source.apkUrl,
      description: null,
    );
  }

  /// Maps bridge ExtensionType to domain ExtensionType
  domain.ExtensionType _mapBridgeTypeToEntityType(ExtensionType type) {
    switch (type) {
      case ExtensionType.cloudstream:
        return domain.ExtensionType.cloudstream;
      case ExtensionType.aniyomi:
        return domain.ExtensionType.aniyomi;
      case ExtensionType.mangayomi:
        return domain.ExtensionType.mangayomi;
      case ExtensionType.lnreader:
        return domain.ExtensionType.lnreader;
      case ExtensionType.aniya:
        return domain.ExtensionType.aniya;
    }
  }

  /// Maps bridge ItemType to domain ItemType
  domain.ItemType _mapBridgeItemTypeToEntityItemType(ItemType itemType) {
    switch (itemType) {
      case ItemType.anime:
        return domain.ItemType.anime;
      case ItemType.manga:
        return domain.ItemType.manga;
      case ItemType.novel:
        return domain.ItemType.novel;
      case ItemType.movie:
        return domain.ItemType.movie;
      case ItemType.tvShow:
        return domain.ItemType.tvShow;
      case ItemType.cartoon:
        return domain.ItemType.cartoon;
      case ItemType.documentary:
        return domain.ItemType.documentary;
      case ItemType.livestream:
        return domain.ItemType.livestream;
      case ItemType.nsfw:
        return domain.ItemType.nsfw;
    }
  }

  /// Checks for available updates for discovered extensions against repository data
  ///
  /// Requirement 10.4: Check for available updates against repository data
  ///
  /// [discoveredExtensions] - List of discovered installed extensions
  /// [availableExtensions] - List of available extensions from repositories
  ///
  /// Returns list of extensions with hasUpdate flag set appropriately
  List<domain.ExtensionEntity> checkForUpdates(
    List<domain.ExtensionEntity> discoveredExtensions,
    List<domain.ExtensionEntity> availableExtensions,
  ) {
    // Create a map of available extensions by ID for quick lookup
    final availableMap = <String, domain.ExtensionEntity>{};
    for (final ext in availableExtensions) {
      availableMap[ext.id] = ext;
    }

    // Check each discovered extension for updates
    return discoveredExtensions.map((installedExt) {
      final availableExt = availableMap[installedExt.id];

      if (availableExt == null) {
        // No available version found, no update available
        return installedExt;
      }

      // Compare versions using the VersionComparator
      final hasUpdate = VersionComparator.hasUpdateAvailable(
        installedExt.version,
        availableExt.version,
      );

      if (hasUpdate) {
        // Update the extension with hasUpdate flag and latest version
        return installedExt.copyWith(
          hasUpdate: true,
          versionLast: availableExt.version,
          apkUrl: availableExt.apkUrl,
        );
      }

      return installedExt;
    }).toList();
  }

  /// Determines the extension type from a source's metadata
  ///
  /// Requirement 10.3: Determine extension type from package metadata
  ///
  /// Returns a valid ExtensionType enum value based on the source's extensionType
  /// field, or defaults to mangayomi if not specified.
  domain.ExtensionType determineExtensionType(Source source) {
    final bridgeType = source.extensionType;

    if (bridgeType == null) {
      // Default to mangayomi for sources without explicit type
      return domain.ExtensionType.mangayomi;
    }

    return _mapBridgeTypeToEntityType(bridgeType);
  }

  /// Validates that a detected extension type is valid
  ///
  /// Property 22: Extension type detection validity
  /// For any discovered extension package, the type detection function
  /// should return a valid ExtensionType enum value.
  bool isValidExtensionType(domain.ExtensionType? type) {
    if (type == null) return false;
    return domain.ExtensionType.values.contains(type);
  }
}
