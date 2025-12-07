import 'dart:math';
import 'package:flutter/foundation.dart';
import '../domain/entities/watch_history_entry.dart';
import '../domain/entities/media_entity.dart';
import '../domain/repositories/watch_history_repository.dart';
import '../utils/logger.dart';

/// Controller for managing watch history across all media types
/// Provides filtered views for Continue Watching, Continue Reading, and per-type sections
///
/// This is an improved version that uses proper logging instead of debug prints
class WatchHistoryController extends ChangeNotifier {
  final WatchHistoryRepository repository;

  WatchHistoryController({required this.repository});

  // State
  List<WatchHistoryEntry> _allEntries = [];
  List<WatchHistoryEntry> _continueWatching = [];
  List<WatchHistoryEntry> _continueReading = [];
  Map<MediaType, List<WatchHistoryEntry>> _entriesByType = {};
  Map<MediaType, int> _entriesCountByType = {};
  bool _isLoading = false;
  String? _error;

  // Getters
  List<WatchHistoryEntry> get allEntries => _allEntries;
  List<WatchHistoryEntry> get continueWatching => _continueWatching;
  List<WatchHistoryEntry> get continueReading => _continueReading;
  Map<MediaType, List<WatchHistoryEntry>> get entriesByType => _entriesByType;
  Map<MediaType, int> get entriesCountByType => _entriesCountByType;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Get entries for a specific media type
  List<WatchHistoryEntry> getEntriesForType(MediaType type) {
    return _entriesByType[type] ?? [];
  }

  /// Load all watch history data
  Future<void> loadAll() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Load all entries
      final allResult = await repository.getAllEntries();
      allResult.fold(
        (failure) {
          _error = failure.message;
          Logger.error(
            'Failed to load watch history',
            tag: 'WatchHistoryController',
            error: failure,
          );
        },
        (entries) {
          _allEntries = entries;
          Logger.debug(
            'Loaded ${entries.length} history entries',
            tag: 'WatchHistoryController',
          );
        },
      );

      // Load continue watching
      final watchingResult = await repository.getContinueWatching(limit: 20);
      watchingResult.fold(
        (failure) => Logger.error(
          'Failed to load continue watching',
          tag: 'WatchHistoryController',
          error: failure,
        ),
        (entries) {
          _continueWatching = entries;
          Logger.debug(
            'Loaded ${entries.length} continue watching entries',
            tag: 'WatchHistoryController',
          );
        },
      );

      // Load continue reading
      final readingResult = await repository.getContinueReading(limit: 20);
      readingResult.fold(
        (failure) => Logger.error(
          'Failed to load continue reading',
          tag: 'WatchHistoryController',
          error: failure,
        ),
        (entries) {
          _continueReading = entries;
          Logger.debug(
            'Loaded ${entries.length} continue reading entries',
            tag: 'WatchHistoryController',
          );
        },
      );

      // Load counts by type
      final countsResult = await repository.getEntriesCountByType();
      countsResult.fold(
        (failure) => Logger.error(
          'Failed to load counts',
          tag: 'WatchHistoryController',
          error: failure,
        ),
        (counts) => _entriesCountByType = counts,
      );

