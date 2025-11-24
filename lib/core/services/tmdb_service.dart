import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tmdb_api/tmdb_api.dart' hide Logger; // Hide tmdb_api's Logger
import '../utils/logger.dart';

/// Service for interacting with The Movie Database (TMDB) API
class TmdbService {
  late final TMDB _tmdb;

  TmdbService() {
    final apiKey = dotenv.env['TMDB_API_KEY'] ?? '';

    if (apiKey.isEmpty) {
      Logger.error('TMDB_API_KEY not found in environment variables');
    }

    _tmdb = TMDB(
      ApiKeys(apiKey, ''), // v3 API key only (v4 not needed yet)
      logConfig: ConfigLogger.showNone(), // Production mode
    );

    Logger.info('TmdbService initialized', tag: 'TmdbService');
  }

  // ==================== Content Discovery ====================

  /// Get trending movies (day or week)
  Future<Map> getTrendingMovies({
    TimeWindow timeWindow = TimeWindow.day,
  }) async {
    try {
      final result = await _tmdb.v3.trending.getTrending(
        mediaType: MediaType.movie,
        timeWindow: timeWindow,
      );
      return result;
    } catch (e) {
      Logger.error(
        'Error fetching trending movies',
        error: e,
        tag: 'TmdbService',
      );
      rethrow;
    }
  }

  /// Get trending TV shows
  Future<Map> getTrendingTVShows({
    TimeWindow timeWindow = TimeWindow.day,
  }) async {
    try {
      final result = await _tmdb.v3.trending.getTrending(
        mediaType: MediaType.tv,
        timeWindow: timeWindow,
      );
      return result;
    } catch (e) {
      Logger.error(
        'Error fetching trending TV shows',
        error: e,
        tag: 'TmdbService',
      );
      rethrow;
    }
  }

  /// Get popular movies
  Future<Map> getPopularMovies({int page = 1}) async {
    try {
      final result = await _tmdb.v3.movies.getPopular(page: page);
      return result;
    } catch (e) {
      Logger.error(
        'Error fetching popular movies',
        error: e,
        tag: 'TmdbService',
      );
      rethrow;
    }
  }

  /// Get popular TV shows
  Future<Map> getPopularTVShows({int page = 1}) async {
    try {
      final result = await _tmdb.v3.tv.getPopular(page: page);
      return result;
    } catch (e) {
      Logger.error(
        'Error fetching popular TV shows',
        error: e,
        tag: 'TmdbService',
      );
      rethrow;
    }
  }

  /// Get top rated movies
  Future<Map> getTopRatedMovies({int page = 1}) async {
    try {
      final result = await _tmdb.v3.movies.getTopRated(page: page);
      return result;
    } catch (e) {
      Logger.error(
        'Error fetching top rated movies',
        error: e,
        tag: 'TmdbService',
      );
      rethrow;
    }
  }

  /// Get top rated TV shows
  Future<Map> getTopRatedTVShows({int page = 1}) async {
    try {
      final result = await _tmdb.v3.tv.getTopRated(page: page);
      return result;
    } catch (e) {
      Logger.error(
        'Error fetching top rated TV shows',
        error: e,
        tag: 'TmdbService',
      );
      rethrow;
    }
  }

  // ==================== Search ====================

  /// Search movies
  Future<Map> searchMovies(String query, {int page = 1}) async {
    try {
      final result = await _tmdb.v3.search.queryMovies(query, page: page);
      return result;
    } catch (e) {
      Logger.error('Error searching movies', error: e, tag: 'TmdbService');
      rethrow;
    }
  }

  /// Search TV shows
  Future<Map> searchTVShows(String query, {int page = 1}) async {
    try {
      final result = await _tmdb.v3.search.queryTvShows(query, page: page);
      return result;
    } catch (e) {
      Logger.error('Error searching TV shows', error: e, tag: 'TmdbService');
      rethrow;
    }
  }

  // ==================== Details ====================

  /// Get movie details
  Future<Map> getMovieDetails(int movieId, {String? appendToResponse}) async {
    try {
      final result = await _tmdb.v3.movies.getDetails(
        movieId,
        appendToResponse: appendToResponse,
      );
      return result;
    } catch (e) {
      Logger.error(
        'Error fetching movie details',
        error: e,
        tag: 'TmdbService',
      );
      rethrow;
    }
  }

  /// Get TV show details
  Future<Map> getTVShowDetails(int tvId, {String? appendToResponse}) async {
    try {
      final result = await _tmdb.v3.tv.getDetails(
        tvId,
        appendToResponse: appendToResponse,
      );
      return result;
    } catch (e) {
      Logger.error(
        'Error fetching TV show details',
        error: e,
        tag: 'TmdbService',
      );
      rethrow;
    }
  }

