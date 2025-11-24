import 'package:dartotsu_extension_bridge/ExtensionManager.dart';
import 'package:dartotsu_extension_bridge/Extensions/Extensions.dart';
import '../../utils/logger.dart';

/// Service for lazy loading extensions on demand
/// Defers extension initialization until they are actually needed
class LazyExtensionLoader {
  final Map<ExtensionType, Extension> _loadedExtensions = {};
  final Map<ExtensionType, bool> _isLoading = {};

  /// Check if an extension type is loaded
  bool isLoaded(ExtensionType type) {
    return _loadedExtensions.containsKey(type);
  }

  /// Check if an extension type is currently loading
  bool isLoading(ExtensionType type) {
    return _isLoading[type] ?? false;
  }

  /// Get or load an extension manager for a specific type
  /// Returns the extension manager, loading it if necessary
  Future<Extension> getOrLoadExtension(ExtensionType type) async {
    // Return cached extension if already loaded
    if (_loadedExtensions.containsKey(type)) {
      return _loadedExtensions[type]!;
    }

    // Check if already loading
    if (_isLoading[type] == true) {
      // Wait for loading to complete
      while (_isLoading[type] == true) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _loadedExtensions[type]!;
    }

    // Start loading
    _isLoading[type] = true;

    try {
      Logger.info(
        'Lazy loading extension type: $type',
        tag: 'LazyExtensionLoader',
      );

      final extension = type.getManager();

      // Initialize the extension if needed
      // The actual initialization happens when methods are called

      _loadedExtensions[type] = extension;

      Logger.info(
        'Successfully loaded extension type: $type',
        tag: 'LazyExtensionLoader',
      );

      return extension;
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to load extension type: $type',
        tag: 'LazyExtensionLoader',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    } finally {
      _isLoading[type] = false;
    }
  }

  /// Preload specific extension types in the background
  /// This can be called during app initialization for commonly used types
  Future<void> preloadExtensions(List<ExtensionType> types) async {
    for (final type in types) {
      if (!isLoaded(type) && !isLoading(type)) {
        // Load in background without awaiting
        getOrLoadExtension(type).catchError((error) {
          Logger.error(
            'Failed to preload extension type: $type',
            tag: 'LazyExtensionLoader',
            error: error,
          );
          // Return a dummy extension to satisfy the return type
          return type.getManager();
        });
      }
    }
  }

  /// Unload an extension to free memory
  void unloadExtension(ExtensionType type) {
    if (_loadedExtensions.containsKey(type)) {
      Logger.info(
        'Unloading extension type: $type',
        tag: 'LazyExtensionLoader',
      );
      _loadedExtensions.remove(type);
    }
  }

  /// Unload all extensions
  void unloadAll() {
    Logger.info('Unloading all extensions', tag: 'LazyExtensionLoader');
    _loadedExtensions.clear();
  }

  /// Get count of loaded extensions
  int get loadedCount => _loadedExtensions.length;
}
