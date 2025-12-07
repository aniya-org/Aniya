import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/domain/entities/media_entity.dart';
import '../../../../core/domain/entities/episode_entity.dart';
import '../../../../core/domain/entities/source_entity.dart';
import '../../../../core/domain/entities/video_source_entity.dart';
import '../../../../core/domain/usecases/get_video_sources_usecase.dart';
import '../../../../core/domain/usecases/extract_video_url_usecase.dart';
import '../../../../core/domain/usecases/save_playback_position_usecase.dart';
import '../../../../core/domain/usecases/get_playback_position_usecase.dart';
import '../../../../core/domain/usecases/update_progress_usecase.dart';
import '../../../../core/services/watch_history_controller.dart';
import '../../../../core/domain/entities/watch_history_entry.dart';
import '../../../../core/services/hardware_acceleration_configurator.dart';
import '../viewmodels/video_player_viewmodel.dart';

/// Video player screen for playing episodes
///
/// This screen integrates media_kit for video playback and provides:
/// - Custom video controls (play/pause, seek, volume)
/// - Quality and server selection
/// - Fullscreen support
/// - Playback progress saving with auto-save every 10 seconds
/// - Resume from saved position
/// - Error handling with fallback sources
class VideoPlayerScreen extends StatefulWidget {
  final String? episodeId;
  final String? sourceId;
  final String? itemId;
  final int? episodeNumber;
  final String? episodeTitle;

  /// Whether to resume from saved position
  final bool resumeFromSavedPosition;

  final MediaEntity? media;
  final EpisodeEntity? episode;
  final SourceEntity? source;
  final List<SourceEntity>? allSources;

  /// Legacy constructor used by screens that only know the media/source IDs.
  const VideoPlayerScreen({
    super.key,
    this.resumeFromSavedPosition = true,
    required this.episodeId,
    required this.sourceId,
    required this.itemId,
    required this.episodeNumber,
    required this.episodeTitle,
  }) : media = null,
       episode = null,
       source = null,
       allSources = null;

  /// Constructor used when a concrete SourceEntity has already been selected.
  const VideoPlayerScreen.fromSourceSelection({
    this.resumeFromSavedPosition = true,
    super.key,
    required MediaEntity media,
    required EpisodeEntity episode,
    required SourceEntity source,
    List<SourceEntity>? allSources,
  }) : media = media,
       episode = episode,
       source = source,
       allSources = allSources,
       episodeId = null,
       sourceId = null,
       itemId = null,
       episodeNumber = null,
       episodeTitle = null;

  bool get isDirectSourceMode => source != null;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final Player _player;
  late final VideoController _videoController;
  late final VideoPlayerViewModel _viewModel;
  late final SavePlaybackPositionUseCase _savePlaybackPositionUseCase;
  late final GetPlaybackPositionUseCase _getPlaybackPositionUseCase;
  late final UpdateProgressUseCase _updateProgressUseCase;
  WatchHistoryController? _watchHistoryController;

  bool _isInitialized = false;
  bool _isLoadingPlayer = true;
  bool _isLoadingSources = true;
  bool _showControls = true;
  bool _isDisposed = false;
  bool _isSeeking = false;
  bool _isPlaying = false;
  bool _isBuffering = false;
  Duration _currentPosition = Duration.zero;
  Duration _currentDuration = Duration.zero;
  double _seekValue = 0.0;
  Duration? _savedPosition;
  Duration? _pendingResumePosition;
  Timer? _hideControlsTimer;
  final List<StreamSubscription> _subscriptions = [];

  List<VideoSource> get _sources => _viewModel.sources;
  VideoSource? get _selectedSource => _viewModel.selectedSource;
  String? get _viewModelError => _viewModel.error;

  String get _resolvedEpisodeId =>
      widget.isDirectSourceMode ? widget.episode!.id : widget.episodeId!;

  String get _resolvedItemId =>
      widget.isDirectSourceMode ? widget.media!.id : widget.itemId!;

  int get _resolvedEpisodeNumber => widget.isDirectSourceMode
      ? widget.episode!.number
      : widget.episodeNumber!;

  String get _resolvedEpisodeTitle =>
      widget.isDirectSourceMode ? widget.episode!.title : widget.episodeTitle!;

  String? get _resolvedSourceProviderId {
    if (widget.isDirectSourceMode) {
      return widget.source?.id ??
          widget.source?.providerId ??
          widget.episode?.sourceProvider ??
          widget.sourceId;
    }
    return widget.sourceId;
  }