  /// Get movie credits (cast & crew)
  Future<Map> getMovieCredits(int movieId) async {
    try {
      final result = await _tmdb.v3.movies.getCredits(movieId);
      return result;
    } catch (e) {
      Logger.error(
        'Error fetching movie credits',
        error: e,
        tag: 'TmdbService',
      );
      rethrow;
    }
  }

  /// Get TV show credits (cast & crew)
  Future<Map> getTVShowCredits(int tvId) async {
    try {
      final result = await _tmdb.v3.tv.getCredits(tvId);
      return result;
    } catch (e) {
      Logger.error(
        'Error fetching TV show credits',
        error: e,
        tag: 'TmdbService',
      );
      rethrow;
    }
  }

  /// Get movie videos (trailers, teasers, clips)
  Future<Map> getMovieVideos(int movieId) async {
    try {
      final result = await _tmdb.v3.movies.getVideos(movieId);
      return result;
    } catch (e) {
      Logger.error('Error fetching movie videos', error: e, tag: 'TmdbService');
      rethrow;
    }
  }

  /// Get TV show videos
  Future<Map> getTVShowVideos(int tvId) async {
    try {
      final result = await _tmdb.v3.tv.getVideos(tvId.toString());
      return result;
    } catch (e) {
      Logger.error(
        'Error fetching TV show videos',
        error: e,
        tag: 'TmdbService',
      );
      rethrow;
    }
  }

  /// Get TV show season details (episodes)
  Future<Map> getTVShowSeasonDetails(int tvId, int seasonNumber) async {
    try {
      final result = await _tmdb.v3.tvSeasons.getDetails(tvId, seasonNumber);
      return result;
    } catch (e) {
      Logger.error(
        'Error fetching TV show season details',
        error: e,
        tag: 'TmdbService',
      );
      rethrow;
    }
  }

  /// Get movie images (posters & backdrops)
  Future<Map> getMovieImages(int movieId) async {
    try {
      final result = await _tmdb.v3.movies.getImages(movieId);
      return result;
    } catch (e) {
      Logger.error('Error fetching movie images', error: e, tag: 'TmdbService');
      rethrow;
    }
  }

  /// Get TV show images
  Future<Map> getTVShowImages(int tvId) async {
    try {
      final result = await _tmdb.v3.tv.getImages(tvId);
      return result;
    } catch (e) {
      Logger.error(
        'Error fetching TV show images',
        error: e,
        tag: 'TmdbService',
      );
      rethrow;
    }
  }

  /// Get TV season details
  Future<Map> getTVSeasonDetails(int tvId, int seasonNumber) async {
    try {
      final result = await _tmdb.v3.tvSeasons.getDetails(tvId, seasonNumber);
      return result;
    } catch (e) {
      Logger.error(
        'Error fetching TV season details',
        error: e,
        tag: 'TmdbService',
      );
      rethrow;
    }
  }

  /// Get TV episode details
  Future<Map> getTVEpisodeDetails(
    int tvId,
    int seasonNumber,
    int episodeNumber,
  ) async {
    try {
      final result = await _tmdb.v3.tvEpisodes.getDetails(
        tvId,
        seasonNumber,
        episodeNumber,
      );
      return result;
    } catch (e) {
      Logger.error(
        'Error fetching TV episode details',
        error: e,
        tag: 'TmdbService',
      );
      rethrow;
    }
  }

  // ==================== Image URL Helpers ====================

  /// Build poster image URL
  /// Sizes: w92, w154, w185, w342, w500, w780, original
  static String getPosterUrl(String? posterPath, {String size = 'w500'}) {
    if (posterPath == null || posterPath.isEmpty) return '';
    return 'https://image.tmdb.org/t/p/$size$posterPath';
  }

  /// Build backdrop image URL
  /// Sizes: w300, w780, w1280, original
  static String getBackdropUrl(
    String? backdropPath, {
    String size = 'original',
  }) {
    if (backdropPath == null || backdropPath.isEmpty) return '';
    return 'https://image.tmdb.org/t/p/$size$backdropPath';
  }

  /// Build profile image URL (for cast photos)
  /// Sizes: w45, w185, h632, original
  static String getProfileUrl(String? profilePath, {String size = 'w185'}) {
    if (profilePath == null || profilePath.isEmpty) return '';
    return 'https://image.tmdb.org/t/p/$size$profilePath';
  }

  /// Dispose resources
  void dispose() {
    _tmdb.close();
  }
}
