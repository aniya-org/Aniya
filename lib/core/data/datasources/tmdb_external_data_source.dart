import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../domain/entities/media_entity.dart';
import '../../domain/entities/media_details_entity.dart';
import '../../domain/entities/search_result_entity.dart' as sr;
import '../../domain/entities/episode_entity.dart';
import '../../error/exceptions.dart';
import '../../utils/logger.dart';

class TmdbExternalDataSourceImpl {
  late final Dio _dio;
  late final String _apiKey;

  // Cache for season metadata (tvId -> season number -> metadata)
  static final Map<String, Map<int, Map<String, dynamic>>>
  _seasonMetadataCache = {};

  /// Get season metadata for a TV show
  static Map<int, Map<String, dynamic>>? getSeasonMetadata(String tvId) {
    return _seasonMetadataCache[tvId];
  }

  MediaDetailsEntity _mapToMediaDetails(
    Map<String, dynamic> data,
    String id,
    MediaType type, {
    required bool includeCharacters,
    required bool includeStaff,
    required bool includeReviews,
  }) {
    final isMovie = type == MediaType.movie;
    final title = isMovie ? (data['title'] ?? '') : (data['name'] ?? '');
    final englishTitle = isMovie
        ? data['original_title'] as String?
        : data['original_name'] as String?;
    final description = data['overview'] as String?;
    final coverImage = _getImageUrl(data['poster_path']) ?? '';
    final bannerImage = _getImageUrl(data['backdrop_path']);
    final startDateStr =
        (isMovie ? data['release_date'] : data['first_air_date']) as String?;
    final endDateStr = data['last_air_date'] as String?;
    final startDate = _parseDate(startDateStr);
    final endDate = _parseDate(endDateStr);
    final durationMinutes = isMovie
        ? data['runtime'] as int?
        : _extractEpisodeRuntime(data['episode_run_time']);
    final genres =
        (data['genres'] as List?)
            ?.map((g) => (g['name'] ?? '').toString())
            .where((name) => name.isNotEmpty)
            .toList() ??
        const [];
    final studios = (data['production_companies'] as List?)
        ?.map((company) {
          final idStr = company['id']?.toString();
          final name = company['name']?.toString();
          if (idStr == null || idStr.isEmpty || name == null || name.isEmpty) {
            return null;
          }
          return StudioEntity(
            id: idStr,
            name: name,
            isMain: company['primary'] == true,
            isAnimationStudio: false,
          );
        })
        .whereType<StudioEntity>()
        .toList();
    final credits = data['credits'] as Map<String, dynamic>?;
    final characters = includeCharacters
        ? _mapCreditsToCharacters(credits)
        : null;
    final staff = includeStaff ? _mapCreditsToStaff(credits) : null;
    final recommendations = _mapRecommendations(
      data['recommendations'] as Map<String, dynamic>?,
    );
    final relations = _mapSimilar(data['similar'] as Map<String, dynamic>?);
    final trailer = _mapTrailer(data['videos'] as Map<String, dynamic>?);

    return MediaDetailsEntity(
      id: id,
      title: title,
      englishTitle: englishTitle,
      romajiTitle: null,
      nativeTitle: null,
      coverImage: coverImage,
      bannerImage: bannerImage,
      description: description,
      type: type,
      status: _mapStatus(data['status'] as String?),
      rating: (data['vote_average'] as num?)?.toDouble(),
      averageScore: (data['vote_average'] as num?)?.round(),
      meanScore: null,
      popularity: (data['popularity'] as num?)?.round(),
      favorites: data['vote_count'] as int?,
      genres: genres,
      tags: const [],
      startDate: startDate,
      endDate: endDate,
      episodes: isMovie ? null : data['number_of_episodes'] as int?,
      chapters: null,
      volumes: null,
      duration: durationMinutes,
      season: null,
      seasonYear: startDate?.year,
      isAdult: data['adult'] == true,
      siteUrl: _buildSiteUrl(type, id),
      sourceId: 'tmdb',
      sourceName: 'TMDB',
      characters: characters,
      staff: staff,
      reviews: includeReviews ? const [] : null,
      recommendations: recommendations,
      relations: relations,
      studios: studios,
      rankings: null,
      trailer: trailer,
      dataSourceAttribution: null,
      contributingProviders: null,
      matchConfidences: null,
    );
  }