  MediaType get _resolvedMediaType {
    if (widget.isDirectSourceMode && widget.media != null) {
      return widget.media!.type;
    }
    return widget.media?.type ?? MediaType.anime;
  }

  @override
  void initState() {
    super.initState();
    _savePlaybackPositionUseCase = sl<SavePlaybackPositionUseCase>();
    _getPlaybackPositionUseCase = sl<GetPlaybackPositionUseCase>();
    _updateProgressUseCase = sl<UpdateProgressUseCase>();

    // Initialize WatchHistoryController if available
    if (sl.isRegistered<WatchHistoryController>()) {
      _watchHistoryController = sl<WatchHistoryController>();
    }

    _viewModel = VideoPlayerViewModel(
      getVideoSources: sl<GetVideoSourcesUseCase>(),
      extractVideoUrl: sl<ExtractVideoUrlUseCase>(),
      savePlaybackPosition: _savePlaybackPositionUseCase,
      getPlaybackPosition: _getPlaybackPositionUseCase,
      updateProgress: _updateProgressUseCase,
    )..addListener(_onViewModelChanged);

    // Set landscape orientation, allow rotation between landscape modes
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    _player = Player();
    final videoControllerConfig =
        await HardwareAccelerationConfigurator.getVideoControllerConfig();
    _videoController = VideoController(
      _player,
      configuration: videoControllerConfig,
    );
    // Load saved playback position if requested
    if (widget.resumeFromSavedPosition) {
      await _loadSavedPosition();
      await _maybePromptResumePlayback();
    }

    // Set up position listener for auto-save
    // Save progress every 10 seconds during playback
    Duration? lastSavedPosition;
    _subscriptions.add(
      _player.stream.position.listen((position) {
        if (_isDisposed) return;
        // Auto-save progress every 10 seconds
        if (lastSavedPosition == null ||
            (position.inSeconds - lastSavedPosition!.inSeconds).abs() >= 10) {
          lastSavedPosition = position;
          _saveProgress(position);
        }
      }),
    );

    // Mark episode as complete when playback finishes
    _subscriptions.add(
      _player.stream.completed.listen((completed) {
        if (_isDisposed) return;
        if (completed) {
          _markEpisodeComplete();
        }
      }),
    );

    // Track position for seek bar
    _subscriptions.add(
      _player.stream.position.listen((position) {
        if (_isDisposed || !mounted || _isSeeking) return;
        setState(() {
          _currentPosition = position;
        });
      }),
    );

    // Track duration for seek bar
    _subscriptions.add(
      _player.stream.duration.listen((duration) {
        if (_isDisposed || !mounted) return;
        setState(() {
          _currentDuration = duration;
        });
      }),
    );

    // Track playing state
    _subscriptions.add(
      _player.stream.playing.listen((playing) {
        if (_isDisposed || !mounted) return;
        setState(() {
          _isPlaying = playing;
        });
      }),
    );

    // Track buffering state
    _subscriptions.add(
      _player.stream.buffering.listen((buffering) {
        if (_isDisposed || !mounted) return;
        setState(() {
          _isBuffering = buffering;
        });
      }),
    );

    if (!mounted) return;
    setState(() {
      _isInitialized = true;
      _isLoadingPlayer = false;
    });

    // Trigger source loading via view model
    if (widget.isDirectSourceMode) {
      await _viewModel.loadSourceEntity(
        widget.source!,
        allSources: widget.allSources,
      );
    } else {
      await _viewModel.loadSources(widget.episodeId!, widget.sourceId!);
    }
  }

  Future<void> _applyPendingResumeSeek() async {
    final target = _pendingResumePosition;
    if (target == null || target.inMilliseconds <= 0) return;
    try {
      debugPrint(
        'Applying queued resume seek to ${target.inSeconds}s before play',
      );
      debugPrint(
        'Current player state before seek: isPlaying=${_player.state.playing}, position=${_player.state.position}',
      );
      await _player.seek(target);
      debugPrint(
        'Player state after seek: isPlaying=${_player.state.playing}, position=${_player.state.position}',
      );
    } catch (e) {
      debugPrint('Failed to apply queued resume seek: $e');
      rethrow;
    } finally {
      _pendingResumePosition = null;
      _savedPosition = null;
    }
  }

