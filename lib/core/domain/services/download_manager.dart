import 'dart:async';
import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:http/http.dart' as http;
import '../entities/download_entity.dart';
import '../repositories/download_repository.dart';
import '../../error/failures.dart';
import '../../utils/logger.dart';

/// Service for managing downloads
/// Handles download queue, pause/resume, and progress tracking
class DownloadManager {
  final DownloadRepository _repository;
  final http.Client _httpClient;
  final Map<String, StreamSubscription> _activeDownloads = {};
  final Map<String, bool> _pauseFlags = {};
  final StreamController<DownloadEntity> _progressController =
      StreamController<DownloadEntity>.broadcast();

  DownloadManager({
    required DownloadRepository repository,
    http.Client? httpClient,
  }) : _repository = repository,
       _httpClient = httpClient ?? http.Client();

  /// Stream of download progress updates
  Stream<DownloadEntity> get progressStream => _progressController.stream;

  /// Add a download to the queue and start downloading
  ///
  /// [download] - The download entity to add
  /// Returns the added download entity
  Future<Either<Failure, DownloadEntity>> addDownload(
    DownloadEntity download,
  ) async {
    try {
      // Add to repository
      final result = await _repository.addDownload(download);

      return result.fold((failure) => Left(failure), (addedDownload) async {
        // Start downloading
        await _startDownload(addedDownload);
        return Right(addedDownload);
      });
    } catch (e) {
      Logger.error('Error adding download: $e');
      return Left(StorageFailure('Failed to add download: ${e.toString()}'));
    }
  }

  /// Pause a download
  ///
  /// [id] - The download ID
  /// Returns the updated download entity
  Future<Either<Failure, DownloadEntity>> pauseDownload(String id) async {
    try {
      // Set pause flag
      _pauseFlags[id] = true;

      // Cancel active download stream
      await _activeDownloads[id]?.cancel();
      _activeDownloads.remove(id);

      // Update status in repository
      return await _repository.pauseDownload(id);
    } catch (e) {
      Logger.error('Error pausing download: $e');
      return Left(StorageFailure('Failed to pause download: ${e.toString()}'));
    }
  }

  /// Resume a download
  ///
  /// [id] - The download ID
  /// Returns the updated download entity
  Future<Either<Failure, DownloadEntity>> resumeDownload(String id) async {
    try {
      // Clear pause flag
      _pauseFlags.remove(id);

      // Get download from repository
      final downloadResult = await _repository.getDownloadById(id);

      return downloadResult.fold((failure) => Left(failure), (download) async {
        // Update status to downloading
        final updateResult = await _repository.updateDownloadStatus(
          id,
          DownloadStatus.downloading,
        );

        return updateResult.fold((failure) => Left(failure), (
          updatedDownload,
        ) async {
          // Resume downloading
          await _startDownload(updatedDownload);
          return Right(updatedDownload);
        });
      });
    } catch (e) {
      Logger.error('Error resuming download: $e');
      return Left(StorageFailure('Failed to resume download: ${e.toString()}'));
    }
  }

  /// Cancel a download
  ///
  /// [id] - The download ID
  /// Returns the updated download entity
  Future<Either<Failure, DownloadEntity>> cancelDownload(String id) async {
    try {
      // Set pause flag
      _pauseFlags[id] = true;

      // Cancel active download stream
      await _activeDownloads[id]?.cancel();
      _activeDownloads.remove(id);

      // Update status in repository
      return await _repository.cancelDownload(id);
    } catch (e) {
      Logger.error('Error cancelling download: $e');
      return Left(StorageFailure('Failed to cancel download: ${e.toString()}'));
    }
  }

