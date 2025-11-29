import 'package:flutter/foundation.dart';
import '../../../../core/domain/entities/source_entity.dart';
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

  /// All available SourceEntity objects (from episode source selection)
  List<SourceEntity> _allSourceEntities = [];

  /// Currently selected SourceEntity
  SourceEntity? _selectedSourceEntity;

  List<VideoSource> get sources => _sources;
  VideoSource? get selectedSource => _selectedSource;
  List<SourceEntity> get allSourceEntities => _allSourceEntities;
  SourceEntity? get selectedSourceEntity => _selectedSourceEntity;
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

  /// Load a video directly from a SourceEntity (used when source is already selected)
  ///
  /// This bypasses the source fetching step and directly uses the sourceLink
  /// from the SourceEntity as the video URL.
  ///
  /// [source] - The selected source to play
  /// [allSources] - Optional list of all available sources for switching
  Future<void> loadSourceEntity(
    SourceEntity source, {
    List<SourceEntity>? allSources,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Store all source entities for switching
      _allSourceEntities = allSources ?? [source];
      _selectedSourceEntity = source;

      // Create a VideoSource from the SourceEntity for consistency
      final videoSource = VideoSource(
        id: source.id,
        name: source.name,
        url: source.sourceLink,
        quality: source.quality ?? 'Auto',
        server: source.name,
        headers: source.headers,
      );

      // Convert all source entities to VideoSource for the sources list
      _sources = _allSourceEntities
          .map(
            (s) => VideoSource(
              id: s.id,
              name: s.name,
              url: s.sourceLink,
              quality: s.quality ?? 'Auto',
              server: s.name,
              headers: s.headers,
            ),
          )
          .toList();
      _selectedSource = videoSource;

      // The sourceLink may be a direct URL or an embed URL that needs extraction
      // Try extraction first, fall back to direct URL if it fails
      final result = await extractVideoUrl(
        ExtractVideoUrlParams(source: videoSource),
      );

      result.fold(
        (failure) {
          // If extraction fails, try using the sourceLink directly
          Logger.warning(
            'URL extraction failed, using sourceLink directly: ${source.sourceLink}',
            tag: 'VideoPlayerViewModel',
          );
          _videoUrl = source.sourceLink;
        },
        (url) {
          _videoUrl = url;
          Logger.info(
            'Successfully extracted video URL',
            tag: 'VideoPlayerViewModel',
          );
        },
      );
    } catch (e, stackTrace) {
      _error = 'An unexpected error occurred. Please try again.';
      Logger.error(
        'Unexpected error loading source entity',
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