  int? _extractEpisodeRuntime(dynamic runtimeField) {
    if (runtimeField is List) {
      for (final value in runtimeField) {
        if (value is int && value > 0) {
          return value;
        }
      }
    }
    return null;
  }

  List<CharacterEntity>? _mapCreditsToCharacters(
    Map<String, dynamic>? credits,
  ) {
    final cast = credits?['cast'] as List?;
    if (cast == null || cast.isEmpty) return null;
    final mapped = cast
        .take(20)
        .map((entry) {
          final map = entry as Map<String, dynamic>;
          final id = map['id']?.toString();
          final name = map['name']?.toString();
          if (id == null || id.isEmpty || name == null || name.isEmpty) {
            return null;
          }
          return CharacterEntity(
            id: id,
            name: name,
            nativeName: null,
            image: _getImageUrl(map['profile_path']),
            role: map['character']?.toString() ?? 'Cast',
          );
        })
        .whereType<CharacterEntity>()
        .toList();
    return mapped.isEmpty ? null : mapped;
  }

  List<StaffEntity>? _mapCreditsToStaff(Map<String, dynamic>? credits) {
    final crew = credits?['crew'] as List?;
    if (crew == null || crew.isEmpty) return null;
    final mapped = crew
        .take(25)
        .map((entry) {
          final map = entry as Map<String, dynamic>;
          final id = map['id']?.toString();
          final name = map['name']?.toString();
          if (id == null || id.isEmpty || name == null || name.isEmpty) {
            return null;
          }
          return StaffEntity(
            id: id,
            name: name,
            nativeName: null,
            image: _getImageUrl(map['profile_path']),
            role: map['job']?.toString() ?? 'Crew',
          );
        })
        .whereType<StaffEntity>()
        .toList();
    return mapped.isEmpty ? null : mapped;
  }

  List<RecommendationEntity>? _mapRecommendations(
    Map<String, dynamic>? recommendations,
  ) {
    final results = recommendations?['results'] as List?;
    if (results == null || results.isEmpty) return null;
    final mapped = results
        .take(20)
        .map((item) {
          final map = item as Map<String, dynamic>;
          final mediaType =
              _mapTmdbMediaType(map['media_type']) ?? MediaType.tvShow;
          final title = mediaType == MediaType.movie
              ? (map['title'] ?? map['original_title'] ?? '')
              : (map['name'] ?? map['original_name'] ?? '');
          final id = map['id']?.toString();
          if (id == null || id.isEmpty || title.isEmpty) {
            return null;
          }
          return RecommendationEntity(
            id: id,
            title: title,
            englishTitle: map['original_title'] ?? map['original_name'],
            romajiTitle: null,
            coverImage: _getImageUrl(map['poster_path']) ?? '',
            rating: (map['vote_average'] as num?)?.round() ?? 0,
          );
        })
        .whereType<RecommendationEntity>()
        .toList();
    return mapped.isEmpty ? null : mapped;
  }

  List<MediaRelationEntity>? _mapSimilar(Map<String, dynamic>? similar) {
    final results = similar?['results'] as List?;
    if (results == null || results.isEmpty) return null;
    final mapped = results
        .take(20)
        .map((item) {
          final map = item as Map<String, dynamic>;
          final mediaType =
              _mapTmdbMediaType(map['media_type']) ?? MediaType.tvShow;
          final title = mediaType == MediaType.movie
              ? (map['title'] ?? map['original_title'] ?? '')
              : (map['name'] ?? map['original_name'] ?? '');
          final id = map['id']?.toString();
          if (id == null || id.isEmpty || title.isEmpty) {
            return null;
          }
          return MediaRelationEntity(
            relationType: 'SIMILAR',
            id: id,
            title: title,
            englishTitle: map['original_title'] ?? map['original_name'],
            romajiTitle: null,
            type: mediaType,
          );
        })
        .whereType<MediaRelationEntity>()
        .toList();
    return mapped.isEmpty ? null : mapped;
  }

