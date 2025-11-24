import 'package:flutter/foundation.dart';
import '../../../../core/domain/entities/media_entity.dart';
import '../../../../core/domain/entities/library_item_entity.dart';
import '../../../../core/domain/usecases/get_trending_media_usecase.dart';
import '../../../../core/domain/usecases/get_library_items_usecase.dart';
import '../../../../core/services/tmdb_service.dart';
import '../../../../core/utils/error_message_mapper.dart';
import '../../../../core/utils/logger.dart';

class HomeViewModel extends ChangeNotifier {
  final GetTrendingMediaUseCase getTrendingMedia;
  final GetLibraryItemsUseCase getLibraryItems;
  final TmdbService tmdbService;

  HomeViewModel({
    required this.getTrendingMedia,
    required this.getLibraryItems,
    required this.tmdbService,
  });

  List<MediaEntity> _trendingAnime = [];
  List<MediaEntity> _trendingManga = [];
  List<LibraryItemEntity> _continueWatching = [];
  List<Map> _trendingMovies = []; // TMDB movies
  List<Map> _trendingTVShows = []; // TMDB TV shows
  List<Map> _popularMovies = []; // TMDB popular movies
  List<Map> _popularTVShows = []; // TMDB popular TV shows
  bool _isLoading = false;
  String? _error;

  List<MediaEntity> get trendingAnime => _trendingAnime;
  List<MediaEntity> get trendingManga => _trendingManga;
  List<LibraryItemEntity> get continueWatching => _continueWatching;
  List<Map> get trendingMovies => _trendingMovies;
  List<Map> get trendingTVShows => _trendingTVShows;
  List<Map> get popularMovies => _popularMovies;
  List<Map> get popularTVShows => _popularTVShows;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadHomeData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Load trending anime
      final animeResult = await getTrendingMedia(
        GetTrendingMediaParams(type: MediaType.anime, page: 1),
      );
      animeResult.fold((failure) {
        _error = ErrorMessageMapper.mapFailureToMessage(failure);
        Logger.error(
          'Failed to load trending anime',
          tag: 'HomeViewModel',
          error: failure,
        );
      }, (anime) => _trendingAnime = anime);

      // Load trending manga
      final mangaResult = await getTrendingMedia(
        GetTrendingMediaParams(type: MediaType.manga, page: 1),
      );
      mangaResult.fold((failure) {
        _error = ErrorMessageMapper.mapFailureToMessage(failure);
        Logger.error(
          'Failed to load trending manga',
          tag: 'HomeViewModel',
          error: failure,
        );
      }, (manga) => _trendingManga = manga);

      // Load continue watching (library items with status watching)
      final libraryResult = await getLibraryItems(
        GetLibraryItemsParams(status: LibraryStatus.watching),
      );
      libraryResult.fold((failure) {
        _error = ErrorMessageMapper.mapFailureToMessage(failure);
        Logger.error(
          'Failed to load continue watching',
          tag: 'HomeViewModel',
          error: failure,
        );
      }, (items) => _continueWatching = items);

      // Load TMDB content
      await _loadTmdbContent();
    } catch (e, stackTrace) {
      _error = 'An unexpected error occurred. Please try again.';
      Logger.error(
        'Unexpected error in loadHomeData',
        tag: 'HomeViewModel',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await loadHomeData();
  }

  Future<void> _loadTmdbContent() async {
    try {
      // Fetch trending movies
      final trendingMoviesResponse = await tmdbService.getTrendingMovies();
      _trendingMovies = (trendingMoviesResponse['results'] as List? ?? [])
          .cast<Map>();

      // Fetch trending TV shows
      final trendingTVResponse = await tmdbService.getTrendingTVShows();
      _trendingTVShows = (trendingTVResponse['results'] as List? ?? [])
          .cast<Map>();

      // Fetch popular movies
      final popularMoviesResponse = await tmdbService.getPopularMovies();
      _popularMovies = (popularMoviesResponse['results'] as List? ?? [])
          .cast<Map>();

      // Fetch popular TV shows
      final popularTVResponse = await tmdbService.getPopularTVShows();
      _popularTVShows = (popularTVResponse['results'] as List? ?? [])
          .cast<Map>();

      Logger.info(
        'TMDB content loaded: ${_trendingMovies.length} movies, ${_trendingTVShows.length} TV shows',
        tag: 'HomeViewModel',
      );
    } catch (e, stackTrace) {
      Logger.error(
        'Error loading TMDB content',
        tag: 'HomeViewModel',
        error: e,
        stackTrace: stackTrace,
      );
      // Don't set error here as we don't want to block the whole screen
      // if only TMDB fails
    }
  }
}
