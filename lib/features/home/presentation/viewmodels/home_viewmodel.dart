import 'package:flutter/foundation.dart';
import '../../../../core/domain/entities/media_entity.dart';
import '../../../../core/domain/entities/library_item_entity.dart';
import '../../../../core/domain/entities/watch_history_entry.dart';
import '../../../../core/domain/usecases/get_trending_media_usecase.dart';
import '../../../../core/domain/usecases/get_library_items_usecase.dart';
import '../../../../core/domain/repositories/watch_history_repository.dart';
import '../../../../core/services/tmdb_service.dart';
import '../../../../core/utils/error_message_mapper.dart';
import '../../../../core/utils/logger.dart';

class HomeViewModel extends ChangeNotifier {
  final GetTrendingMediaUseCase getTrendingMedia;
  final GetLibraryItemsUseCase getLibraryItems;
  final TmdbService tmdbService;
  final WatchHistoryRepository? watchHistoryRepository;

  HomeViewModel({
    required this.getTrendingMedia,
    required this.getLibraryItems,
    required this.tmdbService,
    this.watchHistoryRepository,
  });

  final List<MediaEntity> _trendingAnime = [];
  final List<MediaEntity> _trendingManga = [];
  List<LibraryItemEntity> _continueWatching = [];
  List<WatchHistoryEntry> _continueWatchingHistory = [];
  List<WatchHistoryEntry> _continueReadingHistory = [];
  List<Map> _trendingMovies = []; // TMDB movies
  List<Map> _trendingTVShows = []; // TMDB TV shows
  List<Map> _popularMovies = []; // TMDB popular movies
  List<Map> _popularTVShows = []; // TMDB popular TV shows
  bool _isLoading = false;
  String? _error;

  List<MediaEntity> get trendingAnime => _trendingAnime;
  List<MediaEntity> get trendingManga => _trendingManga;
  List<LibraryItemEntity> get continueWatching => _continueWatching;
  List<WatchHistoryEntry> get continueWatchingHistory =>
      _continueWatchingHistory;
  List<WatchHistoryEntry> get continueReadingHistory => _continueReadingHistory;
  List<Map> get trendingMovies => _trendingMovies;
  List<Map> get trendingTVShows => _trendingTVShows;
  List<Map> get popularMovies => _popularMovies;
  List<Map> get popularTVShows => _popularTVShows;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Returns true if there's any continue watching/reading content
  bool get hasContinueContent =>
      _continueWatching.isNotEmpty ||
      _continueWatchingHistory.isNotEmpty ||
      _continueReadingHistory.isNotEmpty;

  Future<void> loadHomeData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
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

      // Load watch history (Continue Watching from history)
      await _loadWatchHistory();

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

  /// Load watch history for Continue Watching and Continue Reading sections
  Future<void> _loadWatchHistory() async {
    if (watchHistoryRepository == null) return;

    try {
      // Load Continue Watching (video types)
      final watchingResult = await watchHistoryRepository!.getContinueWatching(
        limit: 10,
      );
      watchingResult.fold(
        (failure) => Logger.error(
          'Failed to load continue watching history',
          tag: 'HomeViewModel',
          error: failure,
        ),
        (entries) => _continueWatchingHistory = _dedupeHistoryEntries(entries),
      );

      // Load Continue Reading (manga/novels)
      final readingResult = await watchHistoryRepository!.getContinueReading(
        limit: 10,
      );
      readingResult.fold(
        (failure) => Logger.error(
          'Failed to load continue reading history',
          tag: 'HomeViewModel',
          error: failure,
        ),
        (entries) => _continueReadingHistory = _dedupeHistoryEntries(entries),
      );

      Logger.info(
        'Watch history loaded: ${_continueWatchingHistory.length} watching, ${_continueReadingHistory.length} reading',
        tag: 'HomeViewModel',
      );
    } catch (e, stackTrace) {
      Logger.error(
        'Error loading watch history',
        tag: 'HomeViewModel',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  List<WatchHistoryEntry> _dedupeHistoryEntries(
    List<WatchHistoryEntry> entries,
  ) {
    if (entries.length <= 1) return entries;

    final deduped = <WatchHistoryEntry>[];
    final seenKeys = <String>{};
    final sorted = [...entries]
      ..sort((a, b) => b.lastPlayedAt.compareTo(a.lastPlayedAt));

    for (final entry in sorted) {
      final key = _historyKey(entry);
      if (seenKeys.add(key)) {
        deduped.add(entry);
      }
    }

    return deduped;
  }

  String _historyKey(WatchHistoryEntry entry) {
    if (entry.episodeNumber != null) {
      return '${entry.mediaId}_episode_${entry.episodeNumber}';
    }
    if (entry.chapterNumber != null) {
      return '${entry.mediaId}_chapter_${entry.chapterNumber}';
    }
    return entry.normalizedId ?? entry.id;
  }
}
