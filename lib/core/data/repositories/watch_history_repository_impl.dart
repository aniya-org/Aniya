import 'package:dartz/dartz.dart';

import '../../domain/entities/watch_history_entry.dart';
import '../../domain/entities/media_entity.dart';
import '../../domain/repositories/watch_history_repository.dart';
import '../../error/failures.dart';
import '../../error/exceptions.dart';
import '../datasources/watch_history_local_data_source.dart';
import '../models/watch_history_entry_model.dart';

/// Implementation of WatchHistoryRepository
/// Handles watch/read history with local storage
class WatchHistoryRepositoryImpl implements WatchHistoryRepository {
  final WatchHistoryLocalDataSource localDataSource;

  WatchHistoryRepositoryImpl({required this.localDataSource});

  @override
  Future<Either<Failure, List<WatchHistoryEntry>>> getAllEntries() async {
    try {
      final entries = await localDataSource.getAllEntries();
      return Right(entries.map((e) => e.toEntity()).toList());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get watch history: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, List<WatchHistoryEntry>>> getEntriesByMediaType(
    MediaType type,
  ) async {
    try {
      final entries = await localDataSource.getEntriesByMediaType(type);
      return Right(entries.map((e) => e.toEntity()).toList());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get entries by type: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, List<WatchHistoryEntry>>> getContinueWatching({
    int limit = 20,
  }) async {
    try {
      final entries = await localDataSource.getVideoEntries();
      // Filter to only include entries that are not completed
      final inProgress = entries
          .where((e) => e.completedAt == null && !e.isCurrentUnitCompleted)
          .take(limit)
          .toList();
      return Right(inProgress.map((e) => e.toEntity()).toList());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get continue watching: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, List<WatchHistoryEntry>>> getContinueReading({
    int limit = 20,
  }) async {
    try {
      final entries = await localDataSource.getReadingEntries();
      // Filter to only include entries that are not completed
      final inProgress = entries
          .where((e) => e.completedAt == null && !e.isCurrentUnitCompleted)
          .take(limit)
          .toList();
      return Right(inProgress.map((e) => e.toEntity()).toList());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get continue reading: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, List<WatchHistoryEntry>>> getRecentEntries({
    int limit = 20,
  }) async {
    try {
      final entries = await localDataSource.getRecentEntries(limit: limit);
      return Right(entries.map((e) => e.toEntity()).toList());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get recent entries: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, WatchHistoryEntry?>> getEntry(String id) async {
    try {
      final entry = await localDataSource.getEntry(id);
      return Right(entry?.toEntity());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to get entry: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, WatchHistoryEntry?>> getEntryByNormalizedId(
    String normalizedId,
  ) async {
    try {
      final entry = await localDataSource.getEntryByNormalizedId(normalizedId);
      return Right(entry?.toEntity());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get entry by normalized ID: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, WatchHistoryEntry?>> findConsolidatedEntry({
    required String title,
    required MediaType mediaType,
    int? releaseYear,
  }) async {
    try {
      final entry = await localDataSource.findConsolidatedEntry(
        title: title,
        mediaType: mediaType,
        releaseYear: releaseYear,
      );
      return Right(entry?.toEntity());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to find consolidated entry: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, Unit>> upsertEntry(WatchHistoryEntry entry) async {
    try {
      final model = WatchHistoryEntryModel.fromEntity(entry);
      await localDataSource.upsertEntry(model);
      return const Right(unit);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to upsert entry: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Unit>> updateVideoProgress({
    required String entryId,
    required int playbackPositionMs,
    int? totalDurationMs,
    int? episodeNumber,
    String? episodeId,
    String? episodeTitle,
  }) async {
    try {
      await localDataSource.updateVideoProgress(
        entryId: entryId,
        playbackPositionMs: playbackPositionMs,
        totalDurationMs: totalDurationMs,
        episodeNumber: episodeNumber,
        episodeId: episodeId,
        episodeTitle: episodeTitle,
      );
      return const Right(unit);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to update video progress: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, Unit>> updateReadingProgress({
    required String entryId,
    required int pageNumber,
    int? totalPages,
    int? chapterNumber,
    String? chapterId,
    String? chapterTitle,
    int? volumeNumber,
  }) async {
    try {
      await localDataSource.updateReadingProgress(
        entryId: entryId,
        pageNumber: pageNumber,
        totalPages: totalPages,
        chapterNumber: chapterNumber,
        chapterId: chapterId,
        chapterTitle: chapterTitle,
        volumeNumber: volumeNumber,
      );
      return const Right(unit);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to update reading progress: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, Unit>> markCompleted(String entryId) async {
    try {
      await localDataSource.markCompleted(entryId);
      return const Right(unit);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to mark as completed: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, Unit>> removeEntry(String entryId) async {
    try {
      await localDataSource.removeEntry(entryId);
      return const Right(unit);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to remove entry: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Unit>> clearAll() async {
    try {
      await localDataSource.clearAll();
      return const Right(unit);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to clear watch history: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, Map<MediaType, int>>> getEntriesCountByType() async {
    try {
      final counts = await localDataSource.getEntriesCountByType();
      return Right(counts);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get entries count: ${e.toString()}'),
      );
    }
  }

  @override
  WatchHistoryEntry createEntry({
    required String mediaId,
    required MediaType mediaType,
    required String title,
    String? coverImage,
    required String sourceId,
    required String sourceName,
    String? normalizedId,
    int? releaseYear,
  }) {
    final now = DateTime.now();
    final id = WatchHistoryEntry.generateId(mediaType, mediaId, sourceId);
    final normId =
        normalizedId ??
        WatchHistoryEntry.generateNormalizedId(title, mediaType);

    return WatchHistoryEntry(
      id: id,
      mediaId: mediaId,
      normalizedId: normId,
      mediaType: mediaType,
      title: title,
      coverImage: coverImage,
      sourceId: sourceId,
      sourceName: sourceName,
      releaseYear: releaseYear,
      createdAt: now,
      lastPlayedAt: now,
    );
  }
}
