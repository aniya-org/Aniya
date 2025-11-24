import 'package:dio/dio.dart';

import '../../error/exceptions.dart';

/// Data source for TMDB (The Movie Database) API integration
/// Provides rich metadata for movies and TV shows
abstract class TMDBDataSource {
  /// Get movie details from TMDB
  Future<TMDBMediaDetails> getMovieDetails(String tmdbId);

  /// Get TV show details from TMDB
  Future<TMDBMediaDetails> getTVShowDetails(String tmdbId);

  /// Search for movies on TMDB
  Future<List<TMDBSearchResult>> searchMovies(String query);

  /// Search for TV shows on TMDB
  Future<List<TMDBSearchResult>> searchTVShows(String query);

  /// Get cached TMDB data
  Future<TMDBMediaDetails?> getCachedDetails(String tmdbId);

  /// Cache TMDB data
  Future<void> cacheDetails(String tmdbId, TMDBMediaDetails details);
}

/// TMDB media details model
class TMDBMediaDetails {
  final String id;
  final String title;
  final String? overview;
  final String? posterPath;
  final String? backdropPath;
  final double? voteAverage;
  final int? voteCount;
  final String? releaseDate;
  final List<String> genres;
  final List<TMDBCast> cast;
  final List<TMDBCrew> crew;
  final List<TMDBVideo> trailers;
  final List<TMDBRecommendation> recommendations;

  TMDBMediaDetails({
    required this.id,
    required this.title,
    this.overview,
    this.posterPath,
    this.backdropPath,
    this.voteAverage,
    this.voteCount,
    this.releaseDate,
    required this.genres,
    required this.cast,
    required this.crew,
    required this.trailers,
    required this.recommendations,
  });

  factory TMDBMediaDetails.fromJson(Map<String, dynamic> json) {
    return TMDBMediaDetails(
      id: json['id'].toString(),
      title: json['title'] ?? json['name'] ?? '',
      overview: json['overview'],
      posterPath: json['poster_path'],
      backdropPath: json['backdrop_path'],
      voteAverage: json['vote_average']?.toDouble(),
      voteCount: json['vote_count'],
      releaseDate: json['release_date'] ?? json['first_air_date'],
      genres:
          (json['genres'] as List<dynamic>?)
              ?.map((g) => g['name'] as String)
              .toList() ??
          [],
      cast: [],
      crew: [],
      trailers: [],
      recommendations: [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'overview': overview,
      'poster_path': posterPath,
      'backdrop_path': backdropPath,
      'vote_average': voteAverage,
      'vote_count': voteCount,
      'release_date': releaseDate,
      'genres': genres.map((g) => {'name': g}).toList(),
    };
  }
}

class TMDBCast {
  final String id;
  final String name;
  final String character;
  final String? profilePath;

  TMDBCast({
    required this.id,
    required this.name,
    required this.character,
    this.profilePath,
  });

  factory TMDBCast.fromJson(Map<String, dynamic> json) {
    return TMDBCast(
      id: json['id'].toString(),
      name: json['name'],
      character: json['character'] ?? '',
      profilePath: json['profile_path'],
    );
  }
}

class TMDBCrew {
  final String id;
  final String name;
  final String job;
  final String? profilePath;

  TMDBCrew({
    required this.id,
    required this.name,
    required this.job,
    this.profilePath,
  });

  factory TMDBCrew.fromJson(Map<String, dynamic> json) {
    return TMDBCrew(
      id: json['id'].toString(),
      name: json['name'],
      job: json['job'] ?? '',
      profilePath: json['profile_path'],
    );
  }
}

class TMDBVideo {
  final String id;
  final String key;
  final String name;
  final String site;
  final String type;

  TMDBVideo({
    required this.id,
    required this.key,
    required this.name,
    required this.site,
    required this.type,
  });

  factory TMDBVideo.fromJson(Map<String, dynamic> json) {
    return TMDBVideo(
      id: json['id'],
      key: json['key'],
      name: json['name'],
      site: json['site'],
      type: json['type'],
    );
  }
}

class TMDBRecommendation {
  final String id;
  final String title;
  final String? posterPath;

  TMDBRecommendation({required this.id, required this.title, this.posterPath});

  factory TMDBRecommendation.fromJson(Map<String, dynamic> json) {
    return TMDBRecommendation(
      id: json['id'].toString(),
      title: json['title'] ?? json['name'] ?? '',
      posterPath: json['poster_path'],
    );
  }
}

class TMDBSearchResult {
  final String id;
  final String title;
  final String? posterPath;
  final String? overview;
  final String? releaseDate;

  TMDBSearchResult({
    required this.id,
    required this.title,
    this.posterPath,
    this.overview,
    this.releaseDate,
  });

  factory TMDBSearchResult.fromJson(Map<String, dynamic> json) {
    return TMDBSearchResult(
      id: json['id'].toString(),
      title: json['title'] ?? json['name'] ?? '',
      posterPath: json['poster_path'],
      overview: json['overview'],
      releaseDate: json['release_date'] ?? json['first_air_date'],
    );
  }
}

class TMDBDataSourceImpl implements TMDBDataSource {
  final Dio dio;
  final String apiKey;
  final Map<String, TMDBMediaDetails> _cache = {};

