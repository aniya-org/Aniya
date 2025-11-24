import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../domain/entities/media_entity.dart';
import '../../error/exceptions.dart';
import '../../utils/logger.dart';

class TmdbExternalDataSourceImpl {
  late final Dio _dio;
  late final String _apiKey;

  TmdbExternalDataSourceImpl() {
    _dio = Dio();
    _apiKey = dotenv.env['TMDB_API_KEY'] ?? '';
    if (_apiKey.isEmpty) {
      throw Exception('TMDB_API_KEY not found in .env');
    }
    _dio.options.baseUrl = 'https://api.themoviedb.org/3';
    _dio.options.queryParameters = {'api_key': _apiKey};
  }

  Future<List<MediaEntity>> searchMedia(
    String query,
    MediaType type, {
    int page = 1,
  }) async {
    try {
      List<dynamic> results = [];
      if (type == MediaType.movie) {
        final response = await _dio.get(
          '/search/movie',
          queryParameters: {'query': query},
        );
        results = response.data['results'] ?? [];
      } else if (type == MediaType.tvShow) {
        final response = await _dio.get(
          '/search/tv',
          queryParameters: {'query': query},
        );
        results = response.data['results'] ?? [];
      } else {
        return [];
      }
      return results
          .map((r) => _mapToMediaEntity(r, type, 'tmdb', 'TMDB'))
          .toList();
    } catch (e) {
      Logger.error('TMDB search failed', error: e);
      throw ServerException('Failed to search TMDB: $e');
    }
  }

  Future<List<MediaEntity>> getTrending(MediaType type, {int page = 1}) async {
    try {
      String endpoint;
      if (type == MediaType.movie) {
        endpoint = '/trending/movie/week';
      } else if (type == MediaType.tvShow) {
        endpoint = '/trending/tv/week';
      } else {
        return [];
      }
      final response = await _dio.get(endpoint);
      final List results = response.data['results'] ?? [];
      return results
          .map((r) => _mapToMediaEntity(r, type, 'tmdb', 'TMDB'))
          .toList();
    } catch (e) {
      Logger.error('TMDB trending failed', error: e);
      throw ServerException('Failed to get TMDB trending: $e');
    }
  }

  Future<List<MediaEntity>> getPopular(MediaType type, {int page = 1}) async {
    try {
      String endpoint;
      if (type == MediaType.movie) {
        endpoint = '/movie/popular';
      } else if (type == MediaType.tvShow) {
        endpoint = '/tv/popular';
      } else {
        return [];
      }
      final response = await _dio.get(
        endpoint,
        queryParameters: {'page': page},
      );
      final List results = response.data['results'] ?? [];
      return results
          .map((r) => _mapToMediaEntity(r, type, 'tmdb', 'TMDB'))
          .toList();
    } catch (e) {
      Logger.error('TMDB popular failed', error: e);
      throw ServerException('Failed to get TMDB popular: $e');
    }
  }

  MediaEntity _mapToMediaEntity(
    Map<String, dynamic> json,
    MediaType type,
    String sourceId,
    String sourceName,
  ) {
    return MediaEntity(
      id: json['id'].toString(),
      title: json['title'] ?? json['name'] ?? '',
      coverImage: _getImageUrl(json['poster_path']),
      bannerImage: _getImageUrl(json['backdrop_path']),
      description: json['overview'],
      type: type,
      rating: (json['vote_average'] ?? 0).toDouble(),
      genres: [], // TMDB API needs extra call for genres
      status: MediaStatus.ongoing, // Default for TMDB
      sourceId: sourceId,
      sourceName: sourceName,
    );
  }

  String? _getImageUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    return 'https://image.tmdb.org/t/p/w500$path';
  }
}