  /// Delete a download
  ///
  /// [id] - The download ID
  /// [deleteFile] - Whether to delete the local file
  /// Returns void on success
  Future<Either<Failure, void>> deleteDownload(
    String id, {
    bool deleteFile = true,
  }) async {
    try {
      // Cancel if downloading
      await cancelDownload(id);

      // Delete from repository
      return await _repository.deleteDownload(id, deleteFile: deleteFile);
    } catch (e) {
      Logger.error('Error deleting download: $e');
      return Left(StorageFailure('Failed to delete download: ${e.toString()}'));
    }
  }

  /// Get all downloads
  Future<Either<Failure, List<DownloadEntity>>> getAllDownloads() async {
    return await _repository.getAllDownloads();
  }

  /// Get downloads by status
  Future<Either<Failure, List<DownloadEntity>>> getDownloadsByStatus(
    DownloadStatus status,
  ) async {
    return await _repository.getDownloadsByStatus(status);
  }

  /// Get download by ID
  Future<Either<Failure, DownloadEntity>> getDownloadById(String id) async {
    return await _repository.getDownloadById(id);
  }

  /// Start downloading a file
  Future<void> _startDownload(DownloadEntity download) async {
    if (_activeDownloads.containsKey(download.id)) {
      Logger.warning('Download already in progress: ${download.id}');
      return;
    }

    try {
      // Update status to downloading
      await _repository.updateDownloadStatus(
        download.id,
        DownloadStatus.downloading,
      );

      // Create directory if it doesn't exist
      final file = File(download.localPath);
      await file.parent.create(recursive: true);

      // Check if file exists (for resume)
      int startByte = 0;
      if (await file.exists()) {
        startByte = await file.length();
      }

      // Create request with range header for resume support
      final request = http.Request('GET', Uri.parse(download.url));
      if (startByte > 0) {
        request.headers['Range'] = 'bytes=$startByte-';
      }

      // Send request
      final response = await _httpClient.send(request);

      if (response.statusCode != 200 && response.statusCode != 206) {
        throw Exception('Failed to download: ${response.statusCode}');
      }

      // Get total bytes
      final totalBytes = (response.contentLength ?? 0) + startByte;

      // Open file for writing
      final sink = file.openWrite(mode: FileMode.append);
      int downloadedBytes = startByte;

      // Listen to response stream
      final subscription = response.stream.listen(
        (chunk) async {
          // Check if paused
          if (_pauseFlags[download.id] == true) {
            sink.close();
            return;
          }

          // Write chunk to file
          sink.add(chunk);
          downloadedBytes += chunk.length;

          // Update progress in repository
          final updateResult = await _repository.updateDownloadProgress(
            download.id,
            downloadedBytes,
            totalBytes,
          );

          // Emit progress update
          updateResult.fold(
            (failure) => Logger.error('Failed to update progress: $failure'),
            (updatedDownload) => _progressController.add(updatedDownload),
          );
        },
        onDone: () async {
          await sink.close();
          _activeDownloads.remove(download.id);

          // Check if completed or paused
          if (_pauseFlags[download.id] != true) {
            // Mark as completed
            final result = await _repository.updateDownloadStatus(
              download.id,
              DownloadStatus.completed,
            );

            result.fold(
              (failure) =>
                  Logger.error('Failed to mark as completed: $failure'),
              (completedDownload) => _progressController.add(completedDownload),
            );
          }
        },
        onError: (error) async {
          await sink.close();
          _activeDownloads.remove(download.id);

          Logger.error('Download error: $error');

          // Mark as failed
          await _repository.updateDownloadStatus(
            download.id,
            DownloadStatus.failed,
          );
        },
        cancelOnError: true,
      );

      _activeDownloads[download.id] = subscription;
    } catch (e) {
      Logger.error('Error starting download: $e');
      await _repository.updateDownloadStatus(
        download.id,
        DownloadStatus.failed,
      );
    }
  }

  /// Dispose resources
  void dispose() {
    for (final subscription in _activeDownloads.values) {
      subscription.cancel();
    }
    _activeDownloads.clear();
    _pauseFlags.clear();
    _progressController.close();
  }
}
