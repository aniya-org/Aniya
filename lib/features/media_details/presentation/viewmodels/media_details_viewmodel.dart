import 'package:flutter/foundation.dart';
import '../../../../core/domain/entities/media_entity.dart';
import '../../../../core/domain/entities/episode_entity.dart';
import '../../../../core/domain/entities/chapter_entity.dart';
import '../../../../core/domain/entities/library_item_entity.dart';
import '../../../../core/domain/entities/media_details_entity.dart';
import '../../../../core/enums/tracking_service.dart';
import '../../../../core/domain/usecases/get_media_details_usecase.dart';
import '../../../../core/domain/usecases/get_episodes_usecase.dart';
import '../../../../core/domain/usecases/get_chapters_usecase.dart';
import '../../../../core/domain/usecases/add_to_library_usecase.dart';
import '../../../../core/domain/repositories/media_repository.dart';
import '../../../../core/utils/error_message_mapper.dart';
import '../../../../core/utils/logger.dart';

class MediaDetailsViewModel extends ChangeNotifier {
  final GetMediaDetailsUseCase getMediaDetails;
  final GetEpisodesUseCase getEpisodes;
  final GetChaptersUseCase getChapters;
  final AddToLibraryUseCase addToLibrary;
  final MediaRepository mediaRepository;

  MediaDetailsViewModel({
    required this.getMediaDetails,
    required this.getEpisodes,
    required this.getChapters,
    required this.addToLibrary,
    required this.mediaRepository,
  });

  MediaEntity? _media;
  MediaDetailsEntity? _detailedMedia;
  List<EpisodeEntity> _episodes = [];
  List<ChapterEntity> _chapters = [];
  bool _isLoading = false;
  bool _isInLibrary = false;
  String? _error;
  String? _sourceId;

  MediaEntity? get media => _media;
  MediaDetailsEntity? get detailedMedia => _detailedMedia;
  List<EpisodeEntity> get episodes => _episodes;
  List<ChapterEntity> get chapters => _chapters;
  bool get isLoading => _isLoading;
  bool get isInLibrary => _isInLibrary;
  String? get error => _error;

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
              episodesResult.fold((failure) {
                _error = ErrorMessageMapper.mapFailureToMessage(failure);
                Logger.error(
                  'Failed to load episodes',
                  tag: 'MediaDetailsViewModel',
                  error: failure,
                );
              }, (episodeList) => _episodes = episodeList);
            }
          } else if (mediaEntity.type == MediaType.manga) {
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
              chaptersResult.fold((failure) {
                _error = ErrorMessageMapper.mapFailureToMessage(failure);
                Logger.error(
                  'Failed to load chapters',
                  tag: 'MediaDetailsViewModel',
                  error: failure,
                );
              }, (chapterList) => _chapters = chapterList);
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
}
