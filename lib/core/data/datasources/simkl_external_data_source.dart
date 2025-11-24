import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../domain/entities/entities.dart';
import '../../error/exceptions.dart';
import '../../utils/logger.dart';

class SimklExternalDataSourceImpl {
  late final Dio _dio;
  late final String? _clientId;

  SimklExternalDataSourceImpl() {
    _dio = Dio();
    _clientId = dotenv.env['SIMKL_CLIENT_ID'];
    _dio.options.baseUrl = 'https://api.simkl.com';
    if (_clientId != null) {
      _dio.options.queryParameters = {'client_id': _clientId};
    }
  }

  /// Advanced search with filtering (Simkl has limited filtering options)
  Future<SearchResult<List<MediaEntity>>> searchMedia(
    String query,
    MediaType type, {
    List<String>? genres,
    String? format,
    int? startDate,
    int? minScore,
    String? sort = 'popularity',
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final String simklType = _mapMediaTypeToSimkl(type);

      // Simkl has limited filtering - mainly supports genre and type
      final queryParams = <String, dynamic>{
        'q': query,
        'limit': perPage,
        'page': page,
      };

      // Simkl supports some filtering
      if (genres != null && genres.isNotEmpty) {
        queryParams['genre'] = genres.first; // Simkl only supports one genre
      }

      if (format != null) {
        queryParams['type'] = format.toLowerCase();
      }

      if (startDate != null) {
        queryParams['year'] = startDate;
      }

      if (sort != null) {
        queryParams['sort'] = sort;
      }

      final response = await _dio.get(
        '/search/$simklType',
        queryParameters: queryParams,
      );

      final List results = response.data ?? [];
      // Simkl doesn't provide pagination info, so we estimate
      final hasNextPage = results.length == perPage;

      final mappedResults = results
          .map((r) => _mapToMediaEntity(r, type, 'simkl', 'Simkl'))
          .toList();

      // Since Simkl doesn't provide total count, we use current page size * 5 as estimate
      final estimatedTotal = page * perPage * 5;

      return SearchResult<List<MediaEntity>>(
        items: mappedResults,
        totalCount: estimatedTotal,
        currentPage: page,
        hasNextPage: hasNextPage,
        perPage: perPage,
      );
    } catch (e) {
      Logger.error('Simkl advanced search failed', error: e);
      throw ServerException('Failed to search Simkl: $e');
    }
  }

  /// Get media details (Simkl details are limited)
  Future<MediaDetailsEntity> getMediaDetails(
    String id,
    MediaType type, {
    bool includeCharacters = false,
    bool includeStaff = false,
    bool includeReviews = false,
  }) async {
    try {
      final String simklType = _mapMediaTypeToSimkl(type);

      final response = await _dio.get('https://api.simkl.com/$simklType/$id');
      final media = response.data;

      return _mapToMediaDetailsEntity(media, type);
    } catch (e) {
      Logger.error('Simkl get details failed', error: e);
      throw ServerException('Failed to get Simkl details: $e');
    }
  }

  /// Legacy simple search for backward compatibility
  Future<List<MediaEntity>> simpleSearchMedia(
    String query,
    MediaType type, {
    int page = 1,
  }) async {
    final result = await searchMedia(query, type, page: page, perPage: 20);
    return result.items;
  }

  Future<List<MediaEntity>> getTrending(
    MediaType type, {
    int page = 1,
    String? format,
  }) async {
    try {
      final String simklType = _mapMediaTypeToSimkl(type);
      final queryParams = <String, dynamic>{'page': page, 'limit': 20};

      if (format != null) {
        queryParams['type'] = format.toLowerCase();
      }

      final response = await _dio.get(
        '/trending/$simklType',
        queryParameters: queryParams,
      );

      final List results = response.data ?? [];
      return results
          .map((r) => _mapToMediaEntity(r, type, 'simkl', 'Simkl'))
          .toList();
    } catch (e) {
      Logger.error('Simkl trending failed', error: e);
      throw ServerException('Failed to get Simkl trending: $e');
    }
  }

  Future<List<MediaEntity>> getPopular(MediaType type, {int page = 1}) async {
    try {
      final String simklType = _mapMediaTypeToSimkl(type);
      final response = await _dio.get(
        '/popular/$simklType',
        queryParameters: {'page': page, 'limit': 20},
      );

      final List results = response.data ?? [];
      return results
          .map((r) => _mapToMediaEntity(r, type, 'simkl', 'Simkl'))
          .toList();
    } catch (e) {
      Logger.error('Simkl popular failed', error: e);
      throw ServerException('Failed to get Simkl popular: $e');
    }
  }