      // Group entries by type
      _entriesByType = {};
      for (final entry in _allEntries) {
        _entriesByType.putIfAbsent(entry.mediaType, () => []).add(entry);
      }
    } catch (e, stackTrace) {
      _error = 'An unexpected error occurred';
      Logger.error(
        'Unexpected error in loadAll',
        tag: 'WatchHistoryController',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update or create a watch history entry for video content
  /// Consolidates entries by title+year+type to avoid duplicates
  Future<void> updateVideoProgress({
    required String mediaId,
    required MediaType mediaType,
    required String title,
    String? coverImage,
    required String sourceId,
    required String sourceName,
    required int episodeNumber,
    String? episodeId,
    String? episodeTitle,
    required int playbackPositionMs,
    int? totalDurationMs,
    String? livestreamId,
    bool? wasLive,
    String? normalizedId,
    int? releaseYear,
  }) async {
    try {
      Logger.debug(
        'Updating video progress for $title (episode $episodeNumber)',
        tag: 'WatchHistoryController',
      );

      // First, try to find consolidated entry by title+year+type
      final consolidatedResult = await repository.findConsolidatedEntry(
        title: title,
        mediaType: mediaType,
        releaseYear: releaseYear,
      );

      await consolidatedResult.fold(
        (failure) async {
          Logger.debug(
            'No consolidated entry found, will create new one',
            tag: 'WatchHistoryController',
          );
        },
        (consolidatedEntry) async {
          if (consolidatedEntry != null) {
            // Found consolidated entry - update it with new episode
            Logger.info(
              'Found consolidated entry for "$title", updating episode $episodeNumber',
              tag: 'WatchHistoryController',
            );

            // Merge progress: use max episode number
            final newEpisodeNumber = max(
              consolidatedEntry.episodeNumber ?? 0,
              episodeNumber,
            );

            final updatedEntry = consolidatedEntry.copyWith(
              episodeNumber: newEpisodeNumber,
              episodeId: episodeId ?? consolidatedEntry.episodeId,
              episodeTitle: episodeTitle ?? consolidatedEntry.episodeTitle,
              playbackPositionMs: playbackPositionMs,
              totalDurationMs:
                  totalDurationMs ?? consolidatedEntry.totalDurationMs,
              lastPlayedAt: DateTime.now(),
            );

            await repository.upsertEntry(updatedEntry);
            Logger.info(
              'Updated consolidated entry for "$title" with episode $newEpisodeNumber',
              tag: 'WatchHistoryController',
            );

            // Trigger sync if entry has tracking
            await _triggerSyncIfTracked(updatedEntry);
            await _refreshContinueWatching();
            return;
          }
        },
      );

      // No consolidated entry found - create new one
      final entry = repository.createEntry(
        mediaId: mediaId,
        mediaType: mediaType,
        title: title,
        coverImage: coverImage,
        sourceId: sourceId,
        sourceName: sourceName,
        normalizedId: normalizedId,
        releaseYear: releaseYear,
      );

      final videoEntry = WatchHistoryEntry(
        id: entry.id,
        mediaId: entry.mediaId,
        normalizedId: entry.normalizedId,
        mediaType: entry.mediaType,
        title: entry.title,
        coverImage: entry.coverImage,
        sourceId: entry.sourceId,
        sourceName: entry.sourceName,
        releaseYear: releaseYear,
        episodeNumber: episodeNumber,
        episodeId: episodeId,
        episodeTitle: episodeTitle,
        playbackPositionMs: playbackPositionMs,
        totalDurationMs: totalDurationMs,
        livestreamId: livestreamId,
        wasLive: wasLive,
        createdAt: entry.createdAt,
        lastPlayedAt: entry.lastPlayedAt,
      );

      await repository.upsertEntry(videoEntry);
      Logger.info(
        'Created new video entry for "$title" (episode $episodeNumber)',
        tag: 'WatchHistoryController',
      );

      // Refresh continue watching
      await _refreshContinueWatching();
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to update video progress',
        tag: 'WatchHistoryController',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Update or create a watch history entry for reading content
  /// Consolidates entries by title+year+type to avoid duplicates
  Future<void> updateReadingProgress({
    required String mediaId,
    required MediaType mediaType,
    required String title,
    String? coverImage,
    required String sourceId,
    required String sourceName,
    required int pageNumber,
    int? totalPages,
    int? chapterNumber,
    String? chapterId,
    String? chapterTitle,
    int? volumeNumber,
    String? normalizedId,
    int? releaseYear,
  }) async {
    try {
      Logger.debug(
        'Updating reading progress for $title (chapter $chapterNumber, page $pageNumber)',
        tag: 'WatchHistoryController',
      );

      // First, try to find consolidated entry by title+year+type
      final consolidatedResult = await repository.findConsolidatedEntry(
        title: title,
        mediaType: mediaType,
        releaseYear: releaseYear,
      );

      await consolidatedResult.fold(
        (failure) async {
          Logger.debug(
            'No consolidated entry found, will create new one',
            tag: 'WatchHistoryController',
          );
        },
        (consolidatedEntry) async {
          if (consolidatedEntry != null) {
            // Found consolidated entry - update it with new chapter
            Logger.info(
              'Found consolidated entry for "$title", updating chapter $chapterNumber',
              tag: 'WatchHistoryController',
            );

            // Merge progress: use max chapter number
            final newChapterNumber = max(
              consolidatedEntry.chapterNumber ?? 0,
              chapterNumber ?? 0,
            );

            final updatedEntry = consolidatedEntry.copyWith(
              chapterNumber: newChapterNumber,
              chapterId: chapterId ?? consolidatedEntry.chapterId,
              chapterTitle: chapterTitle ?? consolidatedEntry.chapterTitle,
              pageNumber: pageNumber,
              totalPages: totalPages ?? consolidatedEntry.totalPages,
              lastPlayedAt: DateTime.now(),
            );

            await repository.upsertEntry(updatedEntry);
            Logger.info(
              'Updated consolidated entry for "$title" with chapter $newChapterNumber',
              tag: 'WatchHistoryController',
            );

            // Trigger sync if entry has tracking
            await _triggerSyncIfTracked(updatedEntry);
            await _refreshContinueReading();
            return;
          }
        },
      );

      // No consolidated entry found - create new one
      final entry = repository.createEntry(
        mediaId: mediaId,
        mediaType: mediaType,
        title: title,
        coverImage: coverImage,
        sourceId: sourceId,
        sourceName: sourceName,
        normalizedId: normalizedId,
        releaseYear: releaseYear,
      );

      // Add reading-specific data
      final readingEntry = WatchHistoryEntry(
        id: entry.id,
        mediaId: entry.mediaId,
        normalizedId: entry.normalizedId,
        mediaType: entry.mediaType,
        title: entry.title,
        coverImage: entry.coverImage,
        sourceId: entry.sourceId,
        sourceName: entry.sourceName,
        releaseYear: releaseYear,
        chapterNumber: chapterNumber,
        chapterId: chapterId,
        chapterTitle: chapterTitle,
        volumeNumber: volumeNumber,
        pageNumber: pageNumber,
        totalPages: totalPages,
        createdAt: entry.createdAt,
        lastPlayedAt: entry.lastPlayedAt,
      );

      await repository.upsertEntry(readingEntry);
      Logger.info(
        'Created new reading entry for "$title" (chapter $chapterNumber)',
        tag: 'WatchHistoryController',
      );

      // Refresh continue reading
      await _refreshContinueReading();
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to update reading progress',
        tag: 'WatchHistoryController',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Mark an entry as completed
  Future<void> markAsCompleted({
    required String mediaId,
    required MediaType mediaType,
    required String sourceId,
    String? normalizedId,
  }) async {
    try {
      final entryId = WatchHistoryEntry.generateId(
        mediaType,
        mediaId,
        sourceId,
      );

      Logger.info(
        'Marking $mediaId as completed',
        tag: 'WatchHistoryController',
      );

      await repository.markCompleted(entryId);

      // Refresh data
      if (_allEntries.isNotEmpty) {
        await loadAll();
      }
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to mark entry as completed',
        tag: 'WatchHistoryController',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Remove an entry from watch history
  Future<void> removeEntry({
    required String mediaId,
    required MediaType mediaType,
    required String sourceId,
    String? normalizedId,
  }) async {
    try {
      final entryId = WatchHistoryEntry.generateId(
        mediaType,
        mediaId,
        sourceId,
      );

      Logger.info(
        'Removing $mediaId from watch history',
        tag: 'WatchHistoryController',
      );

      await repository.removeEntry(entryId);

      // Refresh data
      if (_allEntries.isNotEmpty) {
        await loadAll();
      }
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to remove entry',
        tag: 'WatchHistoryController',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Clear all watch history
  Future<void> clearAll() async {
    try {
      Logger.info('Clearing all watch history', tag: 'WatchHistoryController');

      await repository.clearAll();

      // Reset state
      _allEntries = [];
      _continueWatching = [];
      _continueReading = [];
      _entriesByType = {};
      _entriesCountByType = {};
      _error = null;

      notifyListeners();
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to clear watch history',
        tag: 'WatchHistoryController',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Refresh continue watching entries
  Future<void> _refreshContinueWatching() async {
    if (_isLoading) return;

    try {
      final result = await repository.getContinueWatching(limit: 20);
      result.fold(
        (failure) => Logger.error(
          'Failed to refresh continue watching',
          tag: 'WatchHistoryController',
          error: failure,
        ),
        (entries) {
          _continueWatching = entries;
          notifyListeners();
        },
      );
    } catch (e, stackTrace) {
      Logger.error(
        'Error refreshing continue watching',
        tag: 'WatchHistoryController',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Refresh continue reading entries
  Future<void> _refreshContinueReading() async {
    if (_isLoading) return;

    try {
      final result = await repository.getContinueReading(limit: 20);
      result.fold(
        (failure) => Logger.error(
          'Failed to refresh continue reading',
          tag: 'WatchHistoryController',
          error: failure,
        ),
        (entries) {
          _continueReading = entries;
          notifyListeners();
        },
      );
    } catch (e, stackTrace) {
      Logger.error(
        'Error refreshing continue reading',
        tag: 'WatchHistoryController',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Get playback position for a video episode
  Future<int?> getVideoPosition({
    required String mediaId,
    required MediaType mediaType,
    required String sourceId,
    int? episodeNumber,
  }) async {
    try {
      final entryId = WatchHistoryEntry.generateId(
        mediaType,
        mediaId,
        sourceId,
      );

      final result = await repository.getEntry(entryId);
      return result.fold(
        (failure) {
          Logger.debug(
            'No saved position found for $mediaId',
            tag: 'WatchHistoryController',
          );
          return null;
        },
        (entry) {
          if (entry?.playbackPositionMs != null) {
            Logger.debug(
              'Found saved position for $mediaId: ${entry!.playbackPositionMs}ms',
              tag: 'WatchHistoryController',
            );
          }
          return entry?.playbackPositionMs;
        },
      );
    } catch (e, stackTrace) {
      Logger.error(
        'Error getting video position',
        tag: 'WatchHistoryController',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Get watch history entry for a specific media
  Future<WatchHistoryEntry?> getEntryForMedia(
    String mediaId,
    String sourceId,
    MediaType mediaType,
  ) async {
    try {
      final entryId = WatchHistoryEntry.generateId(
        mediaType,
        mediaId,
        sourceId,
      );

      final result = await repository.getEntry(entryId);
      return result.fold((failure) => null, (entry) => entry);
    } catch (e, stackTrace) {
      Logger.error(
        'Error getting entry for media $mediaId',
        tag: 'WatchHistoryController',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Get reading position for a chapter
  Future<int?> getReadingPosition({
    required String mediaId,
    required MediaType mediaType,
    required String sourceId,
    int? chapterNumber,
  }) async {
    try {
      final entryId = WatchHistoryEntry.generateId(
        mediaType,
        mediaId,
        sourceId,
      );

      final result = await repository.getEntry(entryId);
      return result.fold(
        (failure) {
          Logger.debug(
            'No saved reading position found for $mediaId',
            tag: 'WatchHistoryController',
          );
          return null;
        },
        (entry) {
          if (entry?.pageNumber != null) {
            Logger.debug(
              'Found saved reading position for $mediaId: page ${entry!.pageNumber}',
              tag: 'WatchHistoryController',
            );
          }
          return entry?.pageNumber;
        },
      );
    } catch (e, stackTrace) {
      Logger.error(
        'Error getting reading position',
        tag: 'WatchHistoryController',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Trigger sync if the entry has tracking configured
  Future<void> _triggerSyncIfTracked(WatchHistoryEntry entry) async {
    try {
      // Check if entry has a normalized ID (indicates tracking is configured)
      if (entry.normalizedId == null) {
        Logger.debug(
          'Entry "${entry.title}" has no tracking configured, skipping sync',
          tag: 'WatchHistoryController',
        );
        return;
      }

      Logger.info(
        'Entry "${entry.title}" has tracking, triggering sync',
        tag: 'WatchHistoryController',
      );

      // Try to get the sync service from DI if available
      // This is optional - sync can be triggered manually from UI
      // For now, just log that sync should be triggered
      // The actual sync will be called from UI when user initiates it
    } catch (e) {
      Logger.warning(
        'Failed to trigger sync for "${entry.title}": $e',
        tag: 'WatchHistoryController',
      );
    }
  }
}
