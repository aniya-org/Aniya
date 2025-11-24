import 'package:dartz/dartz.dart';
import '../../domain/entities/download_entity.dart';
import '../../domain/repositories/download_repository.dart';
import '../../error/exceptions.dart';
import '../../error/failures.dart';
import '../../utils/logger.dart';
import '../datasources/download_local_data_source.dart';
import '../models/download_model.dart';

/// Implementation of DownloadRepository
/// Manages downloads using local data source
class DownloadRepositoryImpl implements DownloadRepository {
  final DownloadLocalDataSource _localDataSource;

  DownloadRepositoryImpl({required DownloadLocalDataSource localDataSource})
    : _localDataSource = localDataSource;

  @override
  Future<Either<Failure, List<DownloadEntity>>> getAllDownloads() async {
    try {
      final downloads = await _localDataSource.getAllDownloads();
      return Right(downloads.map((model) => model.toEntity()).toList());
    } on CacheException catch (e) {
      Logger.error('Cache exception getting all downloads: $e');
      return Left(StorageFailure(e.message));
    } catch (e) {
      Logger.error('Unexpected error getting all downloads: $e');
      return Left(StorageFailure('Failed to get downloads: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<DownloadEntity>>> getDownloadsByStatus(
    DownloadStatus status,
  ) async {
    try {
      final downloads = await _localDataSource.getDownloadsByStatus(status);
      return Right(downloads.map((model) => model.toEntity()).toList());
    } on CacheException catch (e) {
      Logger.error('Cache exception getting downloads by status: $e');
      return Left(StorageFailure(e.message));
    } catch (e) {
      Logger.error('Unexpected error getting downloads by status: $e');
      return Left(StorageFailure('Failed to get downloads: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, DownloadEntity>> getDownloadById(String id) async {
    try {
      final download = await _localDataSource.getDownloadById(id);
      if (download == null) {
        return Left(StorageFailure('Download not found: $id'));
      }
      return Right(download.toEntity());
    } on CacheException catch (e) {
      Logger.error('Cache exception getting download by ID: $e');
      return Left(StorageFailure(e.message));
    } catch (e) {
      Logger.error('Unexpected error getting download by ID: $e');
      return Left(StorageFailure('Failed to get download: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, DownloadEntity>> addDownload(
    DownloadEntity download,
  ) async {
    try {
      final model = DownloadModel.fromEntity(download);
      final addedModel = await _localDataSource.addDownload(model);
      return Right(addedModel.toEntity());
    } on CacheException catch (e) {
      Logger.error('Cache exception adding download: $e');
      return Left(StorageFailure(e.message));
    } catch (e) {
      Logger.error('Unexpected error adding download: $e');
      return Left(StorageFailure('Failed to add download: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, DownloadEntity>> updateDownloadProgress(
    String id,
    int downloadedBytes,
    int totalBytes,
  ) async {
    try {
      final download = await _localDataSource.getDownloadById(id);
      if (download == null) {
        return Left(StorageFailure('Download not found: $id'));
      }

      final progress = totalBytes > 0 ? downloadedBytes / totalBytes : 0.0;
      final updatedDownload = download.copyWith(
        downloadedBytes: downloadedBytes,
        totalBytes: totalBytes,
        progress: progress,
      );

      final result = await _localDataSource.updateDownload(updatedDownload);
      return Right(result.toEntity());
    } on CacheException catch (e) {
      Logger.error('Cache exception updating download progress: $e');
      return Left(StorageFailure(e.message));
    } catch (e) {
      Logger.error('Unexpected error updating download progress: $e');
      return Left(StorageFailure('Failed to update progress: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, DownloadEntity>> updateDownloadStatus(
    String id,
    DownloadStatus status,
  ) async {
    try {
      final download = await _localDataSource.getDownloadById(id);
      if (download == null) {
        return Left(StorageFailure('Download not found: $id'));
      }

      final updatedDownload = download.copyWith(
        status: status,
        completedAt: status == DownloadStatus.completed ? DateTime.now() : null,
      );

      final result = await _localDataSource.updateDownload(updatedDownload);
      return Right(result.toEntity());
    } on CacheException catch (e) {
      Logger.error('Cache exception updating download status: $e');
      return Left(StorageFailure(e.message));
    } catch (e) {
      Logger.error('Unexpected error updating download status: $e');
      return Left(StorageFailure('Failed to update status: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, DownloadEntity>> pauseDownload(String id) async {
    return await updateDownloadStatus(id, DownloadStatus.paused);
  }

  @override
  Future<Either<Failure, DownloadEntity>> resumeDownload(String id) async {
    return await updateDownloadStatus(id, DownloadStatus.downloading);
  }

  @override
  Future<Either<Failure, DownloadEntity>> cancelDownload(String id) async {
    return await updateDownloadStatus(id, DownloadStatus.cancelled);
  }

  @override
  Future<Either<Failure, void>> deleteDownload(
    String id, {
    bool deleteFile = true,
  }) async {
    try {
      await _localDataSource.deleteDownload(id, deleteFile: deleteFile);
      return const Right(null);
    } on CacheException catch (e) {
      Logger.error('Cache exception deleting download: $e');
      return Left(StorageFailure(e.message));
    } catch (e) {
      Logger.error('Unexpected error deleting download: $e');
      return Left(StorageFailure('Failed to delete download: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> isContentDownloaded({
    required String mediaId,
    String? episodeId,
    String? chapterId,
  }) async {
    try {
      final isDownloaded = await _localDataSource.isContentDownloaded(
        mediaId: mediaId,
        episodeId: episodeId,
        chapterId: chapterId,
      );
      return Right(isDownloaded);
    } on CacheException catch (e) {
      Logger.error('Cache exception checking download status: $e');
      return Left(StorageFailure(e.message));
    } catch (e) {
      Logger.error('Unexpected error checking download status: $e');
      return Left(StorageFailure('Failed to check download: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, String?>> getLocalFilePath({
    required String mediaId,
    String? episodeId,
    String? chapterId,
  }) async {
    try {
      final path = await _localDataSource.getLocalFilePath(
        mediaId: mediaId,
        episodeId: episodeId,
        chapterId: chapterId,
      );
      return Right(path);
    } on CacheException catch (e) {
      Logger.error('Cache exception getting local file path: $e');
      return Left(StorageFailure(e.message));
    } catch (e) {
      Logger.error('Unexpected error getting local file path: $e');
      return Left(StorageFailure('Failed to get file path: ${e.toString()}'));
    }
  }
}