  /// Get TV seasonal content
  Future<List<MediaEntity>> getSeasonalTvShows({
    int? year,
    String? season,
    int page = 1,
  }) async {
    try {
      final currentYear = DateTime.now().year;
      final targetYear = year ?? currentYear;

      final response = await _dio.get(
        '/tv/icons/seasons/$targetYear',
        queryParameters: {'page': page, 'limit': 20},
      );

      final List results = response.data ?? [];
      return results
          .map((r) => _mapToMediaEntity(r, MediaType.tvShow, 'simkl', 'Simkl'))
          .toList();
    } catch (e) {
      Logger.error('Simkl seasonal TV failed', error: e);
      throw ServerException('Failed to get Simkl seasonal TV: $e');
    }
  }

  String _mapMediaTypeToSimkl(MediaType type) {
    switch (type) {
      case MediaType.anime:
        return 'anime';
      case MediaType.manga:
        return 'manga';
      case MediaType.movie:
        return 'movie';
      case MediaType.tvShow:
        return 'tv';
    }
  }

  MediaEntity _mapToMediaEntity(
    Map<String, dynamic> json,
    MediaType type,
    String sourceId,
    String sourceName,
  ) {
    final Map<String, dynamic> show = json['show'] ?? json;

    return MediaEntity(
      id: show['ids']['simkl']?.toString() ?? show['id']?.toString() ?? '',
      title: show['title'] ?? '',
      coverImage: show['poster'] != null
          ? 'https://simkl.in/shd/poster/${show['poster']}_original.jpg'
          : null,
      bannerImage: show['fanart'] != null
          ? 'https://simkl.in/shd/fanart/${show['fanart']}_original.jpg'
          : null,
      description: show['overview'],
      type: type,
      rating: (show['rating'] ?? 0) / 10.0,
      genres: List<String>.from(show['genres'] ?? []),
      status: _mapSimklStatus(show['status']),
      totalEpisodes: show['episodes'],
      totalChapters: null,
      sourceId: sourceId,
      sourceName: sourceName,
    );
  }

  MediaStatus _mapSimklStatus(String? status) {
    if (status == null) return MediaStatus.ongoing;
    switch (status.toLowerCase()) {
      case 'ended':
      case 'completed':
        return MediaStatus.completed;
      case 'returning':
      case 'continuing':
        return MediaStatus.ongoing;
      case 'upcoming':
      case 'planned':
        return MediaStatus.upcoming;
      default:
        return MediaStatus.ongoing;
    }
  }

  MediaDetailsEntity _mapToMediaDetailsEntity(
    Map<String, dynamic> json,
    MediaType type,
  ) {
    return MediaDetailsEntity(
      id: json['ids']['simkl']?.toString() ?? json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      englishTitle: json['title'],
      romajiTitle: null,
      nativeTitle: null,
      coverImage:
          json['images']?['poster'] ??
          (json['poster'] != null
              ? 'https://simkl.in/shd/poster/${json['poster']}_original.jpg'
              : null),
      bannerImage:
          json['images']?['fanart'] ??
          (json['fanart'] != null
              ? 'https://simkl.in/shd/fanart/${json['fanart']}_original.jpg'
              : null),
      description: json['overview'],
      type: type,
      status: _mapSimklStatus(json['status']),
      rating: (json['rating'] ?? 0) / 10.0,
      averageScore: json['rating'],
      popularity: null,
      favorites: null,
      genres: List<String>.from(json['genres'] ?? []),
      tags: [],
      startDate: json['year'] != null ? DateTime(json['year'], 1, 1) : null,
      endDate: json['year'] != null && json['status'] == 'ended'
          ? DateTime(json['year'], 12, 31)
          : null,
      episodes: json['episodes'],
      chapters: null,
      volumes: null,
      duration: null,
      season: null,
      seasonYear: json['year'],
      isAdult: false,
      siteUrl: json['ids']?['simkl'] != null
          ? 'https://simkl.com/${type.toString().split('.').last}/${json['ids']['simkl']}'
          : null,
      sourceId: 'simkl',
      sourceName: 'Simkl',
      characters: null,
      staff: null,
      reviews: null,
      recommendations: null,
      relations: null,
      studios: null,
      rankings: null,
      trailer: json['trailers']?['youtube'] != null
          ? TrailerEntity(
              id: json['trailers']['youtube']['video_id'] ?? '',
              site: 'youtube',
            )
          : null,
    );
  }
}
