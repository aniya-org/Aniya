import 'package:hive/hive.dart';

import '../models/library_item_model.dart';
import '../../domain/entities/library_item_entity.dart';
import '../../domain/entities/media_entity.dart';
import '../../error/exceptions.dart';

/// Local data source for managing library items using Hive
abstract class LibraryLocalDataSource {
  /// Get all library items
  Future<List<LibraryItemModel>> getLibraryItems();

  /// Get library items filtered by status
  Future<List<LibraryItemModel>> getLibraryItemsByStatus(LibraryStatus status);

  /// Add an item to the library
  Future<void> addToLibrary(LibraryItemModel item);

  /// Update a library item
  Future<void> updateLibraryItem(LibraryItemModel item);

  /// Remove an item from the library
  Future<void> removeFromLibrary(String itemId);

  /// Get a specific library item by ID
  Future<LibraryItemModel?> getLibraryItem(String itemId);

  /// Get library item by normalized ID (for cross-source matching)
  Future<LibraryItemModel?> getLibraryItemByNormalizedId(String normalizedId);

  /// Update progress for a library item
  Future<void> updateProgress(
    String itemId,
    int currentEpisode,
    int currentChapter,
  );

  /// Save playback position for a video episode
  Future<void> savePlaybackPosition(
    String itemId,
    String episodeId,
    int position,
  );

  /// Get saved playback position for a video episode
  Future<int?> getPlaybackPosition(String itemId, String episodeId);

  /// Save reading position for a manga chapter
  Future<void> saveReadingPosition(String itemId, String chapterId, int page);

  /// Get saved reading position for a manga chapter
  Future<int?> getReadingPosition(String itemId, String chapterId);

  /// Migrate legacy library items to include normalized IDs
  Future<void> migrateToNormalizedIds();
}

class LibraryLocalDataSourceImpl implements LibraryLocalDataSource {
  static const String _boxName = 'library';
  static const String _playbackBoxName = 'playback_positions';
  static const String _readingBoxName = 'reading_positions';
  static const String _indexBoxName = 'library_index';

  final Box<Map<dynamic, dynamic>> _box;
  final Box<int> _playbackBox;
  final Box<int> _readingBox;
  final Box<String> _indexBox; // For normalized ID -> library item ID mapping

  LibraryLocalDataSourceImpl({
    required Box<Map<dynamic, dynamic>> box,
    required Box<int> playbackBox,
    required Box<int> readingBox,
    required Box<String> indexBox,
  }) : _box = box,
       _playbackBox = playbackBox,
       _readingBox = readingBox,
       _indexBox = indexBox;

  /// Factory method to create instance with initialized boxes
  static Future<LibraryLocalDataSourceImpl> create() async {
    final box = await Hive.openBox<Map<dynamic, dynamic>>(_boxName);
    final playbackBox = await Hive.openBox<int>(_playbackBoxName);
    final readingBox = await Hive.openBox<int>(_readingBoxName);
    final indexBox = await Hive.openBox<String>(_indexBoxName);
    return LibraryLocalDataSourceImpl(
      box: box,
      playbackBox: playbackBox,
      readingBox: readingBox,
      indexBox: indexBox,
    );
  }

  @override
  Future<List<LibraryItemModel>> getLibraryItems() async {
    try {
      final items = <LibraryItemModel>[];

      for (var key in _box.keys) {
        final value = _box.get(key);
        if (value != null) {
          final json = Map<String, dynamic>.from(value);
          items.add(LibraryItemModel.fromJson(json));
        }
      }

      return items;
    } catch (e) {
      throw CacheException('Failed to get library items: ${e.toString()}');
    }
  }

