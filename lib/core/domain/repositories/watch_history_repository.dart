import 'package:dartz/dartz.dart';
import '../entities/watch_history_entry.dart';
import '../entities/media_entity.dart';
import '../../error/failures.dart';

/// Repository interface for watch history management
/// Supports both video-based (anime, movies, TV) and reading-based (manga, novels) content
abstract class WatchHistoryRepository {
  /// Get all watch history entries
  Future<Either<Failure, List<WatchHistoryEntry>>> getAllEntries();

  /// Get watch history entries filtered by media type
  Future<Either<Failure, List<WatchHistoryEntry>>> getEntriesByMediaType(
    MediaType type,
  );

  /// Get video entries for "Continue Watching" section
  Future<Either<Failure, List<WatchHistoryEntry>>> getContinueWatching({
    int limit = 20,
  });

  /// Get reading entries for "Continue Reading" section
  Future<Either<Failure, List<WatchHistoryEntry>>> getContinueReading({
    int limit = 20,
  });

  /// Get recent entries across all types
  Future<Either<Failure, List<WatchHistoryEntry>>> getRecentEntries({
    int limit = 20,
  });

  /// Get a specific entry by ID
  Future<Either<Failure, WatchHistoryEntry?>> getEntry(String id);

  /// Get entry by normalized ID (for cross-source matching)
  Future<Either<Failure, WatchHistoryEntry?>> getEntryByNormalizedId(
    String normalizedId,
  );

  /// Add or update a watch history entry
  Future<Either<Failure, Unit>> upsertEntry(WatchHistoryEntry entry);

  /// Update video playback progress
  ///
  /// [entryId] - The ID of the watch history entry
  /// [playbackPositionMs] - Current playback position in milliseconds
  /// [totalDurationMs] - Total duration of the video in milliseconds
  /// [episodeNumber] - Current episode number (optional)
  /// [episodeId] - Episode identifier from source (optional)
  /// [episodeTitle] - Episode title (optional)
  Future<Either<Failure, Unit>> updateVideoProgress({
    required String entryId,
    required int playbackPositionMs,
    int? totalDurationMs,
    int? episodeNumber,
    String? episodeId,
    String? episodeTitle,
  });

  /// Update reading progress
  ///
  /// [entryId] - The ID of the watch history entry
  /// [pageNumber] - Current page number
  /// [totalPages] - Total pages in current chapter (optional)
  /// [chapterNumber] - Current chapter number (optional)
  /// [chapterId] - Chapter identifier from source (optional)
  /// [chapterTitle] - Chapter title (optional)
  /// [volumeNumber] - Current volume number (optional)
  Future<Either<Failure, Unit>> updateReadingProgress({
    required String entryId,
    required int pageNumber,
    int? totalPages,
    int? chapterNumber,
    String? chapterId,
    String? chapterTitle,
    int? volumeNumber,
  });

  /// Mark an entry as completed
  Future<Either<Failure, Unit>> markCompleted(String entryId);

  /// Remove an entry from history
  Future<Either<Failure, Unit>> removeEntry(String entryId);

  /// Clear all watch history
  Future<Either<Failure, Unit>> clearAll();

  /// Get entries count by media type
  Future<Either<Failure, Map<MediaType, int>>> getEntriesCountByType();

  /// Create a new watch history entry from media details
  ///
  /// This is a convenience method that creates a properly formatted entry
  /// from media information
  WatchHistoryEntry createEntry({
    required String mediaId,
    required MediaType mediaType,
    required String title,
    String? coverImage,
    required String sourceId,
    required String sourceName,
    String? normalizedId,
  });
}
