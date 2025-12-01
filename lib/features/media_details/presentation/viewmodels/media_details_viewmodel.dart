import 'package:flutter/foundation.dart';
import '../../../../core/domain/entities/media_entity.dart';
import '../../../../core/domain/entities/episode_entity.dart';
import '../../../../core/domain/entities/chapter_entity.dart';
import '../../../../core/domain/entities/library_item_entity.dart';
import '../../../../core/domain/entities/media_details_entity.dart';
import '../../../../core/domain/entities/watch_history_entry.dart';
import '../../../../core/enums/tracking_service.dart';
import '../../../../core/domain/usecases/get_media_details_usecase.dart';
import '../../../../core/domain/usecases/get_episodes_usecase.dart';
import '../../../../core/domain/usecases/get_chapters_usecase.dart';
import '../../../../core/domain/usecases/add_to_library_usecase.dart';
import '../../../../core/domain/repositories/media_repository.dart';
import '../../../../core/domain/repositories/library_repository.dart';
import '../../../../core/domain/repositories/watch_history_repository.dart';
import '../../../../core/utils/error_message_mapper.dart';
import '../../../../core/utils/logger.dart';

class MediaDetailsViewModel extends ChangeNotifier {
  final GetMediaDetailsUseCase getMediaDetails;
  final GetEpisodesUseCase getEpisodes;
  final GetChaptersUseCase getChapters;
  final AddToLibraryUseCase addToLibrary;
  final MediaRepository mediaRepository;
  final LibraryRepository? libraryRepository;
  final WatchHistoryRepository? watchHistoryRepository;

  MediaDetailsViewModel({
    required this.getMediaDetails,
    required this.getEpisodes,
    required this.getChapters,
    required this.addToLibrary,
    required this.mediaRepository,
    this.libraryRepository,
    this.watchHistoryRepository,
  });

  MediaEntity? _media;
  MediaDetailsEntity? _detailedMedia;
  List<EpisodeEntity> _episodes = [];
  List<ChapterEntity> _chapters = [];
  bool _isLoading = false;
  bool _isInLibrary = false;
  LibraryItemEntity? _libraryItem;
  WatchHistoryEntry? _watchHistoryEntry;
  String? _error;
  String? _sourceId;
  Map<int, WatchHistoryEntry?> _episodeProgress = {};
  Map<int, WatchHistoryEntry?> _chapterProgress = {};

  MediaEntity? get media => _media;
  MediaDetailsEntity? get detailedMedia => _detailedMedia;
  List<EpisodeEntity> get episodes => _episodes;
  List<ChapterEntity> get chapters => _chapters;
  bool get isLoading => _isLoading;
  bool get isInLibrary => _isInLibrary;
  LibraryItemEntity? get libraryItem => _libraryItem;
  WatchHistoryEntry? get watchHistoryEntry => _watchHistoryEntry;
  String? get error => _error;

  /// Get progress for a specific episode number
  WatchHistoryEntry? getEpisodeProgress(int episodeNumber) =>
      _episodeProgress[episodeNumber];

  /// Get progress for a specific chapter number
  WatchHistoryEntry? getChapterProgress(int chapterNumber) =>
      _chapterProgress[chapterNumber];

  /// Get list of providers that contributed data
  List<String> get contributingProviders =>
      _detailedMedia?.contributingProviders ?? [];

  /// Check if data is aggregated from multiple providers
  bool get isAggregated => contributingProviders.length > 1;

