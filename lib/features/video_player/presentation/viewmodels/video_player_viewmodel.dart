import 'package:flutter/foundation.dart';
import '../../../../core/domain/entities/video_source_entity.dart';
import '../../../../core/domain/usecases/get_video_sources_usecase.dart';
import '../../../../core/domain/usecases/extract_video_url_usecase.dart';
import '../../../../core/domain/usecases/save_playback_position_usecase.dart';
import '../../../../core/domain/usecases/get_playback_position_usecase.dart';
import '../../../../core/domain/usecases/update_progress_usecase.dart';
import '../../../../core/utils/error_message_mapper.dart';
import '../../../../core/utils/logger.dart';

class VideoPlayerViewModel extends ChangeNotifier {
  final GetVideoSourcesUseCase getVideoSources;
  final ExtractVideoUrlUseCase extractVideoUrl;
  final SavePlaybackPositionUseCase savePlaybackPosition;
  final GetPlaybackPositionUseCase getPlaybackPosition;
  final UpdateProgressUseCase updateProgress;

  VideoPlayerViewModel({
    required this.getVideoSources,
    required this.extractVideoUrl,
    required this.savePlaybackPosition,
    required this.getPlaybackPosition,
    required this.updateProgress,
  });

  List<VideoSource> _sources = [];
  VideoSource? _selectedSource;
  String? _videoUrl;
  Duration _currentPosition = Duration.zero;
  bool _isLoading = false;
  String? _error;

  List<VideoSource> get sources => _sources;
  VideoSource? get selectedSource => _selectedSource;
  String? get videoUrl => _videoUrl;
  Duration get currentPosition => _currentPosition;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadSources(String episodeId, String sourceId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await getVideoSources(
        GetVideoSourcesParams(episodeId: episodeId, sourceId: sourceId),
      );

      result.fold(
        (failure) {
          _error = ErrorMessageMapper.mapFailureToMessage(failure);
          Logger.error(
            'Failed to load video sources',
            tag: 'VideoPlayerViewModel',
            error: failure,
          );
        },
        (sourceList) {
          _sources = sourceList;
          // Auto-select first source if available
          if (sourceList.isNotEmpty) {
            selectSource(sourceList.first);
          }
        },
      );
    } catch (e, stackTrace) {
      _error = 'An unexpected error occurred. Please try again.';
      Logger.error(
        'Unexpected error loading video sources',
        tag: 'VideoPlayerViewModel',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectSource(VideoSource source) async {
    _selectedSource = source;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await extractVideoUrl(
        ExtractVideoUrlParams(source: source),
      );

      result.fold((failure) {
        _error = ErrorMessageMapper.mapFailureToMessage(failure);
        Logger.error(
          'Failed to extract video URL',
          tag: 'VideoPlayerViewModel',
          error: failure,
        );
        // If extraction fails and there are other sources, suggest trying them
        if (_sources.length > 1) {
          _error = '$_error\n\nTry selecting a different server.';
        }
      }, (url) => _videoUrl = url);
    } catch (e, stackTrace) {
      _error = 'An unexpected error occurred. Please try again.';
      Logger.error(
        'Unexpected error extracting video URL',
        tag: 'VideoPlayerViewModel',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateCurrentPosition(Duration position) {
    _currentPosition = position;
    // Don't notify listeners for every position update to avoid performance issues
  }

  Future<void> saveProgress(
    String itemId,
    String episodeId,
    Duration position,
  ) async {
    try {
      // Save playback position
      final positionResult = await savePlaybackPosition(
        SavePlaybackPositionParams(
          itemId: itemId,
          episodeId: episodeId,
          position: position.inMilliseconds,
        ),
      );

      positionResult.fold(
        (failure) {
          Logger.error(
            'Failed to save playback position',
            tag: 'VideoPlayerViewModel',
            error: failure,
          );
        },
        (_) {
          // Position saved successfully
        },
      );
    } catch (e, stackTrace) {
      Logger.error(
        'Unexpected error saving progress',
        tag: 'VideoPlayerViewModel',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> markEpisodeComplete(String itemId, int episodeNumber) async {
    try {
      final result = await updateProgress(
        UpdateProgressParams(
          itemId: itemId,
          episode: episodeNumber,
          chapter: 0,
        ),
      );

      result.fold(
        (failure) {
          Logger.error(
            'Failed to update progress',
            tag: 'VideoPlayerViewModel',
            error: failure,
          );
        },
        (_) {
          // Progress updated successfully
        },
      );
    } catch (e, stackTrace) {
      Logger.error(
        'Unexpected error updating progress',
        tag: 'VideoPlayerViewModel',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<Duration?> loadSavedPosition(String itemId, String episodeId) async {
    try {
      final result = await getPlaybackPosition(
        GetPlaybackPositionParams(itemId: itemId, episodeId: episodeId),
      );

      return result.fold(
        (failure) {
          // No saved position or error - return null
          Logger.info('No saved position found', tag: 'VideoPlayerViewModel');
          return null;
        },
        (positionMs) {
          // Return saved position as Duration
          return Duration(milliseconds: positionMs);
        },
      );
    } catch (e, stackTrace) {
      // Error loading position - return null
      Logger.error(
        'Error loading saved position',
        tag: 'VideoPlayerViewModel',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}