  Future<void> _loadSavedPosition() async {
    try {
      final result = await _getPlaybackPositionUseCase(
        GetPlaybackPositionParams(
          itemId: _resolvedItemId,
          episodeId: _resolvedEpisodeId,
        ),
      );

      result.fold(
        (failure) {
          // No saved position or error - start from beginning
          debugPrint('No saved position found: ${failure.message}');
          _savedPosition = null;
        },
        (positionMs) {
          // Found saved position
          if (positionMs > 0) {
            _savedPosition = Duration(milliseconds: positionMs);
            debugPrint('Loaded saved position: ${_savedPosition!.inSeconds}s');
          }
        },
      );
    } catch (e) {
      // Error loading position - start from beginning
      debugPrint('Error loading saved position: $e');
      _savedPosition = null;
      _pendingResumePosition = null;
    }

    if (_savedPosition == null) {
      final fallback = await _loadSavedPositionFromHistory();
      if (fallback != null) {
        _savedPosition = fallback;
        debugPrint(
          'Loaded saved position from watch history: ${fallback.inSeconds}s',
        );
      }
    }
  }

  Future<Duration?> _loadSavedPositionFromHistory() async {
    if (_watchHistoryController == null) return null;
    final sourceProviderId = _resolvedSourceProviderId;
    if (sourceProviderId == null || sourceProviderId.isEmpty) return null;

    try {
      // First try to get exact match with current source provider
      final entry = await _watchHistoryController!.getEntryForMedia(
        _resolvedItemId,
        sourceProviderId,
        _resolvedMediaType,
      );

      final positionMs = entry?.playbackPositionMs;
      if (positionMs != null && positionMs > 0) {
        debugPrint('Found saved position from watch history: ${positionMs}ms');
        return Duration(milliseconds: positionMs);
      }

      // If no exact match, try to find any entry for this media
      // This handles cases where source provider ID has changed
      // or when resuming from history with a different source
      debugPrint(
        'No exact match found, trying to find any entry for media $_resolvedItemId',
      );

      // Get all entries for this media type and look for our media ID
      final allEntries = _watchHistoryController!.getEntriesForType(
        _resolvedMediaType,
      );
      WatchHistoryEntry? matchingEntry;
      try {
        matchingEntry = allEntries.firstWhere(
          (e) => e.mediaId == _resolvedItemId,
        );
      } catch (e) {
        // No matching entry found
        matchingEntry = null;
      }

      final fallbackPositionMs = matchingEntry?.playbackPositionMs;
      if (fallbackPositionMs != null && fallbackPositionMs > 0) {
        debugPrint(
          'Found fallback position from watch history: ${fallbackPositionMs}ms',
        );
        return Duration(milliseconds: fallbackPositionMs);
      }
    } catch (e) {
      debugPrint('Error loading watch history position: $e');
    }
    return null;
  }

  Future<void> _maybePromptResumePlayback() async {
    if (!mounted) return;
    if (_savedPosition == null) return;
    if (_savedPosition!.inSeconds <= 0) return;

    final shouldResume = await _showResumePlaybackDialog();
    if (!mounted) return;
    setState(() {
      if (!shouldResume) {
        _savedPosition = null;
        _pendingResumePosition = null;
      } else {
        _pendingResumePosition = _savedPosition;
        debugPrint(
          'Resume dialog accepted – queued seek to ${_pendingResumePosition!.inSeconds}s',
        );
      }
    });
  }

