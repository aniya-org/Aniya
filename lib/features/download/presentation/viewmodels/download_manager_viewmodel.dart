import 'package:flutter/foundation.dart';
import '../../../../core/domain/entities/download_entity.dart';
import '../../../../core/domain/repositories/download_repository.dart';
import '../../../../core/utils/error_message_mapper.dart';
import '../../../../core/utils/logger.dart';

/// ViewModel for managing download state and operations
/// Based on Flutter Best Practices 2025 for state management
/// References: background_downloader package documentation
class DownloadManagerViewModel extends ChangeNotifier {
  final DownloadRepository _repository;

  DownloadManagerViewModel({required DownloadRepository repository})
      : _repository = repository;

  // State
  List<DownloadEntity> _allDownloads = [];
  List<DownloadEntity> _activeDownloads = [];
  List<DownloadEntity> _completedDownloads = [];
  List<DownloadEntity> _failedDownloads = [];
  bool _isLoading = false;
  String? _error;
  int _totalDownloads = 0;
  int _activeCount = 0;
  int _completedCount = 0;
  int _failedCount = 0;

  // Getters
  List<DownloadEntity> get allDownloads => _allDownloads;
  List<DownloadEntity> get activeDownloads => _activeDownloads;
  List<DownloadEntity> get completedDownloads => _completedDownloads;
  List<DownloadEntity> get failedDownloads => _failedDownloads;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get totalDownloads => _totalDownloads;
  int get activeCount => _activeCount;
  int get completedCount => _completedCount;
  int get failedCount => _failedCount;

  /// Get storage usage summary
  Map<String, int> get storageUsage {
    int totalSize = 0;
    int downloadedSize = 0;

    for (final download in _allDownloads) {
      totalSize += download.totalBytes;
      downloadedSize += download.downloadedBytes;
    }

    return {
      'totalBytes': totalSize,
      'downloadedBytes': downloadedSize,
      'remainingBytes': totalSize - downloadedSize,
    };
  }

  /// Load all downloads
  Future<void> loadDownloads() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      Logger.info('Loading all downloads', tag: 'DownloadManagerViewModel');

