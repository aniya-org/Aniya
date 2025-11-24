import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/domain/usecases/save_playback_position_usecase.dart';
import '../../../../core/domain/usecases/get_playback_position_usecase.dart';
import '../../../../core/domain/usecases/update_progress_usecase.dart';

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
  final String episodeId;
  final String sourceId;
  final String itemId;
  final int episodeNumber;
  final String episodeTitle;

  const VideoPlayerScreen({
    super.key,
    required this.episodeId,
    required this.sourceId,
    required this.itemId,
    required this.episodeNumber,
    required this.episodeTitle,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final Player _player;
  late final VideoController _videoController;
  SavePlaybackPositionUseCase? _savePlaybackPositionUseCase;
  GetPlaybackPositionUseCase? _getPlaybackPositionUseCase;
  UpdateProgressUseCase? _updateProgressUseCase;

  bool _isFullscreen = false;
  bool _showControls = true;
  bool _isInitialized = false;
  bool _isLoading = true;
  String? _error;
  Duration? _savedPosition;

  // Mock video sources for demonstration
  // TODO: Replace with actual video source fetching from ViewModel
  final List<_VideoSource> _sources = [
    _VideoSource(
      quality: '1080p',
      server: 'Server 1',
      url:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
    ),
    _VideoSource(
      quality: '720p',
      server: 'Server 2',
      url:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
    ),
    _VideoSource(
      quality: '480p',
      server: 'Server 3',
      url:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
    ),
  ];

  _VideoSource? _selectedSource;

  @override
  void initState() {
    super.initState();
    // Initialize use cases from dependency injection
    // Note: In production, these should be injected via constructor
    // For now, we'll use a fallback approach
    try {
      _savePlaybackPositionUseCase = sl<SavePlaybackPositionUseCase>();
      _getPlaybackPositionUseCase = sl<GetPlaybackPositionUseCase>();
      _updateProgressUseCase = sl<UpdateProgressUseCase>();
    } catch (e) {
      // Use cases not registered yet - will use mock implementation
      debugPrint('Use cases not registered: $e');
    }
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    _player = Player();
    _videoController = VideoController(_player);

    // Load saved playback position
    await _loadSavedPosition();

    // Set up position listener for auto-save
    // Save progress every 10 seconds during playback
    Duration? lastSavedPosition;
    _player.stream.position.listen((position) {
      // Auto-save progress every 10 seconds
      if (lastSavedPosition == null ||
          (position.inSeconds - lastSavedPosition!.inSeconds).abs() >= 10) {
        lastSavedPosition = position;
        _saveProgress(position);
      }
    });

    // Mark episode as complete when playback finishes
    _player.stream.completed.listen((completed) {
      if (completed) {
        _markEpisodeComplete();
      }
    });

    // Auto-select first source and play
    if (_sources.isNotEmpty) {
      await _selectSource(_sources.first);
    }

    setState(() {
      _isInitialized = true;
      _isLoading = false;
    });
  }

  Future<void> _loadSavedPosition() async {
    if (_getPlaybackPositionUseCase == null) {
      debugPrint('GetPlaybackPositionUseCase not available');
      return;
    }

    try {
      final result = await _getPlaybackPositionUseCase!(
        GetPlaybackPositionParams(
          itemId: widget.itemId,
          episodeId: widget.episodeId,
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
    }
  }

  Future<void> _selectSource(_VideoSource source) async {
    setState(() {
      _selectedSource = source;
      _isLoading = true;
      _error = null;
    });

    try {
      await _player.open(Media(source.url));

      // Seek to saved position if available
      if (_savedPosition != null && _savedPosition!.inSeconds > 0) {
        await _player.seek(_savedPosition!);
        debugPrint(
          'Resumed from saved position: ${_savedPosition!.inSeconds}s',
        );
      }

      await _player.play();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to play video: $e';
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to play video: $e')));
      }
    }
  }

  Future<void> _saveProgress(Duration position) async {
    if (_savePlaybackPositionUseCase == null) {
      return;
    }

    try {
      final result = await _savePlaybackPositionUseCase!(
        SavePlaybackPositionParams(
          itemId: widget.itemId,
          episodeId: widget.episodeId,
          position: position.inMilliseconds,
        ),
      );

      result.fold(
        (failure) {
          debugPrint('Failed to save progress: ${failure.message}');
        },
        (_) {
          debugPrint(
            'Progress saved: ${position.inSeconds}s for episode ${widget.episodeId}',
          );
        },
      );
    } catch (e) {
      debugPrint('Error saving progress: $e');
    }
  }

  Future<void> _markEpisodeComplete() async {
    if (_updateProgressUseCase == null) {
      return;
    }

    try {
      // Save final position
      await _saveProgress(_player.state.position);

      // Update episode progress
      final result = await _updateProgressUseCase!(
        UpdateProgressParams(
          itemId: widget.itemId,
          episode: widget.episodeNumber,
          chapter: 0,
        ),
      );

      result.fold(
        (failure) {
          debugPrint('Failed to mark episode complete: ${failure.message}');
        },
        (_) {
          debugPrint('Episode ${widget.episodeNumber} marked as complete');
        },
      );
    } catch (e) {
      debugPrint('Error marking episode complete: $e');
    }
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });

    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }

  @override
  void dispose() {
    // Save final position before disposing
    _saveProgress(_player.state.position);

    // Reset orientation
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading && !_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _selectedSource == null) {
      return _buildErrorView(_error!);
    }

    return Column(
      children: [
        if (!_isFullscreen) _buildHeader(),
        Expanded(child: _buildVideoPlayer()),
        if (!_isFullscreen) _buildSourceSelector(),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.episodeTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Episode ${widget.episodeNumber}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _showControls = !_showControls;
        });
      },
      child: Stack(
        children: [
          Video(controller: _videoController, controls: NoVideoControls),
          if (_showControls) _buildCustomControls(),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildCustomControls() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.7),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.7),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_isFullscreen)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      if (_isFullscreen) {
                        _toggleFullscreen();
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                  Expanded(
                    child: Text(
                      widget.episodeTitle,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          _buildPlaybackControls(),
          _buildBottomControls(),
        ],
      ),
    );
  }

  Widget _buildPlaybackControls() {
    return StreamBuilder<bool>(
      stream: _player.stream.playing,
      builder: (context, snapshot) {
        final isPlaying = snapshot.data ?? false;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.replay_10, color: Colors.white, size: 32),
              onPressed: () {
                final currentPosition = _player.state.position;
                _player.seek(currentPosition - const Duration(seconds: 10));
              },
            ),
            const SizedBox(width: 20),
            IconButton(
              icon: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 48,
              ),
              onPressed: () {
                if (isPlaying) {
                  _player.pause();
                } else {
                  _player.play();
                }
              },
            ),
            const SizedBox(width: 20),
            IconButton(
              icon: const Icon(Icons.forward_10, color: Colors.white, size: 32),
              onPressed: () {
                final currentPosition = _player.state.position;
                _player.seek(currentPosition + const Duration(seconds: 10));
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          StreamBuilder<Duration>(
            stream: _player.stream.position,
            builder: (context, positionSnapshot) {
              return StreamBuilder<Duration>(
                stream: _player.stream.duration,
                builder: (context, durationSnapshot) {
                  final position = positionSnapshot.data ?? Duration.zero;
                  final duration = durationSnapshot.data ?? Duration.zero;

                  return Column(
                    children: [
                      Slider(
                        value: duration.inMilliseconds > 0
                            ? position.inMilliseconds.toDouble()
                            : 0,
                        max: duration.inMilliseconds > 0
                            ? duration.inMilliseconds.toDouble()
                            : 1,
                        onChanged: (value) {
                          _player.seek(Duration(milliseconds: value.toInt()));
                        },
                        activeColor: Theme.of(context).colorScheme.primary,
                        inactiveColor: Colors.white30,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(position),
                              style: const TextStyle(color: Colors.white),
                            ),
                            Text(
                              _formatDuration(duration),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildVolumeControl(),
              IconButton(
                icon: Icon(
                  _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                  color: Colors.white,
                ),
                onPressed: _toggleFullscreen,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVolumeControl() {
    return StreamBuilder<double>(
      stream: _player.stream.volume,
      builder: (context, snapshot) {
        final volume = snapshot.data ?? 100.0;
        final isMuted = volume == 0.0;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                isMuted
                    ? Icons.volume_off
                    : volume < 50
                    ? Icons.volume_down
                    : Icons.volume_up,
                color: Colors.white,
              ),
              onPressed: () {
                if (isMuted) {
                  _player.setVolume(100.0);
                } else {
                  _player.setVolume(0.0);
                }
              },
            ),
            SizedBox(
              width: 100,
              child: Slider(
                value: volume,
                min: 0,
                max: 100,
                onChanged: (value) {
                  _player.setVolume(value);
                },
                activeColor: Theme.of(context).colorScheme.primary,
                inactiveColor: Colors.white30,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSourceSelector() {
    if (_sources.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Quality / Server',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _sources.length,
              itemBuilder: (context, index) {
                final source = _sources[index];
                final isSelected = _selectedSource == source;

                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text('${source.quality} - ${source.server}'),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected && !isSelected) {
                        _selectSource(source);
                      }
                    },
                    selectedColor: Theme.of(context).colorScheme.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
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
                  _selectSource(_sources[nextIndex]);
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

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }
}

/// Temporary video source model for demonstration
/// TODO: Replace with actual VideoSource entity from domain layer
class _VideoSource {
  final String quality;
  final String server;
  final String url;

  _VideoSource({
    required this.quality,
    required this.server,
    required this.url,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _VideoSource &&
          runtimeType == other.runtimeType &&
          quality == other.quality &&
          server == other.server &&
          url == other.url;

  @override
  int get hashCode => quality.hashCode ^ server.hashCode ^ url.hashCode;
}
