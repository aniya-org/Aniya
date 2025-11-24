import 'package:hive/hive.dart';

import '../models/library_item_model.dart';
import '../../domain/entities/library_item_entity.dart';
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
}

class LibraryLocalDataSourceImpl implements LibraryLocalDataSource {
  static const String _boxName = 'library';
  static const String _playbackBoxName = 'playback_positions';
  static const String _readingBoxName = 'reading_positions';

  final Box<Map<dynamic, dynamic>> _box;
  final Box<int> _playbackBox;
  final Box<int> _readingBox;

  LibraryLocalDataSourceImpl({
    required Box<Map<dynamic, dynamic>> box,
    required Box<int> playbackBox,
    required Box<int> readingBox,
  }) : _box = box,
       _playbackBox = playbackBox,
       _readingBox = readingBox;

  /// Factory method to create instance with initialized boxes
  static Future<LibraryLocalDataSourceImpl> create() async {
    final box = await Hive.openBox<Map<dynamic, dynamic>>(_boxName);
    final playbackBox = await Hive.openBox<int>(_playbackBoxName);
    final readingBox = await Hive.openBox<int>(_readingBoxName);
    return LibraryLocalDataSourceImpl(
      box: box,
      playbackBox: playbackBox,
      readingBox: readingBox,
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

      await _box.put(item.id, item.toJson());
    } catch (e) {
      throw CacheException('Failed to update library item: ${e.toString()}');
    }
  }

  @override
  Future<void> removeFromLibrary(String itemId) async {
    try {
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
  Future<int?> getReadingPosition(String itemId, String chapterId) async {
    try {
      final key = '${itemId}_$chapterId';
      return _readingBox.get(key);
    } catch (e) {
      throw CacheException('Failed to get reading position: ${e.toString()}');
    }
  }
}
