import 'package:hive/hive.dart';

import '../models/media_model.dart';
import '../../error/exceptions.dart';

/// Local data source for caching media content using Hive
abstract class MediaLocalDataSource {
  /// Cache a media item
  Future<void> cacheMedia(MediaModel media);

  /// Get a cached media item by ID
  Future<MediaModel?> getCachedMedia(String id);

  /// Get all cached media items
  Future<List<MediaModel>> getCachedMediaList();

  /// Clear all cached media
  Future<void> clearCache();

  /// Remove a specific cached media item
  Future<void> removeCachedMedia(String id);
}

class MediaLocalDataSourceImpl implements MediaLocalDataSource {
  static const String _boxName = 'media_cache';
  final Box<Map<dynamic, dynamic>> _box;

  MediaLocalDataSourceImpl({required Box<Map<dynamic, dynamic>> box})
    : _box = box;

  /// Factory method to create instance with initialized box
  static Future<MediaLocalDataSourceImpl> create() async {
    final box = await Hive.openBox<Map<dynamic, dynamic>>(_boxName);
    return MediaLocalDataSourceImpl(box: box);
  }

  @override
  Future<void> cacheMedia(MediaModel media) async {
    try {
      final json = media.toJson();
      json['cachedAt'] = DateTime.now().toIso8601String();
      await _box.put(media.id, json);
    } catch (e) {
      throw CacheException('Failed to cache media: ${e.toString()}');
    }
  }

  @override
  Future<MediaModel?> getCachedMedia(String id) async {
    try {
      final value = _box.get(id);
      if (value == null) return null;

      final json = Map<String, dynamic>.from(value);
      return MediaModel.fromJson(json);
    } catch (e) {
      throw CacheException('Failed to get cached media: ${e.toString()}');
    }
  }

  @override
  Future<List<MediaModel>> getCachedMediaList() async {
    try {
      final items = <MediaModel>[];

      for (var key in _box.keys) {
        final value = _box.get(key);
        if (value != null) {
          final json = Map<String, dynamic>.from(value);
          items.add(MediaModel.fromJson(json));
        }
      }

      return items;
    } catch (e) {
      throw CacheException('Failed to get cached media list: ${e.toString()}');
    }
  }

  @override
  Future<void> clearCache() async {
    try {
      await _box.clear();
    } catch (e) {
      throw CacheException('Failed to clear cache: ${e.toString()}');
    }
  }

  @override
  Future<void> removeCachedMedia(String id) async {
    try {
      await _box.delete(id);
    } catch (e) {
      throw CacheException('Failed to remove cached media: ${e.toString()}');
    }
  }
}
