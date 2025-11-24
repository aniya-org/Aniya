import 'package:flutter/foundation.dart';
import '../../../../core/domain/entities/media_entity.dart';
import '../../../../core/domain/entities/episode_entity.dart';
import '../../../../core/domain/entities/chapter_entity.dart';
import '../../../../core/domain/entities/library_item_entity.dart';
import '../../../../core/domain/usecases/get_media_details_usecase.dart';
import '../../../../core/domain/usecases/get_episodes_usecase.dart';
import '../../../../core/domain/usecases/get_chapters_usecase.dart';
import '../../../../core/domain/usecases/add_to_library_usecase.dart';
import '../../../../core/utils/error_message_mapper.dart';
import '../../../../core/utils/logger.dart';

class MediaDetailsViewModel extends ChangeNotifier {
  final GetMediaDetailsUseCase getMediaDetails;
  final GetEpisodesUseCase getEpisodes;
  final GetChaptersUseCase getChapters;
  final AddToLibraryUseCase addToLibrary;

  MediaDetailsViewModel({
    required this.getMediaDetails,
    required this.getEpisodes,
    required this.getChapters,
    required this.addToLibrary,
  });

  MediaEntity? _media;
  List<EpisodeEntity> _episodes = [];
  List<ChapterEntity> _chapters = [];
  bool _isLoading = false;
  bool _isInLibrary = false;
  String? _error;

  MediaEntity? get media => _media;
  List<EpisodeEntity> get episodes => _episodes;
  List<ChapterEntity> get chapters => _chapters;
  bool get isLoading => _isLoading;
  bool get isInLibrary => _isInLibrary;
  String? get error => _error;

  Future<void> loadMediaDetails(String id, String sourceId) async {
    _isLoading = true;
    _error = null;
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

          // Load episodes or chapters based on media type
          if (mediaEntity.type == MediaType.anime ||
              mediaEntity.type == MediaType.tvShow) {
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
          } else if (mediaEntity.type == MediaType.manga) {
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
      final libraryItem = LibraryItemEntity(
        id: _media!.id,
        media: _media!,
        status: status,
        currentEpisode: 0,
        currentChapter: 0,
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