  TrailerEntity? _mapTrailer(Map<String, dynamic>? videos) {
    final results = videos?['results'] as List?;
    if (results == null || results.isEmpty) return null;
    for (final entry in results) {
      final map = entry as Map<String, dynamic>;
      final type = map['type']?.toString().toLowerCase();
      final site = map['site']?.toString().toLowerCase();
      if (type == 'trailer' && site == 'youtube') {
        final key = map['key']?.toString();
        if (key != null && key.isNotEmpty) {
          return TrailerEntity(
            id: key,
            site: map['site']?.toString() ?? 'youtube',
          );
        }
      }
    }
    return null;
  }

  MediaStatus _mapStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'released':
      case 'ended':
      case 'canceled':
      case 'cancelled':
        return MediaStatus.completed;
      case 'in production':
      case 'returning series':
      case 'planned':
      case 'post production':
        return MediaStatus.ongoing;
      default:
        return MediaStatus.upcoming;
    }
  }

  MediaType? _mapTmdbMediaType(dynamic mediaType) {
    final type = mediaType?.toString().toLowerCase();
    switch (type) {
      case 'movie':
        return MediaType.movie;
      case 'tv':
        return MediaType.tvShow;
      default:
        return null;
    }
  }

  String _buildSiteUrl(MediaType type, String id) {
    final path = type == MediaType.movie ? 'movie' : 'tv';
    return 'https://www.themoviedb.org/$path/$id';
  }

  DateTime? _parseDate(String? date) {
    if (date == null || date.isEmpty) return null;
    return DateTime.tryParse(date);
  }

  Future<MediaDetailsEntity> getMediaDetails(
    String id,
    MediaType type, {
    bool includeCharacters = true,
    bool includeStaff = true,
    bool includeReviews = false,
  }) async {
    final effectiveType = type == MediaType.anime ? MediaType.tvShow : type;
    final endpoint = effectiveType == MediaType.movie
        ? '/movie/$id'
        : '/tv/$id';
    final appendResponses = <String>[];
    if (includeCharacters || includeStaff) {
      appendResponses.add('credits');
    }
    appendResponses.add('recommendations');
    appendResponses.add('similar');
    appendResponses.add('videos');

    try {
      await _enforceRateLimit();
      final response = await _dio.get(
        endpoint,
        queryParameters: {
          if (appendResponses.isNotEmpty)
            'append_to_response': appendResponses.join(','),
        },
      );

      final data = response.data as Map<String, dynamic>;
      return _mapToMediaDetails(
        data,
        id,
        effectiveType,
        includeCharacters: includeCharacters,
        includeStaff: includeStaff,
        includeReviews: includeReviews,
      );
    } catch (e, stackTrace) {
      Logger.error(
        'TMDB getMediaDetails failed for $id',
        tag: 'TmdbDataSource',
        error: e,
        stackTrace: stackTrace,
      );
      throw ServerException('Failed to fetch TMDB details: $e');
    }
  }

  // Rate limiting: ~35 requests per second (TMDB upper limit is ~40/sec)
  DateTime? _lastRequestTime;
  static const Duration _minRequestInterval = Duration(
    milliseconds: 29,
  ); // ~35 req/sec

  TmdbExternalDataSourceImpl() {
    _dio = Dio();
    _apiKey = dotenv.env['TMDB_API_KEY'] ?? '';
    if (_apiKey.isEmpty) {
      throw Exception('TMDB_API_KEY not found in .env');
    }
    _dio.options.baseUrl = 'https://api.themoviedb.org/3';
    _dio.options.queryParameters = {'api_key': _apiKey};
  }

  /// Ensure rate limit of ~35 requests per second
  Future<void> _enforceRateLimit() async {
    final now = DateTime.now();
    if (_lastRequestTime != null) {
      final timeSinceLastRequest = now.difference(_lastRequestTime!);
      if (timeSinceLastRequest < _minRequestInterval) {
        final waitTime = _minRequestInterval - timeSinceLastRequest;
        Logger.debug(
          'TMDB rate limiting: waiting ${waitTime.inMilliseconds}ms',
        );
        await Future.delayed(waitTime);
      }
    }
    _lastRequestTime = DateTime.now();
  }

  Future<sr.SearchResult<List<MediaEntity>>> searchMedia(
    String query,
    MediaType type, {
    int page = 1,
    int perPage = 20,
    List<String>? genres,
    int? year,
    String? season,
    String? status,
    String? format,
    int? minScore,
    int? maxScore,
    String? sort,
  }) async {
    try {
      Logger.info(
        'TMDB search: query="$query", type=$type, page=$page',
        tag: 'TmdbDataSource',
      );

      List<dynamic> results = [];
      int totalResults = 0;
      int totalPages = 1;

      // Map anime to TV shows for TMDB compatibility
      final searchType = type == MediaType.anime ? MediaType.tvShow : type;

      final queryParams = {'query': query, 'page': page};

      if (searchType == MediaType.movie) {
        if (year != null) {
          queryParams['year'] = year;
        }
        await _enforceRateLimit();
        final response = await _dio.get(
          '/search/movie',
          queryParameters: queryParams,
        );
        results = response.data['results'] ?? [];
        totalResults = response.data['total_results'] ?? 0;
        totalPages = response.data['total_pages'] ?? 1;
      } else if (searchType == MediaType.tvShow) {
        if (year != null) {
          queryParams['first_air_date_year'] = year;
        }
        await _enforceRateLimit();
        final response = await _dio.get(
          '/search/tv',
          queryParameters: queryParams,
        );
        results = response.data['results'] ?? [];
        totalResults = response.data['total_results'] ?? 0;
        totalPages = response.data['total_pages'] ?? 1;
      } else {
        Logger.debug(
          'TMDB does not support type: $type',
          tag: 'TmdbDataSource',
        );
        return sr.SearchResult<List<MediaEntity>>(
          items: [],
          totalCount: 0,
          currentPage: page,
          hasNextPage: false,
          perPage: perPage,
        );
      }

      final mappedResults = results
          .map((r) => _mapToMediaEntity(r, type, 'tmdb', 'TMDB'))
          .toList();

      Logger.info(
        'TMDB search completed: ${mappedResults.length} results',
        tag: 'TmdbDataSource',
      );

      return sr.SearchResult<List<MediaEntity>>(
        items: mappedResults,
        totalCount: totalResults,
        currentPage: page,
        hasNextPage: page < totalPages,
        perPage: perPage,
      );
    } catch (e, stackTrace) {
      Logger.error(
        'TMDB search failed',
        tag: 'TmdbDataSource',
        error: e,
        stackTrace: stackTrace,
      );
      throw ServerException('Failed to search TMDB: $e');
    }
  }

  Future<List<MediaEntity>> getTrending(MediaType type, {int page = 1}) async {
    try {
      String endpoint;
      // Map anime to TV shows for TMDB compatibility
      final searchType = type == MediaType.anime ? MediaType.tvShow : type;
      if (searchType == MediaType.movie) {
        endpoint = '/trending/movie/week';
      } else if (searchType == MediaType.tvShow) {
        endpoint = '/trending/tv/week';
      } else {
        return [];
      }
      await _enforceRateLimit();
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
      // Map anime to TV shows for TMDB compatibility
      final searchType = type == MediaType.anime ? MediaType.tvShow : type;
      if (searchType == MediaType.movie) {
        endpoint = '/movie/popular';
      } else if (searchType == MediaType.tvShow) {
        endpoint = '/tv/popular';
      } else {
        return [];
      }
      await _enforceRateLimit();
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
    final dateString = json['first_air_date'] ?? json['release_date'];
    DateTime? startDate;
    if (dateString is String && dateString.isNotEmpty) {
      startDate = DateTime.tryParse(dateString);
    }

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
      startDate: startDate,
      sourceId: sourceId,
      sourceName: sourceName,
    );
  }

  String? _getImageUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    return 'https://image.tmdb.org/t/p/w500$path';
  }

  /// Get all episodes for a TV show
  ///
  /// Fetches all episodes from all seasons of a TMDB TV show.
  /// This method is used for aggregating episodes from TMDB.
  Future<List<EpisodeEntity>> getEpisodes(
    String tvId, {
    String? coverImage,
  }) async {
    try {
      Logger.info(
        'Fetching episodes from TMDB for TV show ID: $tvId',
        tag: 'TmdbDataSource',
      );

      // First, get TV show details to find all seasons
      await _enforceRateLimit();
      final tvResponse = await _dio.get('/tv/$tvId');
      final tvData = tvResponse.data as Map<String, dynamic>;
      final seasons = tvData['seasons'] as List<dynamic>? ?? [];

      if (seasons.isEmpty) {
        Logger.warning('TMDB TV show $tvId has no seasons');
        return [];
      }

      // Fetch episodes from all seasons
      // Also collect season metadata (name, episode_count) for proper season inference
      final allEpisodes = <EpisodeEntity>[];
      final seasonMetadata = <int, Map<String, dynamic>>{};

      for (final season in seasons) {
        final seasonNumber = season['season_number'] as int?;
        if (seasonNumber == null || seasonNumber < 0) {
          // Skip special seasons (season 0 is usually specials)
          continue;
        }

        // Store season metadata (name and episode_count from TV show data)
        seasonMetadata[seasonNumber] = {
          'name': season['name'] as String?,
          'episode_count': season['episode_count'] as int?,
        };

        try {
          await _enforceRateLimit();
          final seasonResponse = await _dio.get(
            '/tv/$tvId/season/$seasonNumber',
          );
          final seasonData = seasonResponse.data as Map<String, dynamic>;
          final episodes = seasonData['episodes'] as List<dynamic>? ?? [];

          // Update episode_count with actual count from season details if available
          if (episodes.isNotEmpty) {
            seasonMetadata[seasonNumber]!['episode_count'] = episodes.length;
          }

          for (final ep in episodes) {
            final epNumber = ep['episode_number'] as int?;
            if (epNumber == null) continue;

            final stillPath = ep['still_path'] as String?;
            final thumbnail = stillPath != null
                ? 'https://image.tmdb.org/t/p/w500$stillPath'
                : null;

            allEpisodes.add(
              EpisodeEntity(
                id: '${tvId}_s${seasonNumber}_e$epNumber',
                mediaId: tvId,
                number:
                    epNumber, // Use episode number within season, not global
                seasonNumber: seasonNumber, // Include season number
                title: ep['name'] as String? ?? 'Episode $epNumber',
                thumbnail: thumbnail,
                duration: ep['runtime'] != null
                    ? (ep['runtime'] as int) *
                          60 // Convert minutes to seconds
                    : null,
                releaseDate: ep['air_date'] != null
                    ? DateTime.tryParse(ep['air_date'] as String)
                    : null,
                sourceProvider: 'tmdb',
              ),
            );
          }
        } catch (e) {
          Logger.warning(
            'Failed to fetch season $seasonNumber for TMDB TV show $tvId: $e',
            tag: 'TmdbDataSource',
          );
          // Continue with other seasons
        }
      }

      Logger.info(
        'TMDB returned ${allEpisodes.length} episodes for TV show $tvId across ${seasonMetadata.length} seasons',
        tag: 'TmdbDataSource',
      );

      // Store season metadata in episodes' alternativeData for later retrieval
      // We'll use a special key to store season metadata
      // Actually, we can't modify EpisodeEntity here easily, so we'll store it in a static map
      _seasonMetadataCache[tvId] = seasonMetadata;

      return allEpisodes;
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to fetch TMDB episodes for TV show $tvId',
        tag: 'TmdbDataSource',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }
}
