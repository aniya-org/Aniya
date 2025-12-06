import 'dart:io' as io;
import 'package:dartz/dartz.dart';
import 'package:background_downloader/background_downloader.dart';
import 'package:path_provider/path_provider.dart';
import '../domain/entities/download_entity.dart';
import '../domain/repositories/download_repository.dart';
import '../utils/logger.dart';

/// Service for managing background downloads
class DownloadService {
  final DownloadRepository _repository;

  DownloadService({required DownloadRepository repository})
    : _repository = repository;

  /// Initialize the download service
  Future<void> initialize() async {
    Logger.info('Initializing DownloadService', tag: 'DownloadService');

    // Configure background downloader
    await FileDownloader().configure(
      globalConfig: [(Config.requestTimeout, const Duration(seconds: 100))],
      androidConfig: [(Config.useCacheDir, Config.whenAble)],
      iOSConfig: [
        (Config.localize, {'Cancel': 'Cancel'}),
      ],
    );

    // Register update callback
    FileDownloader().updates.listen(_handleDownloadUpdate);

    Logger.info(
      'DownloadService initialized successfully',
      tag: 'DownloadService',
    );
  }

  /// Add a download to the queue
  Future<Either<Exception, DownloadEntity>> addDownload({
    required String url,
    required String mediaId,
    required String mediaTitle,
    String? episodeId,
    String? chapterId,
    int? episodeNumber,
    double? chapterNumber,
    String? filename,
    String? group,
  }) async {
    try {
      Logger.info('Adding download: $mediaTitle', tag: 'DownloadService');

      // Get downloads directory
      final directory = await getApplicationDocumentsDirectory();
      final downloadsDir = io.Directory('${directory.path}/downloads');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      // Generate safe filename
      final safeFilename =
          filename ??
          _generateSafeFilename(mediaTitle, episodeNumber, chapterNumber);

      // Generate unique download ID
      final downloadId = _generateDownloadId(mediaId, episodeId, chapterId);

      // Create download entity
      final download = DownloadEntity(
        id: downloadId,
        mediaId: mediaId,
        mediaTitle: mediaTitle,
        episodeId: episodeId,
        chapterId: chapterId,
        episodeNumber: episodeNumber,
        chapterNumber: chapterNumber,
        url: url,
        localPath: '${downloadsDir.path}/$safeFilename',
        status: DownloadStatus.queued,
        progress: 0.0,
        totalBytes: 0,
        downloadedBytes: 0,
        createdAt: DateTime.now(),
      );

      // Save to repository
      final result = await _repository.addDownload(download);
      if (result.isLeft()) {
        Logger.error(
          'Failed to save download to repository',
          tag: 'DownloadService',
          error: result.fold((l) => l, (r) => null),
        );
        return Left(Exception('Failed to save download to repository'));
      }

      // Create download task for background downloader
      final task = DownloadTask(
        url: url,
        filename: safeFilename,
        directory: downloadsDir.path,
        group: group ?? 'default',
        updates: Updates.statusAndProgress,
        metaData: downloadId,
      );

      // Enqueue the download
      final successfullyEnqueued = await FileDownloader().enqueue(task);
      if (successfullyEnqueued) {
        Logger.info(
          'Download enqueued successfully: ${download.id}',
          tag: 'DownloadService',
        );
        return Right(download);
      } else {
        Logger.error(
          'Failed to enqueue download: ${download.id}',
          tag: 'DownloadService',
        );
        return Left(Exception('Failed to enqueue download'));
      }
    } catch (e, stackTrace) {
      Logger.error(
        'Error adding download',
        tag: 'DownloadService',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(e is Exception ? e : Exception(e.toString()));
    }
  }

  /// Get all downloads
  Future<Either<Exception, List<DownloadEntity>>> getAllDownloads() async {
    try {
      final result = await _repository.getAllDownloads();
      return result.fold(
        (failure) => Left(Exception('Failed to get downloads')),
        (downloads) => Right(downloads),
      );
    } catch (e) {
      Logger.error(
        'Error getting all downloads',
        tag: 'DownloadService',
        error: e,
      );
      return Left(e is Exception ? e : Exception(e.toString()));
    }
  }

  /// Get download by ID
  Future<Either<Exception, DownloadEntity>> getDownload(String id) async {
    try {
      final result = await _repository.getDownloadById(id);
      return result.fold(
        (failure) => Left(Exception('Download not found')),
        (download) => Right(download),
      );
    } catch (e) {
      Logger.error(
        'Error getting download: $id',
        tag: 'DownloadService',
        error: e,
      );
      return Left(e is Exception ? e : Exception(e.toString()));
    }
  }

  /// Cancel download
  Future<Either<Exception, bool>> cancelDownload(String id) async {
    try {
      Logger.info('Cancelling download: $id', tag: 'DownloadService');

      // Find the task with this downloadId
      final records = await FileDownloader().database.allRecords();
      final record = records.cast<TaskRecord?>().firstWhere(
        (r) => r?.task.metaData == id,
        orElse: () => null,
      );

      if (record == null) {
        return Left(Exception('Download task not found'));
      }

      // Cancel the task
      await FileDownloader().cancelTasksWithIds([record.task.taskId]);

      // Update status in repository
      final result = await _repository.updateDownloadStatus(
        id,
        DownloadStatus.cancelled,
      );
      return result.fold(
        (failure) => Left(Exception('Failed to update download status')),
        (download) => Right(true),
      );
    } catch (e, stackTrace) {
      Logger.error(
        'Error cancelling download',
        tag: 'DownloadService',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(e is Exception ? e : Exception(e.toString()));
    }
  }

  /// Remove download
  Future<Either<Exception, bool>> removeDownload(String id) async {
    try {
      Logger.info('Removing download: $id', tag: 'DownloadService');

      // Get download details first
      final downloadResult = await _repository.getDownloadById(id);
      if (downloadResult.isLeft()) {
        return Left(Exception('Download not found'));
      }

      final download = downloadResult.getOrElse(
        () => throw Exception('Download not found'),
      );

      // Delete the file if it exists
      final file = io.File(download.localPath);
      if (await file.exists()) {
        await file.delete();
      }

      // Find and remove the task
      final records = await FileDownloader().database.allRecords();
      TaskRecord? record;
      try {
        record = records.firstWhere((r) => r.task.metaData == id);
      } catch (e) {
        record = null;
      }

      if (record != null) {
        await FileDownloader().cancelTasksWithIds([record.task.taskId]);
      }

      // Remove from repository
      final result = await _repository.deleteDownload(id, deleteFile: false);
      return result.fold(
        (failure) =>
            Left(Exception('Failed to remove download from repository')),
        (_) => Right(true),
      );
    } catch (e, stackTrace) {
      Logger.error(
        'Error removing download',
        tag: 'DownloadService',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(e is Exception ? e : Exception(e.toString()));
    }
  }

  /// Update download progress
  Future<Either<Exception, DownloadEntity>> updateDownloadProgress(
    String id,
    double progress,
    int totalBytes,
  ) async {
    try {
      final downloadedBytes = (progress * totalBytes).toInt();
      final result = await _repository.updateDownloadProgress(
        id,
        downloadedBytes,
        totalBytes,
      );
      return result.fold(
        (failure) => Left(Exception('Failed to update progress')),
        (download) => Right(download),
      );
    } catch (e) {
      Logger.error(
        'Error updating download progress: $id',
        tag: 'DownloadService',
        error: e,
      );
      return Left(e is Exception ? e : Exception(e.toString()));
    }
  }

  /// Pause a download
  Future<Either<Exception, bool>> pauseDownload(String downloadId) async {
    try {
      Logger.info('Pausing download: $downloadId', tag: 'DownloadService');

      // Find the task with this downloadId
      final records = await FileDownloader().database.allRecords();
      final record = records.firstWhere(
        (r) => r.task.metaData == downloadId,
        orElse: () => throw Exception('Task not found'),
      );

      // Pause the task
      await FileDownloader().pause(record.task as DownloadTask);

      // Update status in repository
      final result = await _repository.updateDownloadStatus(
        downloadId,
        DownloadStatus.paused,
      );
      return result.fold(
        (failure) => Left(Exception('Failed to update download status')),
        (download) => Right(true),
      );
    } catch (e, stackTrace) {
      Logger.error(
        'Error pausing download',
        tag: 'DownloadService',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(e is Exception ? e : Exception(e.toString()));
    }
  }

  /// Resume a download
  Future<Either<Exception, bool>> resumeDownload(String downloadId) async {
    try {
      Logger.info('Resuming download: $downloadId', tag: 'DownloadService');

      // Find the task with this downloadId
      final records = await FileDownloader().database.allRecords();
      final record = records.firstWhere(
        (r) => r.task.metaData == downloadId,
        orElse: () => throw Exception('Task not found'),
      );

      // Resume the task
      await FileDownloader().resume(record.task as DownloadTask);

      // Update status in repository
      final result = await _repository.updateDownloadStatus(
        downloadId,
        DownloadStatus.downloading,
      );
      return result.fold(
        (failure) => Left(Exception('Failed to update download status')),
        (download) => Right(true),
      );
    } catch (e, stackTrace) {
      Logger.error(
        'Error resuming download',
        tag: 'DownloadService',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(e is Exception ? e : Exception(e.toString()));
    }
  }

  /// Handle download updates from background downloader
  void _handleDownloadUpdate(TaskUpdate update) {
    if (update is TaskStatusUpdate) {
      _handleStatusUpdate(update);
    } else if (update is TaskProgressUpdate) {
      _handleProgressUpdate(update);
    }
  }

  /// Handle status updates
  void _handleStatusUpdate(TaskStatusUpdate update) {
    final downloadId = update.task.metaData as String?;
    if (downloadId == null) return;

    DownloadStatus status;
    switch (update.status) {
      case TaskStatus.enqueued:
        status = DownloadStatus.queued;
        break;
      case TaskStatus.running:
        status = DownloadStatus.downloading;
        break;
      case TaskStatus.paused:
        status = DownloadStatus.paused;
        break;
      case TaskStatus.complete:
        status = DownloadStatus.completed;
        break;
      case TaskStatus.canceled:
        status = DownloadStatus.cancelled;
        break;
      case TaskStatus.failed:
        status = DownloadStatus.failed;
        break;
      default:
        return;
    }

    // Update status in repository
    _repository
        .updateDownloadStatus(downloadId, status)
        .then(
          (result) => result.fold(
            (failure) {
              Logger.error(
                'Failed to update download status',
                tag: 'DownloadService',
                error: failure,
              );
            },
            (download) {
              Logger.debug(
                'Download status updated: $downloadId -> $status',
                tag: 'DownloadService',
              );
            },
          ),
        );
  }

  /// Handle progress updates
  void _handleProgressUpdate(TaskProgressUpdate update) {
    final downloadId = update.task.metaData as String?;
    if (downloadId == null) return;

    // Update progress in repository
    final totalBytes = update.expectedFileSize;
    final downloadedBytes = (update.progress * totalBytes).toInt();
    _repository
        .updateDownloadProgress(downloadId, downloadedBytes, totalBytes)
        .then(
          (result) => result.fold(
            (failure) {
              Logger.error(
                'Failed to update download progress',
                tag: 'DownloadService',
                error: failure,
              );
            },
            (download) {
              // Progress updates are frequent, log only at debug level
              Logger.debug(
                'Download progress: $downloadId -> ${(update.progress * 100).toInt()}%',
                tag: 'DownloadService',
              );
            },
          ),
        );
  }

  /// Generate a safe filename
  String _generateSafeFilename(
    String mediaTitle,
    int? episodeNumber,
    double? chapterNumber,
  ) {
    // Remove invalid characters
    String safeTitle = mediaTitle
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
        .replaceAll(' ', '_')
        .toLowerCase();

    // Add episode/chapter number if available
    String suffix = '';
    if (episodeNumber != null) {
      suffix = '_e${episodeNumber.toString().padLeft(2, '0')}';
    } else if (chapterNumber != null) {
      suffix = '_c${chapterNumber.toString().padLeft(3, '0')}';
    }

    return '$safeTitle$suffix.mp4';
  }

  /// Generate a unique download ID
  String _generateDownloadId(
    String mediaId,
    String? episodeId,
    String? chapterId,
  ) {
    final parts = <String>[mediaId];
    if (episodeId != null) parts.add(episodeId);
    if (chapterId != null) parts.add(chapterId);
    return parts.join('_');
  }
}
