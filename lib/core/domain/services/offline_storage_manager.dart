import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:path_provider/path_provider.dart';
import '../repositories/download_repository.dart';
import '../../error/failures.dart';
import '../../utils/logger.dart';

/// Service for managing offline storage
/// Handles marking content as offline-available and managing local file storage
class OfflineStorageManager {
  final DownloadRepository _downloadRepository;
  String? _storageDirectory;

  OfflineStorageManager({required DownloadRepository downloadRepository})
    : _downloadRepository = downloadRepository;

  /// Initialize the storage manager
  /// Sets up the storage directory
  Future<Either<Failure, void>> initialize() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      _storageDirectory = '${directory.path}/downloads';

      // Create directory if it doesn't exist
      final dir = Directory(_storageDirectory!);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
        Logger.info('Created downloads directory: $_storageDirectory');
      }

      return const Right(null);
    } catch (e) {
      Logger.error('Error initializing offline storage: $e');
      return Left(
        StorageFailure('Failed to initialize storage: ${e.toString()}'),
      );
    }
  }

  /// Get the storage directory path
  Future<Either<Failure, String>> getStorageDirectory() async {
    if (_storageDirectory == null) {
      final result = await initialize();
      if (result.isLeft()) {
        return Left(StorageFailure('Storage not initialized'));
      }
    }
    return Right(_storageDirectory!);
  }

  /// Generate a local file path for content
  ///
  /// [mediaId] - The media ID
  /// [episodeId] - The episode ID (optional)
  /// [chapterId] - The chapter ID (optional)
  /// [extension] - The file extension (default: mp4)
  /// Returns the generated file path
  Future<Either<Failure, String>> generateLocalFilePath({
    required String mediaId,
    String? episodeId,
    String? chapterId,
    String extension = 'mp4',
  }) async {
    try {
      final dirResult = await getStorageDirectory();

      return dirResult.fold((failure) => Left(failure), (directory) {
        // Create a safe filename
        final sanitizedMediaId = _sanitizeFilename(mediaId);
        String filename;

        if (episodeId != null) {
          final sanitizedEpisodeId = _sanitizeFilename(episodeId);
          filename = '${sanitizedMediaId}_ep_$sanitizedEpisodeId.$extension';
        } else if (chapterId != null) {
          final sanitizedChapterId = _sanitizeFilename(chapterId);
          filename = '${sanitizedMediaId}_ch_$sanitizedChapterId.$extension';
        } else {
          filename = '$sanitizedMediaId.$extension';
        }

        final path = '$directory/$filename';
        Logger.debug('Generated file path: $path');
        return Right(path);
      });
    } catch (e) {
      Logger.error('Error generating file path: $e');
      return Left(
        StorageFailure('Failed to generate file path: ${e.toString()}'),
      );
    }
  }

  /// Check if content is available offline
  ///
  /// [mediaId] - The media ID
  /// [episodeId] - The episode ID (optional)
  /// [chapterId] - The chapter ID (optional)
  /// Returns true if content is available offline
  Future<Either<Failure, bool>> isContentAvailableOffline({
    required String mediaId,
    String? episodeId,
    String? chapterId,
  }) async {
    try {
      final result = await _downloadRepository.isContentDownloaded(
        mediaId: mediaId,
        episodeId: episodeId,
        chapterId: chapterId,
      );

      return result.fold((failure) => Left(failure), (isDownloaded) async {
        if (!isDownloaded) {
          return const Right(false);
        }

        // Verify file exists
        final pathResult = await _downloadRepository.getLocalFilePath(
          mediaId: mediaId,
          episodeId: episodeId,
          chapterId: chapterId,
        );

        return pathResult.fold((failure) => Left(failure), (path) async {
          if (path == null) {
            return const Right(false);
          }

          final file = File(path);
          final exists = await file.exists();
          return Right(exists);
        });
      });
    } catch (e) {
      Logger.error('Error checking offline availability: $e');
      return Left(
        StorageFailure('Failed to check offline status: ${e.toString()}'),
      );
    }
  }

  /// Get the local file path for offline content
  ///
  /// [mediaId] - The media ID
  /// [episodeId] - The episode ID (optional)
  /// [chapterId] - The chapter ID (optional)
  /// Returns the local file path if available
  Future<Either<Failure, String?>> getOfflineContentPath({
    required String mediaId,
    String? episodeId,
    String? chapterId,
  }) async {
    try {
      final result = await _downloadRepository.getLocalFilePath(
        mediaId: mediaId,
        episodeId: episodeId,
        chapterId: chapterId,
      );

      return result.fold((failure) => Left(failure), (path) async {
        if (path == null) {
          return const Right(null);
        }

        // Verify file exists
        final file = File(path);
        if (!await file.exists()) {
          Logger.warning('File not found: $path');
          return const Right(null);
        }

        return Right(path);
      });
    } catch (e) {
      Logger.error('Error getting offline content path: $e');
      return Left(
        StorageFailure('Failed to get offline path: ${e.toString()}'),
      );
    }
  }

  /// Get the size of a file in bytes
  ///
  /// [path] - The file path
  /// Returns the file size in bytes
  Future<Either<Failure, int>> getFileSize(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        return Left(StorageFailure('File not found: $path'));
      }

      final size = await file.length();
      return Right(size);
    } catch (e) {
      Logger.error('Error getting file size: $e');
      return Left(StorageFailure('Failed to get file size: ${e.toString()}'));
    }
  }

  /// Get total storage used by downloads
  ///
  /// Returns the total size in bytes
  Future<Either<Failure, int>> getTotalStorageUsed() async {
    try {
      final dirResult = await getStorageDirectory();

      return dirResult.fold((failure) => Left(failure), (directory) async {
        final dir = Directory(directory);
        if (!await dir.exists()) {
          return const Right(0);
        }

        int totalSize = 0;
        await for (final entity in dir.list(recursive: true)) {
          if (entity is File) {
            try {
              totalSize += await entity.length();
            } catch (e) {
              Logger.warning('Error getting file size for ${entity.path}: $e');
            }
          }
        }

        Logger.info('Total storage used: $totalSize bytes');
        return Right(totalSize);
      });
    } catch (e) {
      Logger.error('Error calculating total storage: $e');
      return Left(
        StorageFailure('Failed to calculate storage: ${e.toString()}'),
      );
    }
  }

  /// Get available storage space
  ///
  /// Returns the available space in bytes
  Future<Either<Failure, int>> getAvailableStorage() async {
    try {
      final dirResult = await getStorageDirectory();

      return dirResult.fold((failure) => Left(failure), (directory) async {
        // Note: This is a simplified implementation
        // In production, you'd want to use platform-specific APIs
        // to get accurate available space
        Logger.info('Storage directory: $directory');
        return const Right(0); // Placeholder
      });
    } catch (e) {
      Logger.error('Error getting available storage: $e');
      return Left(
        StorageFailure('Failed to get available storage: ${e.toString()}'),
      );
    }
  }

  /// Clear all offline content
  ///
  /// Deletes all downloaded files
  Future<Either<Failure, void>> clearAllOfflineContent() async {
    try {
      final dirResult = await getStorageDirectory();

      return dirResult.fold((failure) => Left(failure), (directory) async {
        final dir = Directory(directory);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
          await dir.create(recursive: true);
          Logger.info('Cleared all offline content');
        }
        return const Right(null);
      });
    } catch (e) {
      Logger.error('Error clearing offline content: $e');
      return Left(StorageFailure('Failed to clear content: ${e.toString()}'));
    }
  }

  /// Sanitize a filename by removing invalid characters
  String _sanitizeFilename(String filename) {
    // Remove or replace invalid characters
    return filename
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
  }
}
