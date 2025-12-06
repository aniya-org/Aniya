import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Utility class for storage-related operations
/// Provides methods to format file sizes and manage file operations
class StorageUtils {
  /// Format bytes into human readable format
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Get available storage space
  static Future<int?> getAvailableSpace(String path) async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        // For mobile platforms, we need to use platform-specific code
        // This would require method channels or plugins
        return null;
      } else {
        final directory = Directory(path);
        if (await directory.exists()) {
          final stat = await directory.stat();
          return stat.size;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting available space: $e');
      }
    }
    return null;
  }

  /// Open file with appropriate application
  static Future<bool> openFile(String filePath) async {
    try {
      final uri = Uri.file(filePath);

      // Check if file exists
      final file = File(filePath);
      if (!await file.exists()) {
        return false;
      }

      // Use url_launcher to open the file
      if (await canLaunchUrl(uri)) {
        return await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Error opening file: $e');
      }
      return false;
    }
  }

  /// Share file
  static Future<bool> shareFile(String filePath, {String? text}) async {
    try {
      // This would require the share_plus package
      // For now, we'll just log the request
      if (kDebugMode) {
        print('Share file requested: $filePath');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Error sharing file: $e');
      }
      return false;
    }
  }

  /// Get file extension
  static String getFileExtension(String filePath) {
    return filePath.split('.').last.toLowerCase();
  }

  /// Check if file is video
  static bool isVideoFile(String filePath) {
    final videoExtensions = [
      'mp4', 'avi', 'mkv', 'mov', 'wmv', 'flv', 'webm', 'm4v', '3gp'
    ];
    final extension = getFileExtension(filePath);
    return videoExtensions.contains(extension);
  }

  /// Check if file is image
  static bool isImageFile(String filePath) {
    final imageExtensions = [
      'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg'
    ];
    final extension = getFileExtension(filePath);
    return imageExtensions.contains(extension);
  }

  /// Check if file is audio
  static bool isAudioFile(String filePath) {
    final audioExtensions = [
      'mp3', 'wav', 'aac', 'flac', 'm4a', 'ogg', 'wma'
    ];
    final extension = getFileExtension(filePath);
    return audioExtensions.contains(extension);
  }

  /// Check if file is document
  static bool isDocumentFile(String filePath) {
    final documentExtensions = [
      'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt'
    ];
    final extension = getFileExtension(filePath);
    return documentExtensions.contains(extension);
  }

  /// Get file type display name
  static String getFileType(String filePath) {
    if (isVideoFile(filePath)) return 'Video';
    if (isImageFile(filePath)) return 'Image';
    if (isAudioFile(filePath)) return 'Audio';
    if (isDocumentFile(filePath)) return 'Document';
    return 'File';
  }

  /// Calculate download speed
  static String calculateSpeed(int bytes, Duration duration) {
    if (duration.inMilliseconds == 0) return '0 B/s';

    final bytesPerSecond = (bytes * 1000) / duration.inMilliseconds;
    return '${formatBytes(bytesPerSecond.round())}/s';
  }

  /// Calculate estimated time remaining
  static String calculateETA(int remainingBytes, int bytesPerSecond) {
    if (bytesPerSecond <= 0) return '--:--';

    final seconds = remainingBytes / bytesPerSecond;

    if (seconds < 60) {
      return '${seconds.toInt()}s';
    } else if (seconds < 3600) {
      final minutes = (seconds / 60).floor();
      final remainingSeconds = (seconds % 60).round();
      return '${minutes}m ${remainingSeconds}s';
    } else {
      final hours = (seconds / 3600).floor();
      final remainingMinutes = ((seconds % 3600) / 60).floor();
      return '${hours}h ${remainingMinutes}m';
    }
  }

  /// Clean up old downloads
  static Future<void> cleanupOldDownloads(String directoryPath, {int daysOld = 30}) async {
    try {
      final directory = Directory(directoryPath);
      if (!await directory.exists()) return;

      final now = DateTime.now();
      final cutoffDate = now.subtract(Duration(days: daysOld));

      await for (final entity in directory.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoffDate)) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error cleaning up old downloads: $e');
      }
    }
  }
}