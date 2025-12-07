import 'package:hive/hive.dart';

import '../models/watch_history_entry_model.dart';
import '../../domain/entities/media_entity.dart';
import '../../error/exceptions.dart';

/// Local data source for managing watch history using Hive
abstract class WatchHistoryLocalDataSource {
  /// Get all watch history entries
  Future<List<WatchHistoryEntryModel>> getAllEntries();

  /// Get watch history entries filtered by media type
  Future<List<WatchHistoryEntryModel>> getEntriesByMediaType(MediaType type);

  /// Get watch history entries for video types (Continue Watching)
  Future<List<WatchHistoryEntryModel>> getVideoEntries();

  /// Get watch history entries for reading types (Continue Reading)
  Future<List<WatchHistoryEntryModel>> getReadingEntries();

  /// Get entries sorted by last played date (most recent first)
  Future<List<WatchHistoryEntryModel>> getRecentEntries({int limit = 20});

  /// Get a specific entry by ID
  Future<WatchHistoryEntryModel?> getEntry(String id);

  /// Get entry by normalized ID (for cross-source matching)
  Future<WatchHistoryEntryModel?> getEntryByNormalizedId(String normalizedId);

  /// Find consolidated entry by title, year, and type (ignoring source)
  /// Returns the first entry matching these criteria
  Future<WatchHistoryEntryModel?> findConsolidatedEntry({
    required String title,
    required MediaType mediaType,
    int? releaseYear,
  });

  /// Add or update a watch history entry
  Future<void> upsertEntry(WatchHistoryEntryModel entry);

  /// Update video playback progress
  Future<void> updateVideoProgress({
    required String entryId,
    required int playbackPositionMs,
    int? totalDurationMs,
    int? episodeNumber,
    String? episodeId,
    String? episodeTitle,
  });

  /// Update reading progress
  Future<void> updateReadingProgress({
    required String entryId,
    required int pageNumber,
    int? totalPages,
    int? chapterNumber,
    String? chapterId,
    String? chapterTitle,
    int? volumeNumber,
  });

  /// Mark an entry as completed
  Future<void> markCompleted(String entryId);

  /// Remove an entry from history
  Future<void> removeEntry(String entryId);

  /// Clear all watch history
  Future<void> clearAll();

  /// Get entries count by media type
  Future<Map<MediaType, int>> getEntriesCountByType();
}

class WatchHistoryLocalDataSourceImpl implements WatchHistoryLocalDataSource {
  static const String _boxName = 'watch_history';
  static const String _indexBoxName = 'watch_history_index';

  final Box<Map<dynamic, dynamic>> _box;
  final Box<String> _indexBox; // For normalized ID -> entry ID mapping

  WatchHistoryLocalDataSourceImpl({
    required Box<Map<dynamic, dynamic>> box,
    required Box<String> indexBox,
  }) : _box = box,
       _indexBox = indexBox;

  /// Factory method to create instance with initialized boxes
  static Future<WatchHistoryLocalDataSourceImpl> create() async {
    final box = await Hive.openBox<Map<dynamic, dynamic>>(_boxName);
    final indexBox = await Hive.openBox<String>(_indexBoxName);
    return WatchHistoryLocalDataSourceImpl(box: box, indexBox: indexBox);
  }

  @override
  Future<List<WatchHistoryEntryModel>> getAllEntries() async {
    try {
      final entries = <WatchHistoryEntryModel>[];
      for (var key in _box.keys) {
        final value = _box.get(key);
        if (value != null) {
          final json = Map<String, dynamic>.from(value);
          entries.add(WatchHistoryEntryModel.fromJson(json));
        }
      }
      // Sort by lastPlayedAt descending
      entries.sort((a, b) => b.lastPlayedAt.compareTo(a.lastPlayedAt));
      return entries;
    } catch (e) {
      throw CacheException(
        'Failed to get watch history entries: ${e.toString()}',
      );
    }
  }

  @override
  Future<List<WatchHistoryEntryModel>> getEntriesByMediaType(
    MediaType type,
  ) async {
    try {
      final allEntries = await getAllEntries();
      return allEntries.where((entry) => entry.mediaType == type).toList();
    } catch (e) {
      throw CacheException(
        'Failed to get entries by media type: ${e.toString()}',
      );
    }
  }

  @override
  Future<List<WatchHistoryEntryModel>> getVideoEntries() async {
    try {
      final allEntries = await getAllEntries();
      return allEntries.where((entry) => entry.isVideoEntry).toList();
    } catch (e) {
      throw CacheException('Failed to get video entries: ${e.toString()}');
    }
  }

  @override
  Future<List<WatchHistoryEntryModel>> getReadingEntries() async {
    try {
      final allEntries = await getAllEntries();
      return allEntries.where((entry) => entry.isReadingEntry).toList();
    } catch (e) {
      throw CacheException('Failed to get reading entries: ${e.toString()}');
    }
  }

  @override
  Future<List<WatchHistoryEntryModel>> getRecentEntries({
    int limit = 20,
  }) async {
    try {
      final allEntries = await getAllEntries();
      return allEntries.take(limit).toList();
    } catch (e) {
      throw CacheException('Failed to get recent entries: ${e.toString()}');
    }
  }