  Future<bool> _showResumePlaybackDialog() async {
    final positionLabel = _formatDuration(_savedPosition!);
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Resume playback?'),
            content: Text('Continue from $positionLabel or start over?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Start Over'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Resume'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _saveProgress(Duration position) async {
    try {
      // Try to save to library repository
      final result = await _savePlaybackPositionUseCase(
        SavePlaybackPositionParams(
          itemId: _resolvedItemId,
          episodeId: _resolvedEpisodeId,
          position: position.inMilliseconds,
        ),
      );

      result.fold(
        (failure) {
          debugPrint('Failed to save progress to library: ${failure.message}');
        },
        (_) {
          debugPrint(
            'Progress saved to library: ${position.inSeconds}s for episode $_resolvedEpisodeId',
          );
        },
      );

      // Always update watch history if available (this works regardless of library status)
      await _updateWatchHistory(position);
    } catch (e) {
      debugPrint('Error saving progress: $e');
    }
  }

  /// Update watch history with current playback progress
  Future<void> _updateWatchHistory(Duration position) async {
    if (_watchHistoryController == null) return;
    if (!widget.isDirectSourceMode) return; // Need full media info

    final media = widget.media!;
    final episode = widget.episode!;
    final source = widget.source!;

    // Extract release year from start date if available
    int? releaseYear;
    if (media.startDate != null) {
      releaseYear = media.startDate!.year;
    }

    await _watchHistoryController!.updateVideoProgress(
      mediaId: media.id,
      mediaType: media.type,
      title: media.title,
      coverImage: media.coverImage,
      sourceId: source.id,
      sourceName: source.name,
      playbackPositionMs: position.inMilliseconds,
      totalDurationMs: _currentDuration.inMilliseconds > 0
          ? _currentDuration.inMilliseconds
          : null,
      episodeNumber: episode.number,
      episodeId: episode.id,
      episodeTitle: episode.title,
      normalizedId: null, // MediaEntity doesn't have normalizedId yet
      releaseYear: releaseYear,
    );
  }

  Future<void> _markEpisodeComplete() async {
    try {
      // Save final position
      await _saveProgress(_player.state.position);

      // Update episode progress
      final result = await _updateProgressUseCase(
        UpdateProgressParams(
          itemId: _resolvedItemId,
          episode: _resolvedEpisodeNumber,
          chapter: 0,
        ),
      );

      result.fold(
        (failure) {
          debugPrint('Failed to mark episode complete: ${failure.message}');
        },
        (_) {
          debugPrint('Episode $_resolvedEpisodeNumber marked as complete');
        },
      );
    } catch (e) {
      debugPrint('Error marking episode complete: $e');
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _hideControlsTimer?.cancel();

    // Cancel all stream subscriptions first
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();

    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();

    // Reset orientation and system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Stop playback before disposing
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    _resetHideControlsTimer();
  }

  void _resetHideControlsTimer() {
    _hideControlsTimer?.cancel();
    if (_showControls) {
      _hideControlsTimer = Timer(const Duration(seconds: 4), () {
        if (mounted && _player.state.playing) {
          setState(() {
            _showControls = false;
          });
        }
      });
    }
  }

  void _showSourceSelectionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _buildSourceSelectionSheet(),
    );
  }

