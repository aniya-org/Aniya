import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../domain/entities/entities.dart';
import '../../error/exceptions.dart';
import '../../utils/logger.dart';

class SimklExternalDataSourceImpl {
  late final Dio _dio;
  late final String? _clientId;

  // Rate limiting: 1 request per second (conservative limit)
  DateTime? _lastRequestTime;
  static const Duration _minRequestInterval = Duration(seconds: 1);

  SimklExternalDataSourceImpl() {
    _dio = Dio();
    _clientId = dotenv.env['SIMKL_CLIENT_ID'];
    _dio.options.baseUrl = 'https://api.simkl.com';
    if (_clientId != null) {
      _dio.options.queryParameters = {'client_id': _clientId};
    }
  }

  /// Ensure rate limit of 1 request per second
  Future<void> _enforceRateLimit() async {
    final now = DateTime.now();
    if (_lastRequestTime != null) {
      final timeSinceLastRequest = now.difference(_lastRequestTime!);
      if (timeSinceLastRequest < _minRequestInterval) {
        final waitTime = _minRequestInterval - timeSinceLastRequest;
        Logger.debug(
          'Simkl rate limiting: waiting ${waitTime.inMilliseconds}ms',
        );
        await Future.delayed(waitTime);
      }
    }
    _lastRequestTime = DateTime.now();
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

      await _enforceRateLimit();
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

      // Simkl has limited character/staff/review data
      // Characters, staff, and reviews are not available in Simkl yet

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

  /// Enhanced trending with filtering
  /// Note: Simkl doesn't have a dedicated trending endpoint, so we use search with sorting
  Future<List<MediaEntity>> getTrending(
    MediaType type, {
    int page = 1,
    String? format,
  }) async {
    try {
      final String simklType = _mapMediaTypeToSimkl(type);
      final queryParams = <String, dynamic>{
        'q': '', // Empty query to get all results
        'limit': 20,
        'page': page,
        'extended': 'full',
      };

      if (format != null) {
        queryParams['type'] = format.toLowerCase();
      }

      // Use the search endpoint with empty query to get all items, sorted by relevance/popularity
      final response = await _dio.get(
        '/search/$simklType',
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

  /// Get popular media
  /// Note: Simkl doesn't have dedicated popular/trending endpoints
  /// We use the search endpoint with appropriate parameters
  Future<List<MediaEntity>> getPopular(MediaType type, {int page = 1}) async {
    try {
      final String simklType = _mapMediaTypeToSimkl(type);

      // Use search with empty query and extended info to get popular items
      final response = await _dio.get(
        '/search/$simklType',
        queryParameters: {
          'q': '', // Empty query to get all results
          'limit': 20,
          'page': page,
          'extended': 'full',
        },
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
      // Filter by season if specified
      final filtered = season != null
          ? results.where((item) {
              final itemSeason = item['season_number'] ?? item['season'];
              return itemSeason ==
                  (season.toLowerCase() == 'winter'
                      ? 1
                      : season.toLowerCase() == 'spring'
                      ? 2
                      : season.toLowerCase() == 'summer'
                      ? 3
                      : 4);
            }).toList()
          : results;

      return filtered
          .map((r) => _mapToMediaEntity(r, MediaType.tvShow, 'simkl', 'Simkl'))
          .toList();
    } catch (e) {
      Logger.error('Simkl seasonal TV failed', error: e);
      throw ServerException('Failed to get Simkl seasonal TV: $e');
    }
  }

  /// Get movies by year
  Future<List<MediaEntity>> getMoviesByYear({int? year, int page = 1}) async {
    try {
      final targetYear = year ?? DateTime.now().year;

      final response = await _dio.get(
        '/search/movies',
        queryParameters: {
          'q': targetYear.toString(),
          'type': 'movie',
          'year': targetYear,
          'page': page,
          'limit': 20,
        },
      );

      final List results = response.data ?? [];
      return results
          .map((r) => _mapToMediaEntity(r, MediaType.movie, 'simkl', 'Simkl'))
          .toList();
    } catch (e) {
      Logger.error('Simkl movies by year failed', error: e);
      throw ServerException('Failed to get Simkl movies by year: $e');
    }
  }

  String _mapMediaTypeToSimkl(MediaType type) {
    switch (type) {
      case MediaType.anime:
        return 'anime';
      case MediaType.manga:
        return 'manga';
      case MediaType.novel:
        return 'manga'; // Simkl doesn't have separate novel type
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
      totalChapters: null, // Simkl doesn't have manga chapters
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
    // Simkl has less detailed metadata than Jikan/AniList
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
      popularity: null, // Simkl doesn't provide popularity numbers
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
      isAdult: false, // Simkl doesn't flag adult content explicitly
      siteUrl: json['ids']?['simkl'] != null
          ? 'https://simkl.com/${type.toString().split('.').last}/${json['ids']['simkl']}'
          : null,
      sourceId: 'simkl',
      sourceName: 'Simkl',
      characters: null, // Not available in Simkl
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