  @override
  Future<WatchHistoryEntryModel?> getEntry(String id) async {
    try {
      final value = _box.get(id);
      if (value == null) return null;
      final json = Map<String, dynamic>.from(value);
      return WatchHistoryEntryModel.fromJson(json);
    } catch (e) {
      throw CacheException('Failed to get entry: ${e.toString()}');
    }
  }

  @override
  Future<WatchHistoryEntryModel?> getEntryByNormalizedId(
    String normalizedId,
  ) async {
    try {
      final entryId = _indexBox.get(normalizedId);
      if (entryId == null) return null;
      return getEntry(entryId);
    } catch (e) {
      throw CacheException(
        'Failed to get entry by normalized ID: ${e.toString()}',
      );
    }
  }

  @override
  Future<WatchHistoryEntryModel?> findConsolidatedEntry({
    required String title,
    required MediaType mediaType,
    int? releaseYear,
  }) async {
    try {
      final allEntries = await getAllEntries();

      // Find first entry matching title, type, and year (ignoring source)
      for (final entry in allEntries) {
        if (entry.title.toLowerCase() == title.toLowerCase() &&
            entry.mediaType == mediaType &&
            entry.releaseYear == releaseYear) {
          return entry;
        }
      }

      return null;
    } catch (e) {
      throw CacheException(
        'Failed to find consolidated entry: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> upsertEntry(WatchHistoryEntryModel entry) async {
    try {
      await _box.put(entry.id, entry.toJson());

      // Update normalized ID index if present
      if (entry.normalizedId != null) {
        await _indexBox.put(entry.normalizedId!, entry.id);
      }
    } catch (e) {
      throw CacheException('Failed to upsert entry: ${e.toString()}');
    }
  }

  @override
  Future<void> updateVideoProgress({
    required String entryId,
    required int playbackPositionMs,
    int? totalDurationMs,
    int? episodeNumber,
    String? episodeId,
    String? episodeTitle,
  }) async {
    try {
      final entry = await getEntry(entryId);
      if (entry == null) {
        throw CacheException('Entry not found: $entryId');
      }

      final updatedEntry = entry.copyWith(
        playbackPositionMs: playbackPositionMs,
        totalDurationMs: totalDurationMs ?? entry.totalDurationMs,
        episodeNumber: episodeNumber ?? entry.episodeNumber,
        episodeId: episodeId ?? entry.episodeId,
        episodeTitle: episodeTitle ?? entry.episodeTitle,
        lastPlayedAt: DateTime.now(),
      );

      await upsertEntry(updatedEntry);
    } catch (e) {
      throw CacheException('Failed to update video progress: ${e.toString()}');
    }
  }

  @override
  Future<void> updateReadingProgress({
    required String entryId,
    required int pageNumber,
    int? totalPages,
    int? chapterNumber,
    String? chapterId,
    String? chapterTitle,
    int? volumeNumber,
  }) async {
    try {
      final entry = await getEntry(entryId);
      if (entry == null) {
        throw CacheException('Entry not found: $entryId');
      }

      final updatedEntry = entry.copyWith(
        pageNumber: pageNumber,
        totalPages: totalPages ?? entry.totalPages,
        chapterNumber: chapterNumber ?? entry.chapterNumber,
        chapterId: chapterId ?? entry.chapterId,
        chapterTitle: chapterTitle ?? entry.chapterTitle,
        volumeNumber: volumeNumber ?? entry.volumeNumber,
        lastPlayedAt: DateTime.now(),
      );

      await upsertEntry(updatedEntry);
    } catch (e) {
      throw CacheException(
        'Failed to update reading progress: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> markCompleted(String entryId) async {
    try {
      final entry = await getEntry(entryId);
      if (entry == null) {
        throw CacheException('Entry not found: $entryId');
      }

      final updatedEntry = entry.copyWith(
        completedAt: DateTime.now(),
        lastPlayedAt: DateTime.now(),
      );

      await upsertEntry(updatedEntry);
    } catch (e) {
      throw CacheException(
        'Failed to mark entry as completed: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> removeEntry(String entryId) async {
    try {
      final entry = await getEntry(entryId);
      if (entry?.normalizedId != null) {
        await _indexBox.delete(entry!.normalizedId);
      }
      await _box.delete(entryId);
    } catch (e) {
      throw CacheException('Failed to remove entry: ${e.toString()}');
    }
  }

  @override
  Future<void> clearAll() async {
    try {
      await _box.clear();
      await _indexBox.clear();
    } catch (e) {
      throw CacheException('Failed to clear watch history: ${e.toString()}');
    }
  }

  @override
  Future<Map<MediaType, int>> getEntriesCountByType() async {
    try {
      final allEntries = await getAllEntries();
      final counts = <MediaType, int>{};

      for (final entry in allEntries) {
        counts[entry.mediaType] = (counts[entry.mediaType] ?? 0) + 1;
      }

      return counts;
    } catch (e) {
      throw CacheException(
        'Failed to get entries count by type: ${e.toString()}',
      );
    }
  }
}