  @override
  Future<List<LibraryItemModel>> getLibraryItemsByStatus(
    LibraryStatus status,
  ) async {
    try {
      final allItems = await getLibraryItems();
      return allItems.where((item) => item.status == status).toList();
    } catch (e) {
      throw CacheException(
        'Failed to get library items by status: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> addToLibrary(LibraryItemModel item) async {
    try {
      await _box.put(item.id, item.toJson());

      // Update normalized ID index if present
      if (item.normalizedId != null && item.normalizedId!.isNotEmpty) {
        await _indexBox.put(item.normalizedId!, item.id);
      }
    } catch (e) {
      throw CacheException('Failed to add to library: ${e.toString()}');
    }
  }

  @override
  Future<void> updateLibraryItem(LibraryItemModel item) async {
    try {
      if (!_box.containsKey(item.id)) {
        throw CacheException('Library item not found: ${item.id}');
      }

      // Get the old item to clean up old index if normalized ID changed
      final oldItem = await getLibraryItem(item.id);
      if (oldItem != null &&
          oldItem.normalizedId != null &&
          oldItem.normalizedId != item.normalizedId) {
        await _indexBox.delete(oldItem.normalizedId);
      }

      await _box.put(item.id, item.toJson());

      // Update normalized ID index if present
      if (item.normalizedId != null && item.normalizedId!.isNotEmpty) {
        await _indexBox.put(item.normalizedId!, item.id);
      }
    } catch (e) {
      throw CacheException('Failed to update library item: ${e.toString()}');
    }
  }

  @override
  Future<void> removeFromLibrary(String itemId) async {
    try {
      // Clean up normalized ID index before deleting
      final item = await getLibraryItem(itemId);
      if (item?.normalizedId != null) {
        await _indexBox.delete(item!.normalizedId);
      }

      await _box.delete(itemId);
    } catch (e) {
      throw CacheException('Failed to remove from library: ${e.toString()}');
    }
  }

  @override
  Future<LibraryItemModel?> getLibraryItem(String itemId) async {
    try {
      final value = _box.get(itemId);
      if (value == null) return null;

      final json = Map<String, dynamic>.from(value);
      return LibraryItemModel.fromJson(json);
    } catch (e) {
      throw CacheException('Failed to get library item: ${e.toString()}');
    }
  }

  @override
  Future<void> updateProgress(
    String itemId,
    int currentEpisode,
    int currentChapter,
  ) async {
    try {
      final item = await getLibraryItem(itemId);
      if (item == null) {
        throw CacheException('Library item not found: $itemId');
      }

      final updatedItem = item.copyWith(
        progress: (item.progress ?? const WatchProgress()).copyWith(
          currentEpisode: currentEpisode,
          currentChapter: currentChapter,
        ),
        lastUpdated: DateTime.now(),
      );

      await updateLibraryItem(updatedItem);
    } catch (e) {
      throw CacheException('Failed to update progress: ${e.toString()}');
    }
  }

  @override
  Future<void> savePlaybackPosition(
    String itemId,
    String episodeId,
    int position,
  ) async {
    try {
      final key = '${itemId}_$episodeId';
      await _playbackBox.put(key, position);
    } catch (e) {
      throw CacheException('Failed to save playback position: ${e.toString()}');
    }
  }

  @override
  Future<int?> getPlaybackPosition(String itemId, String episodeId) async {
    try {
      final key = '${itemId}_$episodeId';
      return _playbackBox.get(key);
    } catch (e) {
      throw CacheException('Failed to get playback position: ${e.toString()}');
    }
  }

  @override
  Future<int?> getReadingPosition(String itemId, String chapterId) async {
    try {
      final key = '${itemId}_$chapterId';
      return _readingBox.get(key);
    } catch (e) {
      throw CacheException('Failed to get reading position: ${e.toString()}');
    }
  }

  @override
  Future<void> saveReadingPosition(
    String itemId,
    String chapterId,
    int page,
  ) async {
    try {
      final key = '${itemId}_$chapterId';
      await _readingBox.put(key, page);
    } catch (e) {
      throw CacheException('Failed to save reading position: ${e.toString()}');
    }
  }

  @override
  Future<LibraryItemModel?> getLibraryItemByNormalizedId(
    String normalizedId,
  ) async {
    try {
      final itemId = _indexBox.get(normalizedId);
      if (itemId == null) return null;
      return getLibraryItem(itemId);
    } catch (e) {
      throw CacheException(
        'Failed to get library item by normalized ID: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> migrateToNormalizedIds() async {
    try {
      final allItems = await getLibraryItems();
      int migratedCount = 0;

      for (final item in allItems) {
        // Skip items that already have normalized IDs
        if (item.normalizedId != null && item.normalizedId!.isNotEmpty) {
          continue;
        }

        // Generate normalized ID from media information
        if (item.media != null) {
          final normalizedId = _generateNormalizedId(
            item.media!.title,
            item.effectiveMediaType,
            item.media!.startDate?.year,
          );

          // Update the item with normalized ID
          final updatedItem = item.copyWith(normalizedId: normalizedId);
          await updateLibraryItem(updatedItem);
          migratedCount++;
        }
      }

      // Log migration results
      if (migratedCount > 0) {
        print(
          'Migrated $migratedCount library items to include normalized IDs',
        );
      }
    } catch (e) {
      throw CacheException(
        'Failed to migrate to normalized IDs: ${e.toString()}',
      );
    }
  }

  /// Generate a normalized ID for cross-source matching
  String _generateNormalizedId(String title, MediaType type, [int? year]) {
    // Normalize title: lowercase, remove special characters, trim
    final normalized = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();

    final yearSuffix = year != null ? '_$year' : '';
    return '${type.name}_$normalized$yearSuffix';
  }
}
