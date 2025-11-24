import 'package:dartz/dartz.dart';
import '../entities/download_entity.dart';
import '../../error/failures.dart';

/// Repository interface for download management operations
/// Provides methods to manage downloads and offline storage
abstract class DownloadRepository {
  /// Get all downloads
  ///
  /// Returns a list of all download items
  Future<Either<Failure, List<DownloadEntity>>> getAllDownloads();

  /// Get downloads by status
  ///
  /// [status] - The status to filter by
  /// Returns a list of downloads with the specified status
  Future<Either<Failure, List<DownloadEntity>>> getDownloadsByStatus(
    DownloadStatus status,
  );

  /// Get download by ID
  ///
  /// [id] - The download ID
  /// Returns the download entity if found
  Future<Either<Failure, DownloadEntity>> getDownloadById(String id);

  /// Add a download to the queue
  ///
  /// [download] - The download entity to add
  /// Returns the added download entity
  Future<Either<Failure, DownloadEntity>> addDownload(DownloadEntity download);

  /// Update download progress
  ///
  /// [id] - The download ID
  /// [downloadedBytes] - The number of bytes downloaded
  /// [totalBytes] - The total number of bytes
  /// Returns the updated download entity
  Future<Either<Failure, DownloadEntity>> updateDownloadProgress(
    String id,
    int downloadedBytes,
    int totalBytes,
  );

  /// Update download status
  ///
  /// [id] - The download ID
  /// [status] - The new status
  /// Returns the updated download entity
  Future<Either<Failure, DownloadEntity>> updateDownloadStatus(
    String id,
    DownloadStatus status,
  );

  /// Pause a download
  ///
  /// [id] - The download ID
  /// Returns the updated download entity
  Future<Either<Failure, DownloadEntity>> pauseDownload(String id);

  /// Resume a download
  ///
  /// [id] - The download ID
  /// Returns the updated download entity
  Future<Either<Failure, DownloadEntity>> resumeDownload(String id);

  /// Cancel a download
  ///
  /// [id] - The download ID
  /// Returns the updated download entity
  Future<Either<Failure, DownloadEntity>> cancelDownload(String id);

  /// Delete a download
  ///
  /// [id] - The download ID
  /// [deleteFile] - Whether to delete the local file
  /// Returns void on success
  Future<Either<Failure, void>> deleteDownload(
    String id, {
    bool deleteFile = true,
  });

  /// Check if content is downloaded
  ///
  /// [mediaId] - The media ID
  /// [episodeId] - The episode ID (optional)
  /// [chapterId] - The chapter ID (optional)
  /// Returns true if the content is downloaded
  Future<Either<Failure, bool>> isContentDownloaded({
    required String mediaId,
    String? episodeId,
    String? chapterId,
  });

  /// Get local file path for downloaded content
  ///
  /// [mediaId] - The media ID
  /// [episodeId] - The episode ID (optional)
  /// [chapterId] - The chapter ID (optional)
  /// Returns the local file path if content is downloaded
  Future<Either<Failure, String?>> getLocalFilePath({
    required String mediaId,
    String? episodeId,
    String? chapterId,
  });
}