      final result = await _repository.getAllDownloads();
      result.fold((failure) {
        _error = ErrorMessageMapper.mapFailureToMessage(failure);
        Logger.error(
          'Failed to load downloads',
          tag: 'DownloadManagerViewModel',
          error: failure,
        );
      }, (downloads) {
        _allDownloads = downloads;
        _categorizeDownloads();
        Logger.debug('Loaded ${downloads.length} downloads', tag: 'DownloadManagerViewModel');
      });
    } catch (e, stackTrace) {
      _error = 'An unexpected error occurred';
      Logger.error(
        'Unexpected error loading downloads',
        tag: 'DownloadManagerViewModel',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh downloads
  Future<void> refresh() async {
    await loadDownloads();
  }

  /// Pause a download
  Future<void> pauseDownload(String id) async {
    try {
      Logger.info('Pausing download: $id', tag: 'DownloadManagerViewModel');

      final result = await _repository.pauseDownload(id);
      result.fold(
        (failure) => Logger.error(
          'Failed to pause download',
          tag: 'DownloadManagerViewModel',
          error: failure,
        ),
        (download) {
          // Update local state immediately
          _updateDownloadInList(download);
          Logger.debug('Download paused: $id', tag: 'DownloadManagerViewModel');
        },
      );
    } catch (e, stackTrace) {
      Logger.error(
        'Error pausing download',
        tag: 'DownloadManagerViewModel',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Resume a download
  Future<void> resumeDownload(String id) async {
    try {
      Logger.info('Resuming download: $id', tag: 'DownloadManagerViewModel');

      final result = await _repository.resumeDownload(id);
      result.fold(
        (failure) => Logger.error(
          'Failed to resume download',
          tag: 'DownloadManagerViewModel',
          error: failure,
        ),
        (download) {
          // Update local state immediately
          _updateDownloadInList(download);
          Logger.debug('Download resumed: $id', tag: 'DownloadManagerViewModel');
        },
      );
    } catch (e, stackTrace) {
      Logger.error(
        'Error resuming download',
        tag: 'DownloadManagerViewModel',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Cancel a download
  Future<void> cancelDownload(String id) async {
    try {
      Logger.info('Cancelling download: $id', tag: 'DownloadManagerViewModel');

      final result = await _repository.cancelDownload(id);
      result.fold(
        (failure) => Logger.error(
          'Failed to cancel download',
          tag: 'DownloadManagerViewModel',
          error: failure,
        ),
        (download) {
          // Update local state immediately
          _updateDownloadInList(download);
          Logger.debug('Download cancelled: $id', tag: 'DownloadManagerViewModel');
        },
      );
    } catch (e, stackTrace) {
      Logger.error(
        'Error cancelling download',
        tag: 'DownloadManagerViewModel',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Delete a download
  Future<void> deleteDownload(String id, {bool deleteFile = true}) async {
    try {
      Logger.info('Deleting download: $id (deleteFile: $deleteFile)', tag: 'DownloadManagerViewModel');

      final result = await _repository.deleteDownload(id, deleteFile: deleteFile);
      result.fold(
        (failure) => Logger.error(
          'Failed to delete download',
          tag: 'DownloadManagerViewModel',
          error: failure,
        ),
        (_) {
          // Remove from local list
          _allDownloads.removeWhere((d) => d.id == id);
          _categorizeDownloads();
          Logger.debug('Download deleted: $id', tag: 'DownloadManagerViewModel');
        },
      );
    } catch (e, stackTrace) {
      Logger.error(
        'Error deleting download',
        tag: 'DownloadManagerViewModel',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Retry failed downloads
  Future<void> retryFailedDownloads() async {
    final failedToRetry = List<DownloadEntity>.from(_failedDownloads);

    for (final download in failedToRetry) {
      try {
        Logger.info('Retrying failed download: ${download.id}', tag: 'DownloadManagerViewModel');

        // Reset status to queued
        final updatedResult = await _repository.updateDownloadStatus(
          download.id,
          DownloadStatus.queued,
        );

        updatedResult.fold(
          (failure) => Logger.error(
            'Failed to retry download',
            tag: 'DownloadManagerViewModel',
            error: failure,
          ),
          (updated) {
            _updateDownloadInList(updated);
            Logger.debug('Download queued for retry: ${download.id}', tag: 'DownloadManagerViewModel');
          },
        );
      } catch (e, stackTrace) {
        Logger.error(
          'Error retrying download',
          tag: 'DownloadManagerViewModel',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
  }

  /// Clear completed downloads
  Future<void> clearCompleted() async {
    final completedToDelete = List<DownloadEntity>.from(_completedDownloads);

    for (final download in completedToDelete) {
      await deleteDownload(download.id, deleteFile: false);
    }

    Logger.info('Cleared ${completedToDelete.length} completed downloads', tag: 'DownloadManagerViewModel');
  }

  /// Update download progress (called by background downloader updates)
  void updateProgress(String id, int downloadedBytes, int totalBytes) {
    final index = _allDownloads.indexWhere((d) => d.id == id);
    if (index != -1) {
      final progress = totalBytes > 0 ? downloadedBytes / totalBytes : 0.0;
      _allDownloads[index] = _allDownloads[index].copyWith(
        downloadedBytes: downloadedBytes,
        totalBytes: totalBytes,
        progress: progress,
      );
      _categorizeDownloads();
      notifyListeners();
    }
  }

  /// Update download status (called by background downloader updates)
  void updateStatus(String id, DownloadStatus status) {
    final index = _allDownloads.indexWhere((d) => d.id == id);
    if (index != -1) {
      _allDownloads[index] = _allDownloads[index].copyWith(
        status: status,
        completedAt: status == DownloadStatus.completed ? DateTime.now() : null,
      );
      _categorizeDownloads();
      notifyListeners();
    }
  }

  /// Add a new download
  void addDownload(DownloadEntity download) {
    _allDownloads.insert(0, download);
    _categorizeDownloads();
    notifyListeners();
    Logger.debug('Added new download: ${download.id}', tag: 'DownloadManagerViewModel');
  }

  /// Categorize downloads by status
  void _categorizeDownloads() {
    _activeDownloads = _allDownloads.where((d) =>
        d.status == DownloadStatus.queued ||
        d.status == DownloadStatus.downloading ||
        d.status == DownloadStatus.paused
    ).toList();

    _completedDownloads = _allDownloads.where((d) =>
        d.status == DownloadStatus.completed
    ).toList();

    _failedDownloads = _allDownloads.where((d) =>
        d.status == DownloadStatus.failed ||
        d.status == DownloadStatus.cancelled
    ).toList();

    _totalDownloads = _allDownloads.length;
    _activeCount = _activeDownloads.length;
    _completedCount = _completedDownloads.length;
    _failedCount = _failedDownloads.length;
  }

  /// Update a download in the list
  void _updateDownloadInList(DownloadEntity updated) {
    final index = _allDownloads.indexWhere((d) => d.id == updated.id);
    if (index != -1) {
      _allDownloads[index] = updated;
      _categorizeDownloads();
      notifyListeners();
    }
  }

  /// Get download by ID
  DownloadEntity? getDownloadById(String id) {
    try {
      return _allDownloads.firstWhere((d) => d.id == id);
    } catch (e) {
      return null;
    }
  }
}