  Widget _buildSourceSelectionSheet() {
    final allSourceEntities = _viewModel.allSourceEntities;
    final selectedSourceEntity = _viewModel.selectedSourceEntity;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sources (${allSourceEntities.length})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (allSourceEntities.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'No sources available',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: allSourceEntities.length,
                  itemBuilder: (context, index) {
                    final source = allSourceEntities[index];
                    final isSelected = selectedSourceEntity?.id == source.id;
                    return ListTile(
                      leading: Icon(
                        isSelected ? Icons.check_circle : Icons.circle_outlined,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.white54,
                      ),
                      title: Text(
                        source.name,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        _buildSourceSubtitle(source),
                        style: TextStyle(
                          color: isSelected ? Colors.white60 : Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                      onTap: () {
                        if (!isSelected) {
                          _switchToSource(source);
                        }
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _buildSourceSubtitle(SourceEntity source) {
    final parts = <String>[];
    if (source.quality != null && source.quality!.isNotEmpty) {
      parts.add(source.quality!);
    }
    if (source.language != null && source.language!.isNotEmpty) {
      parts.add(source.language!);
    }
    return parts.isEmpty ? 'Unknown quality' : parts.join(' • ');
  }

  Future<void> _switchToSource(SourceEntity source) async {
    // Save current position before switching
    if (_currentPosition.inSeconds > 0) {
      await _saveProgress(_currentPosition);
    }

    // Stop current playback
    await _player.stop();

    // Load the new source
    await _viewModel.loadSourceEntity(
      source,
      allSources: _viewModel.allSourceEntities,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.black, body: _buildBody());
  }

  Widget _buildBody() {
    if ((_isLoadingPlayer || _isLoadingSources) && !_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_viewModelError != null && _selectedSource == null) {
      return _buildErrorView(_viewModelError!);
    }

    return _buildVideoPlayer();
  }

  Widget _buildVideoPlayer() {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return GestureDetector(
      onTap: _toggleControls,
      child: Stack(
        children: [
          Video(controller: _videoController, controls: NoVideoControls),
          if (_showControls) _buildControlsOverlay(),
          if (_isLoadingPlayer || _isLoadingSources)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.7),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: 0.7),
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top bar with back button, title, and settings
          _buildTopBar(),
          // Center play/pause
          Expanded(child: _buildCenterControls()),
          // Bottom bar with seek and controls
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _resolvedEpisodeTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Episode $_resolvedEpisodeNumber',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          // Settings button for source selection
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: _showSourceSelectionSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildCenterControls() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Rewind 10s
          IconButton(
            iconSize: 40,
            icon: const Icon(Icons.replay_10, color: Colors.white),
            onPressed: () {
              _player.seek(_currentPosition - const Duration(seconds: 10));
            },
          ),
          const SizedBox(width: 32),
          // Play/Pause
          if (_isBuffering)
            const SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(color: Colors.white),
            )
          else
            IconButton(
              iconSize: 64,
              icon: Icon(
                _isPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled,
                color: Colors.white,
              ),
              onPressed: () => _player.playOrPause(),
            ),
          const SizedBox(width: 32),
          // Forward 10s
          IconButton(
            iconSize: 40,
            icon: const Icon(Icons.forward_10, color: Colors.white),
            onPressed: () {
              _player.seek(_currentPosition + const Duration(seconds: 10));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Seek bar
          _buildSeekBar(),
          const SizedBox(height: 4),
          // Position indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(children: [_buildPositionIndicator(), const Spacer()]),
          ),
        ],
      ),
    );
  }

  Widget _buildSeekBar() {
    final progress = _currentDuration.inMilliseconds > 0
        ? _currentPosition.inMilliseconds / _currentDuration.inMilliseconds
        : 0.0;

    final displayValue = _isSeeking ? _seekValue : progress.clamp(0.0, 1.0);

    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
        activeTrackColor: Theme.of(context).colorScheme.primary,
        inactiveTrackColor: Colors.white30,
        thumbColor: Theme.of(context).colorScheme.primary,
      ),
      child: Slider(
        value: displayValue,
        onChangeStart: (value) {
          setState(() {
            _isSeeking = true;
            _seekValue = value;
          });
        },
        onChanged: (value) {
          setState(() {
            _seekValue = value;
          });
        },
        onChangeEnd: (value) {
          final newPosition = Duration(
            milliseconds: (value * _currentDuration.inMilliseconds).round(),
          );
          _player.seek(newPosition);
          setState(() {
            _isSeeking = false;
          });
        },
      ),
    );
  }

  Widget _buildPositionIndicator() {
    return Text(
      '${_formatDuration(_currentPosition)} / ${_formatDuration(_currentDuration)}',
      style: const TextStyle(color: Colors.white, fontSize: 12),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(
              'Playback Error',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_sources.length > 1 && _selectedSource != null)
              ElevatedButton.icon(
                onPressed: () {
                  // Try next source
                  final currentIndex = _sources.indexOf(_selectedSource!);
                  final nextIndex = (currentIndex + 1) % _sources.length;
                  _viewModel.selectSource(_sources[nextIndex]);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Try Alternative Source'),
              )
            else
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
              ),
          ],
        ),
      ),
    );
  }

  void _onViewModelChanged() {
    if (_isDisposed || !mounted) return;

    final hasVideoUrl = _viewModel.videoUrl != null;
    final isLoading = _viewModel.isLoading;

    setState(() {
      _isLoadingSources = isLoading;
    });

    if (hasVideoUrl) {
      _playCurrentUrl();
    }
  }

  Future<void> _playCurrentUrl() async {
    if (_isDisposed) return;

    final url = _viewModel.videoUrl;
    if (url == null) return;

    try {
      debugPrint('Opening video URL: $url');
      // Use merged headers from view model (includes extracted headers from extractor)
      final playbackHeaders = _viewModel.getPlaybackHeaders();
      await _player.open(Media(url, httpHeaders: playbackHeaders), play: false);

      if (_isDisposed) return;

      debugPrint(
        'Video opened, player state: isPlaying=${_player.state.playing}, position=${_player.state.position}',
      );

      // Wait a moment for the media to be properly loaded before seeking
      await Future.delayed(const Duration(milliseconds: 500));

      if (_isDisposed) return;

      await _applyPendingResumeSeek();
      if (_isDisposed) return;

      debugPrint(
        'Final player state before play: isPlaying=${_player.state.playing}, position=${_player.state.position}',
      );

      if (_isDisposed) return;
      await _player.play();

      debugPrint('Video started playing');
    } catch (e) {
      if (mounted && !_isDisposed) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to play video: $e')));
      }
    }
  }
}
