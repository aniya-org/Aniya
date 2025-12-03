import 'package:flutter/foundation.dart';
import '../domain/entities/watch_history_entry.dart';
import '../domain/entities/media_entity.dart';
import '../domain/repositories/watch_history_repository.dart';
import '../utils/logger.dart';

/// Controller for managing watch history across all media types
/// Provides filtered views for Continue Watching, Continue Reading, and per-type sections
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
      allResult.fold((failure) {
        _error = failure.message;
        Logger.error(
          'Failed to load watch history',
          tag: 'WatchHistoryController',
          error: failure,
        );
      }, (entries) => _allEntries = entries);

      // Load continue watching
      final watchingResult = await repository.getContinueWatching(limit: 20);
      watchingResult.fold(
        (failure) => Logger.error(
          'Failed to load continue watching',
          tag: 'WatchHistoryController',
          error: failure,
        ),
        (entries) => _continueWatching = entries,
      );

      // Load continue reading
      final readingResult = await repository.getContinueReading(limit: 20);
      readingResult.fold(
        (failure) => Logger.error(
          'Failed to load continue reading',
          tag: 'WatchHistoryController',
          error: failure,
        ),
        (entries) => _continueReading = entries,
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

  /// Load entries for a specific media type
  Future<void> loadEntriesForType(MediaType type) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await repository.getEntriesByMediaType(type);
      result.fold((failure) {
        _error = failure.message;
        Logger.error(
          'Failed to load entries for type $type',
          tag: 'WatchHistoryController',
          error: failure,
        );
      }, (entries) => _entriesByType[type] = entries);
    } catch (e, stackTrace) {
      _error = 'An unexpected error occurred';
      Logger.error(
        'Unexpected error loading entries for type',
        tag: 'WatchHistoryController',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update video playback progress
  /// Call this from video player when progress changes
  Future<void> updateVideoProgress({
    required String mediaId,
    required MediaType mediaType,
    required String title,
    String? coverImage,
    required String sourceId,
    required String sourceName,
    required int playbackPositionMs,
    int? totalDurationMs,
    int? episodeNumber,
    String? episodeId,
    String? episodeTitle,
    String? normalizedId,
  }) async {
    try {
      // Generate entry ID
      final entryId = WatchHistoryEntry.generateId(
        mediaType,
        mediaId,
        sourceId,
      );

      // Check if entry exists
      final existingResult = await repository.getEntry(entryId);

      await existingResult.fold(
        (failure) async {
          Logger.error(
            'Failed to check existing entry',
            tag: 'WatchHistoryController',
            error: failure,
          );
        },
        (existing) async {
          if (existing != null) {
            // Update existing entry
            await repository.updateVideoProgress(
              entryId: entryId,
              playbackPositionMs: playbackPositionMs,
              totalDurationMs: totalDurationMs,
              episodeNumber: episodeNumber,
              episodeId: episodeId,
              episodeTitle: episodeTitle,
            );
          } else {
            // Create new entry
            final entry = repository.createEntry(
              mediaId: mediaId,
              mediaType: mediaType,
              title: title,
              coverImage: coverImage,
              sourceId: sourceId,
              sourceName: sourceName,
              normalizedId: normalizedId,
            );

            // Add video-specific data
            final videoEntry = WatchHistoryEntry(
              id: entry.id,
              mediaId: entry.mediaId,
              normalizedId: entry.normalizedId,
              mediaType: entry.mediaType,
              title: entry.title,
              coverImage: entry.coverImage,
              sourceId: entry.sourceId,
              sourceName: entry.sourceName,
              episodeNumber: episodeNumber,
              episodeId: episodeId,
              episodeTitle: episodeTitle,
              playbackPositionMs: playbackPositionMs,
              totalDurationMs: totalDurationMs,
              createdAt: entry.createdAt,
              lastPlayedAt: entry.lastPlayedAt,
            );

            await repository.upsertEntry(videoEntry);
          }
        },
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

  /// Update reading progress
  /// Call this from manga/novel reader when progress changes
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
  }) async {
    print('DEBUG: WatchHistoryController.updateReadingProgress called');
    print('DEBUG: mediaId: $mediaId');
    print('DEBUG: mediaType: $mediaType');
    print('DEBUG: title: $title');
    print('DEBUG: sourceId: $sourceId');
    print('DEBUG: pageNumber: $pageNumber');
    print('DEBUG: totalPages: $totalPages');
    print('DEBUG: chapterNumber: $chapterNumber');
    print('DEBUG: chapterId: $chapterId');

    try {
      // Generate entry ID
      final entryId = WatchHistoryEntry.generateId(
        mediaType,
        mediaId,
        sourceId,
      );
      print('DEBUG: Generated entryId: $entryId');

      // Check if entry exists
      final existingResult = await repository.getEntry(entryId);

      await existingResult.fold(
        (failure) async {
          Logger.error(
            'Failed to check existing entry',
            tag: 'WatchHistoryController',
            error: failure,
          );
        },
        (existing) async {
          print('DEBUG: Existing entry: $existing');
          if (existing != null) {
            print('DEBUG: Updating existing entry');
            // Update existing entry
            await repository.updateReadingProgress(
              entryId: entryId,
              pageNumber: pageNumber,
              totalPages: totalPages,
              chapterNumber: chapterNumber,
              chapterId: chapterId,
              chapterTitle: chapterTitle,
              volumeNumber: volumeNumber,
            );
            print('DEBUG: Updated existing entry');
          } else {
            print('DEBUG: Creating new entry');
            // Create new entry
            final entry = repository.createEntry(
              mediaId: mediaId,
              mediaType: mediaType,
              title: title,
              coverImage: coverImage,
              sourceId: sourceId,
              sourceName: sourceName,
              normalizedId: normalizedId,
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
            print('DEBUG: Created and upserted new entry');
          }
        },
      );

      // Refresh continue reading
      await _refreshContinueReading();
      print('DEBUG: Refreshed continue reading');
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
  Future<void> markCompleted(String entryId) async {
    try {
      final result = await repository.markCompleted(entryId);
      result.fold(
        (failure) => Logger.error(
          'Failed to mark as completed',
          tag: 'WatchHistoryController',
          error: failure,
        ),
        (_) {
          // Refresh lists
          _refreshContinueWatching();
          _refreshContinueReading();
        },
      );
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to mark as completed',
        tag: 'WatchHistoryController',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Remove an entry from history
  Future<void> removeEntry(String entryId) async {
    try {
      final result = await repository.removeEntry(entryId);
      result.fold(
        (failure) => Logger.error(
          'Failed to remove entry',
          tag: 'WatchHistoryController',
          error: failure,
        ),
        (_) {
          // Remove from local lists
          _allEntries.removeWhere((e) => e.id == entryId);
          _continueWatching.removeWhere((e) => e.id == entryId);
          _continueReading.removeWhere((e) => e.id == entryId);
          for (final type in _entriesByType.keys) {
            _entriesByType[type]?.removeWhere((e) => e.id == entryId);
          }
          notifyListeners();
        },
      );
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
      final result = await repository.clearAll();
      result.fold(
        (failure) => Logger.error(
          'Failed to clear history',
          tag: 'WatchHistoryController',
          error: failure,
        ),
        (_) {
          _allEntries = [];
          _continueWatching = [];
          _continueReading = [];
          _entriesByType = {};
          _entriesCountByType = {};
          notifyListeners();
        },
      );
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to clear history',
        tag: 'WatchHistoryController',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Get entry for a specific media (for checking if in history)
  Future<WatchHistoryEntry?> getEntryForMedia(
    String mediaId,
    String sourceId,
    MediaType type,
  ) async {
    final entryId = WatchHistoryEntry.generateId(type, mediaId, sourceId);
    final result = await repository.getEntry(entryId);
    return result.fold((failure) => null, (entry) => entry);
  }

  // Private helpers
  Future<void> _refreshContinueWatching() async {
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
  }

  Future<void> _refreshContinueReading() async {
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
  }
}