  Future<void> loadMediaDetails(String id, String sourceId) async {
    _isLoading = true;
    _error = null;
    _sourceId = sourceId;
    notifyListeners();

    try {
      // Load media details
      final mediaResult = await getMediaDetails(
        GetMediaDetailsParams(id: id, sourceId: sourceId),
      );

      await mediaResult.fold(
        (failure) async {
          _error = ErrorMessageMapper.mapFailureToMessage(failure);
          Logger.error(
            'Failed to load media details',
            tag: 'MediaDetailsViewModel',
            error: failure,
          );
        },
        (mediaEntity) async {
          _media = mediaEntity;

          // Load library status
          await _loadLibraryStatus(id);

          // Load watch history entry
          await _loadWatchHistory(id);

          // Check if this is an external source for aggregation
          final isExternalSource = _isExternalSource(sourceId);

          // Load episodes or chapters based on media type
          if (mediaEntity.type == MediaType.anime ||
              mediaEntity.type == MediaType.tvShow) {
            if (isExternalSource) {
              // Use aggregation for external sources
              Logger.info(
                'Using cross-provider aggregation for episodes',
                tag: 'MediaDetailsViewModel',
              );
              final episodesResult = await mediaRepository
                  .getEpisodesWithAggregation(mediaEntity);
              episodesResult.fold(
                (failure) {
                  _error = ErrorMessageMapper.mapFailureToMessage(failure);
                  Logger.error(
                    'Failed to load episodes with aggregation',
                    tag: 'MediaDetailsViewModel',
                    error: failure,
                  );
                },
                (episodeList) {
                  _episodes = episodeList;
                  _loadEpisodeProgress();
                  Logger.info(
                    'Loaded ${episodeList.length} aggregated episodes',
                    tag: 'MediaDetailsViewModel',
                  );
                },
              );
            } else {
              // Use regular method for extensions
              final episodesResult = await getEpisodes(
                GetEpisodesParams(mediaId: id, sourceId: sourceId),
              );
              episodesResult.fold(
                (failure) {
                  _error = ErrorMessageMapper.mapFailureToMessage(failure);
                  Logger.error(
                    'Failed to load episodes',
                    tag: 'MediaDetailsViewModel',
                    error: failure,
                  );
                },
                (episodeList) {
                  _episodes = episodeList;
                  _loadEpisodeProgress();
                },
              );
            }
          } else if (mediaEntity.type == MediaType.manga ||
              mediaEntity.type == MediaType.novel) {
            if (isExternalSource) {
              // Use aggregation for external sources
              Logger.info(
                'Using cross-provider aggregation for chapters',
                tag: 'MediaDetailsViewModel',
              );
              final chaptersResult = await mediaRepository
                  .getChaptersWithAggregation(mediaEntity);
              chaptersResult.fold(
                (failure) {
                  _error = ErrorMessageMapper.mapFailureToMessage(failure);
                  Logger.error(
                    'Failed to load chapters with aggregation',
                    tag: 'MediaDetailsViewModel',
                    error: failure,
                  );
                },
                (chapterList) {
                  _chapters = chapterList;
                  _loadChapterProgress();
                  Logger.info(
                    'Loaded ${chapterList.length} aggregated chapters',
                    tag: 'MediaDetailsViewModel',
                  );
                },
              );
            } else {
              // Use regular method for extensions
              final chaptersResult = await getChapters(
                GetChaptersParams(mediaId: id, sourceId: sourceId),
              );
              chaptersResult.fold(
                (failure) {
                  _error = ErrorMessageMapper.mapFailureToMessage(failure);
                  Logger.error(
                    'Failed to load chapters',
                    tag: 'MediaDetailsViewModel',
                    error: failure,
                  );
                },
                (chapterList) {
                  _chapters = chapterList;
                  _loadChapterProgress();
                },
              );
            }
          }
        },
      );
    } catch (e, stackTrace) {
      _error = 'An unexpected error occurred. Please try again.';
      Logger.error(
        'Unexpected error in loadMediaDetails',
        tag: 'MediaDetailsViewModel',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Check if a source ID is an external source (vs extension)
  bool _isExternalSource(String sourceId) {
    final externalSources = ['tmdb', 'anilist', 'jikan', 'kitsu', 'simkl'];
    return externalSources.contains(sourceId.toLowerCase());
  }

  Future<void> addMediaToLibrary(LibraryStatus status) async {
    if (_media == null) {
      _error = 'No media loaded';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userService = TrackingService.values.firstWhere(
        (service) => service.name == _sourceId!,
        orElse: () => throw ArgumentError('Unknown source: $_sourceId'),
      );

      final libraryItem = LibraryItemEntity(
        id: '${_media!.id}_${userService.name}',
        mediaId: _media!.id,
        userService: userService,
        media: _media!,
        status: status,
        progress: WatchProgress(currentEpisode: 0, currentChapter: 0),
        addedAt: DateTime.now(),
      );

      final result = await addToLibrary(AddToLibraryParams(item: libraryItem));

      result.fold((failure) {
        _error = ErrorMessageMapper.mapFailureToMessage(failure);
        Logger.error(
          'Failed to add media to library',
          tag: 'MediaDetailsViewModel',
          error: failure,
        );
      }, (_) => _isInLibrary = true);
    } catch (e, stackTrace) {
      _error = 'An unexpected error occurred. Please try again.';
      Logger.error(
        'Unexpected error adding media to library',
        tag: 'MediaDetailsViewModel',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void playEpisode(EpisodeEntity episode) {
    // This method will be used by the UI to navigate to the video player
    // The actual navigation logic will be handled by the UI layer
  }

  void readChapter(ChapterEntity chapter) {
    // This method will be used by the UI to navigate to the manga reader
    // The actual navigation logic will be handled by the UI layer
  }

  /// Load library status for the media
  Future<void> _loadLibraryStatus(String mediaId) async {
    if (libraryRepository == null) return;

    try {
      final result = await libraryRepository!.getLibraryItem(mediaId);
      result.fold(
        (failure) => Logger.debug(
          'No library item found for media: $mediaId',
          tag: 'MediaDetailsViewModel',
        ),
        (item) {
          _libraryItem = item;
          _isInLibrary = true;
        },
      );
    } catch (e) {
      Logger.debug(
        'Error loading library status: $e',
        tag: 'MediaDetailsViewModel',
      );
    }
  }

  /// Load watch history entry for the media
  Future<void> _loadWatchHistory(String mediaId) async {
    if (watchHistoryRepository == null) return;

    try {
      final result = await watchHistoryRepository!.getEntry(mediaId);
      result.fold(
        (failure) => Logger.debug(
          'No watch history entry found for media: $mediaId',
          tag: 'MediaDetailsViewModel',
        ),
        (entry) {
          _watchHistoryEntry = entry;
        },
      );
    } catch (e) {
      Logger.debug(
        'Error loading watch history: $e',
        tag: 'MediaDetailsViewModel',
      );
    }
  }

  /// Load episode progress from watch history
  void _loadEpisodeProgress() {
    if (watchHistoryRepository == null || _watchHistoryEntry == null) return;

    _episodeProgress.clear();
    // Map episodes to watch history entries by episode number
    for (final episode in _episodes) {
      if (_watchHistoryEntry!.episodeNumber == episode.number) {
        _episodeProgress[episode.number] = _watchHistoryEntry;
      }
    }
  }

  /// Load chapter progress from watch history
  void _loadChapterProgress() {
    if (watchHistoryRepository == null || _watchHistoryEntry == null) return;

    _chapterProgress.clear();
    // Map chapters to watch history entries by chapter number
    for (final chapter in _chapters) {
      final chapterNum = chapter.number.toInt();
      if (_watchHistoryEntry!.chapterNumber == chapterNum) {
        _chapterProgress[chapterNum] = _watchHistoryEntry;
      }
    }
  }

  /// Toggle library status (add/remove from library)
  Future<void> toggleLibraryStatus(LibraryStatus status) async {
    if (_media == null || libraryRepository == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      if (_isInLibrary && _libraryItem != null) {
        // Remove from library
        final result = await libraryRepository!.removeFromLibrary(
          _libraryItem!.id,
        );
        result.fold(
          (failure) {
            _error = ErrorMessageMapper.mapFailureToMessage(failure);
            Logger.error(
              'Failed to remove from library',
              tag: 'MediaDetailsViewModel',
              error: failure,
            );
          },
          (_) {
            _isInLibrary = false;
            _libraryItem = null;
            Logger.info(
              'Removed from library: ${_media!.id}',
              tag: 'MediaDetailsViewModel',
            );
          },
        );
      } else {
        // Create library item from media
        final userService = TrackingService.values.firstWhere(
          (service) => service.name == _sourceId,
          orElse: () => TrackingService.local,
        );

        final newItem = LibraryItemEntity(
          id: '${_media!.id}_${userService.name}',
          mediaId: _media!.id,
          userService: userService,
          media: _media,
          status: status,
          addedAt: DateTime.now(),
          lastUpdated: DateTime.now(),
          mediaType: _media!.type,
          sourceId: _sourceId,
          sourceName: _sourceId,
        );

        // Add to library
        final result = await addToLibrary(AddToLibraryParams(item: newItem));
        result.fold(
          (failure) {
            _error = ErrorMessageMapper.mapFailureToMessage(failure);
            Logger.error(
              'Failed to add to library',
              tag: 'MediaDetailsViewModel',
              error: failure,
            );
          },
          (_) {
            _isInLibrary = true;
            _libraryItem = newItem;
            Logger.info(
              'Added to library: ${_media!.id}',
              tag: 'MediaDetailsViewModel',
            );
          },
        );
      }
    } catch (e, stackTrace) {
      _error = 'An unexpected error occurred. Please try again.';
      Logger.error(
        'Unexpected error toggling library status',
        tag: 'MediaDetailsViewModel',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update library item status
  Future<void> updateLibraryStatus(LibraryStatus newStatus) async {
    if (_libraryItem == null || libraryRepository == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final updatedItem = _libraryItem!.copyWith(
        status: newStatus,
        lastUpdated: DateTime.now(),
      );

      final result = await libraryRepository!.updateLibraryItem(updatedItem);
      result.fold(
        (failure) {
          _error = ErrorMessageMapper.mapFailureToMessage(failure);
          Logger.error(
            'Failed to update library status',
            tag: 'MediaDetailsViewModel',
            error: failure,
          );
        },
        (_) {
          _libraryItem = updatedItem;
          Logger.info(
            'Updated library status: ${_media!.id}',
            tag: 'MediaDetailsViewModel',
          );
        },
      );
    } catch (e, stackTrace) {
      _error = 'An unexpected error occurred. Please try again.';
      Logger.error(
        'Unexpected error updating library status',
        tag: 'MediaDetailsViewModel',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