  static const String _baseUrl = 'https://api.themoviedb.org/3';
  static const String _imageBaseUrl = 'https://image.tmdb.org/t/p/w500';

  TMDBDataSourceImpl({required this.dio, required this.apiKey}) {
    // Configure Dio with base options
    dio.options.baseUrl = _baseUrl;
    dio.options.queryParameters = {'api_key': apiKey};
  }

  @override
  Future<TMDBMediaDetails> getMovieDetails(String tmdbId) async {
    try {
      // Check cache first
      final cached = await getCachedDetails(tmdbId);
      if (cached != null) {
        return cached;
      }

      // Fetch from API
      final response = await dio.get(
        '/movie/$tmdbId',
        queryParameters: {
          'append_to_response': 'credits,videos,recommendations',
        },
      );

      final details = _parseMediaDetails(response.data);

      // Cache the result
      await cacheDetails(tmdbId, details);

      return details;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw NotFoundException('Movie not found on TMDB: $tmdbId');
      }
      throw ServerException('Failed to get movie details: ${e.message}');
    } catch (e) {
      throw ServerException('Failed to get movie details: ${e.toString()}');
    }
  }

  @override
  Future<TMDBMediaDetails> getTVShowDetails(String tmdbId) async {
    try {
      // Check cache first
      final cached = await getCachedDetails(tmdbId);
      if (cached != null) {
        return cached;
      }

      // Fetch from API
      final response = await dio.get(
        '/tv/$tmdbId',
        queryParameters: {
          'append_to_response': 'credits,videos,recommendations',
        },
      );

      final details = _parseMediaDetails(response.data);

      // Cache the result
      await cacheDetails(tmdbId, details);

      return details;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw NotFoundException('TV show not found on TMDB: $tmdbId');
      }
      throw ServerException('Failed to get TV show details: ${e.message}');
    } catch (e) {
      throw ServerException('Failed to get TV show details: ${e.toString()}');
    }
  }

  TMDBMediaDetails _parseMediaDetails(Map<String, dynamic> json) {
    final details = TMDBMediaDetails.fromJson(json);

    // Parse credits
    final credits = json['credits'];
    final cast =
        (credits?['cast'] as List<dynamic>?)
            ?.map((c) => TMDBCast.fromJson(c))
            .toList() ??
        [];
    final crew =
        (credits?['crew'] as List<dynamic>?)
            ?.map((c) => TMDBCrew.fromJson(c))
            .toList() ??
        [];

    // Parse videos (trailers)
    final videos = json['videos'];
    final trailers =
        (videos?['results'] as List<dynamic>?)
            ?.map((v) => TMDBVideo.fromJson(v))
            .where((v) => v.type == 'Trailer')
            .toList() ??
        [];

    // Parse recommendations
    final recommendations = json['recommendations'];
    final recs =
        (recommendations?['results'] as List<dynamic>?)
            ?.map((r) => TMDBRecommendation.fromJson(r))
            .toList() ??
        [];

    return TMDBMediaDetails(
      id: details.id,
      title: details.title,
      overview: details.overview,
      posterPath: details.posterPath,
      backdropPath: details.backdropPath,
      voteAverage: details.voteAverage,
      voteCount: details.voteCount,
      releaseDate: details.releaseDate,
      genres: details.genres,
      cast: cast,
      crew: crew,
      trailers: trailers,
      recommendations: recs,
    );
  }

  @override
  Future<List<TMDBSearchResult>> searchMovies(String query) async {
    try {
      final response = await dio.get(
        '/search/movie',
        queryParameters: {'query': query},
      );

      final results = (response.data['results'] as List<dynamic>)
          .map((r) => TMDBSearchResult.fromJson(r))
          .toList();

      return results;
    } on DioException catch (e) {
      throw ServerException('Failed to search movies: ${e.message}');
    } catch (e) {
      throw ServerException('Failed to search movies: ${e.toString()}');
    }
  }

  @override
  Future<List<TMDBSearchResult>> searchTVShows(String query) async {
    try {
      final response = await dio.get(
        '/search/tv',
        queryParameters: {'query': query},
      );

      final results = (response.data['results'] as List<dynamic>)
          .map((r) => TMDBSearchResult.fromJson(r))
          .toList();

      return results;
    } on DioException catch (e) {
      throw ServerException('Failed to search TV shows: ${e.message}');
    } catch (e) {
      throw ServerException('Failed to search TV shows: ${e.toString()}');
    }
  }

  @override
  Future<TMDBMediaDetails?> getCachedDetails(String tmdbId) async {
    return _cache[tmdbId];
  }

  @override
  Future<void> cacheDetails(String tmdbId, TMDBMediaDetails details) async {
    _cache[tmdbId] = details;
  }

  /// Get full image URL from path
  static String getImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    return '$_imageBaseUrl$path';
  }
}
