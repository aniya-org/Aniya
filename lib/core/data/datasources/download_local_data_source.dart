import 'dart:io';
import 'package:hive/hive.dart';
import '../models/download_model.dart';
import '../../domain/entities/download_entity.dart';
import '../../error/exceptions.dart';
import '../../utils/logger.dart';

/// Local data source for download management
/// Uses Hive for persistent storage
class DownloadLocalDataSource {
  static const String _boxName = 'downloads';
  late Box<DownloadModel> _box;

  /// Initialize the data source
  Future<void> init() async {
    try {
      _box = await Hive.openBox<DownloadModel>(_boxName);
      Logger.info('Download data source initialized');
    } catch (e) {
      Logger.error('Failed to initialize download data source: $e');
      throw CacheException('Failed to initialize download storage');
    }
  }

  /// Get all downloads
  Future<List<DownloadModel>> getAllDownloads() async {
    try {
      return _box.values.toList();
    } catch (e) {
      Logger.error('Error getting all downloads: $e');
      throw CacheException('Failed to get downloads');
    }
  }

  /// Get downloads by status
  Future<List<DownloadModel>> getDownloadsByStatus(
    DownloadStatus status,
  ) async {
    try {
      return _box.values
          .where((download) => download.status == status)
          .toList();
    } catch (e) {
      Logger.error('Error getting downloads by status: $e');
      throw CacheException('Failed to get downloads by status');
    }
  }

  /// Get download by ID
  Future<DownloadModel?> getDownloadById(String id) async {
    try {
      return _box.get(id);
    } catch (e) {
      Logger.error('Error getting download by ID: $e');
      throw CacheException('Failed to get download');
    }
  }

  /// Add a download
  Future<DownloadModel> addDownload(DownloadModel download) async {
    try {
      await _box.put(download.id, download);
      Logger.info('Download added: ${download.id}');
      return download;
    } catch (e) {
      Logger.error('Error adding download: $e');
      throw CacheException('Failed to add download');
    }
  }

  /// Update a download
  Future<DownloadModel> updateDownload(DownloadModel download) async {
    try {
      await _box.put(download.id, download);
      Logger.info('Download updated: ${download.id}');
      return download;
    } catch (e) {
      Logger.error('Error updating download: $e');
      throw CacheException('Failed to update download');
    }
  }

  /// Delete a download
  Future<void> deleteDownload(String id, {bool deleteFile = true}) async {
    try {
      final download = await getDownloadById(id);

      if (download != null) {
        // Delete local file if requested
        if (deleteFile) {
          final file = File(download.localPath);
          if (await file.exists()) {
            await file.delete();
            Logger.info('Deleted file: ${download.localPath}');
          }
        }

        // Delete from storage
        await _box.delete(id);
        Logger.info('Download deleted: $id');
      }
    } catch (e) {
      Logger.error('Error deleting download: $e');
      throw CacheException('Failed to delete download');
    }
  }

  /// Check if content is downloaded
  Future<bool> isContentDownloaded({
    required String mediaId,
    String? episodeId,
    String? chapterId,
  }) async {
    try {
      final downloads = _box.values.where((download) {
        if (download.mediaId != mediaId) return false;
        if (download.status != DownloadStatus.completed) return false;

        if (episodeId != null && download.episodeId != episodeId) return false;
        if (chapterId != null && download.chapterId != chapterId) return false;

        return true;
      });

      return downloads.isNotEmpty;
    } catch (e) {
      Logger.error('Error checking if content is downloaded: $e');
      throw CacheException('Failed to check download status');
    }
  }

  /// Get local file path for downloaded content
  Future<String?> getLocalFilePath({
    required String mediaId,
    String? episodeId,
    String? chapterId,
  }) async {
    try {
      final download = _box.values.firstWhere((download) {
        if (download.mediaId != mediaId) return false;
        if (download.status != DownloadStatus.completed) return false;

        if (episodeId != null && download.episodeId != episodeId) return false;
        if (chapterId != null && download.chapterId != chapterId) return false;

        return true;
      }, orElse: () => throw Exception('Download not found'));

      return download.localPath;
    } catch (e) {
      Logger.debug('No local file path found: $e');
      return null;
    }
  }

  /// Clear all downloads
  Future<void> clearAll() async {
    try {
      await _box.clear();
      Logger.info('All downloads cleared');
    } catch (e) {
      Logger.error('Error clearing downloads: $e');
      throw CacheException('Failed to clear downloads');
    }
  }

  /// Close the data source
  Future<void> close() async {
    try {
      await _box.close();
      Logger.info('Download data source closed');
    } catch (e) {
      Logger.error('Error closing download data source: $e');
    }
  }
}
