import 'package:dio/dio.dart';
import '../../domain/entities/media_entity.dart';
import '../../domain/entities/media_details_entity.dart' hide SearchResult;
import '../../domain/entities/episode_entity.dart';
import '../../domain/entities/chapter_entity.dart';
import '../../domain/entities/episode_page_result.dart';
import '../../domain/entities/search_result_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/tracking_auth_repository.dart';
import '../../enums/tracking_service.dart';
import '../../error/exceptions.dart';
import '../../utils/logger.dart';
import 'mal_external_data_source.dart';

class JikanExternalDataSourceImpl {
  late final Dio _dio;
  final TrackingAuthRepository? _authRepository;
  final MalExternalDataSourceImpl? _malDataSource;

  JikanExternalDataSourceImpl({
    TrackingAuthRepository? authRepository,
    MalExternalDataSourceImpl? malDataSource,
  }) : _authRepository = authRepository,
       _malDataSource = malDataSource ?? MalExternalDataSourceImpl() {
    _dio = Dio();
    _dio.options.baseUrl = 'https://api.jikan.moe/v4';
  }

  Future<EpisodePageResult> getEpisodePage({
    required String id,
    int offset = 0,
    int limit = 50,
    String? coverImage,
  }) async {
    final perPage = limit.clamp(1, 100);
    final pageNumber = (offset ~/ perPage) + 1;
    try {
      final response = await _dio.get(
        '/anime/$id/episodes',
        queryParameters: {'page': pageNumber, 'limit': perPage},
      );

      final List episodesList = response.data['data'] ?? [];
      final pagination = response.data['pagination'] as Map<String, dynamic>?;
      final hasNext = pagination?['has_next_page'] == true;
      final effectiveCover = await _ensureAnimeCoverImage(id, coverImage);

      final episodes = episodesList
          .map(
            (ep) => _mapEpisodeEntity(
              ep,
              animeId: id,
              fallbackCover: effectiveCover,
            ),
          )
          .toList();

      final nextOffset = hasNext ? offset + episodes.length : null;

      return EpisodePageResult(
        episodes: episodes,
        nextOffset: nextOffset,
        providerId: 'jikan',
        providerMediaId: id,
      );
    } catch (e) {
      Logger.error('Jikan getEpisodePage failed', error: e);
      throw ServerException('Failed to get paged episodes: $e');
    }
  }

  Future<String?> _ensureAnimeCoverImage(String id, String? existing) async {
    if (existing != null && existing.isNotEmpty) {
      Logger.info('Jikan using provided cover image for fallback: $existing');
      return existing;
    }

    try {
      final animeResponse = await _dio.get('/anime/$id');
      final animeData = animeResponse.data['data'];
      final cover =
          animeData?['images']?['jpg']?['large_image_url'] ??
          animeData?['images']?['jpg']?['image_url'];
      Logger.info('Jikan anime cover for fallback: $cover');
      await Future.delayed(const Duration(milliseconds: 400));
      return cover;
    } catch (e) {
      Logger.warning('Could not fetch anime cover for fallback: $e');
      return null;
    }
  }

  EpisodeEntity _mapEpisodeEntity(
    Map<String, dynamic> ep, {
    required String animeId,
    Map<int, String>? defaultThumbnail,
    String? fallbackCover,
  }) {
    final epNumber = ep['mal_id'] is int
        ? ep['mal_id']
        : int.tryParse(ep['mal_id'].toString()) ?? 0;
    final thumbnail = defaultThumbnail?[epNumber] ?? fallbackCover;

    return EpisodeEntity(
      id: ep['mal_id'].toString(),
      mediaId: animeId,
      number: epNumber,
      title: ep['title'] ?? 'Episode $epNumber',
      thumbnail: thumbnail,
      releaseDate: ep['aired'] != null
          ? DateTime.tryParse(ep['aired'].toString())
          : null,
    );
  }

  /// Advanced search with filtering and pagination (Jikan v4)
  Future<SearchResult<List<MediaEntity>>> searchMedia(
    String query,
    MediaType type, {
    List<String>? genres,
    int? minScore,
    int? maxScore,
    String? status,
    String? format,
    int? startDate,
    int? endDate,
    String? sort = 'desc',
    int page = 1,
    int perPage = 25,
    int? year,
    String? season,
  }) async {
    try {
      Logger.info(
        'Jikan search: query="$query", type=$type, page=$page',
        tag: 'JikanDataSource',
      );

      if (type != MediaType.anime && type != MediaType.manga) {
        Logger.debug(
          'Jikan does not support type: $type',
          tag: 'JikanDataSource',
        );
        return SearchResult<List<MediaEntity>>(
          items: [],
          totalCount: 0,
          currentPage: 1,
          hasNextPage: false,
          perPage: perPage,
        );
      }

      final endpoint = type == MediaType.anime ? 'anime' : 'manga';

      // Build query parameters
      final queryParams = <String, dynamic>{
        'q': query,
        'page': page,
        'limit': perPage,
      };

      // Add filtering
      if (genres != null && genres.isNotEmpty) {
        queryParams['genres'] = genres.join(',');
      }

      if (minScore != null && minScore > 0) {
        queryParams['min_score'] = minScore;
      }
      if (maxScore != null && maxScore < 10) {
        queryParams['max_score'] = maxScore;
      }

      if (status != null) {
        queryParams['status'] = status.toLowerCase();
      }

      if (format != null && type == MediaType.anime) {
        queryParams['type'] = format.toLowerCase();
      }

      // Jikan uses year ranges
      if (startDate != null) {
        queryParams['start_date'] = '${startDate}01';
      }
      if (endDate != null) {
        queryParams['end_date'] = '${endDate}12';
      }

      if (sort != null) {
        queryParams['order_by'] = 'score';
        queryParams['sort'] = sort;
      }

      final fullUrl = '${_dio.options.baseUrl}/$endpoint';
      Logger.debug(
        'Jikan API call: GET $fullUrl with params: $queryParams',
        tag: 'JikanDataSource',
      );

      final response = await _dio.get(
        '/$endpoint',
        queryParameters: queryParams,
      );

      Logger.debug(
        'Jikan API response status: ${response.statusCode}, data type: ${response.data.runtimeType}',
        tag: 'JikanDataSource',
      );

      if (response.data == null) {
        Logger.warning('Jikan API returned null data', tag: 'JikanDataSource');
        return SearchResult<List<MediaEntity>>(
          items: [],
          totalCount: 0,
          currentPage: page,
          hasNextPage: false,
          perPage: perPage,
        );
      }

      final responseData = response.data as Map<String, dynamic>?;
      if (responseData == null) {
        Logger.warning(
          'Jikan API response.data is not a Map',
          tag: 'JikanDataSource',
        );
        return SearchResult<List<MediaEntity>>(
          items: [],
          totalCount: 0,
          currentPage: page,
          hasNextPage: false,
          perPage: perPage,
        );
      }

      final List mediaList = responseData['data'] ?? [];
      final pagination = responseData['pagination'] ?? {};

      Logger.debug(
        'Jikan raw data count: ${mediaList.length}, pagination: $pagination',
        tag: 'JikanDataSource',
      );

      final results = mediaList.map((item) {
        return type == MediaType.anime
            ? _mapAnimeToMediaEntity(item)
            : _mapMangaToMediaEntity(item);
      }).toList();

      Logger.info(
        'Jikan search completed: ${results.length} results',
        tag: 'JikanDataSource',
      );

      return SearchResult<List<MediaEntity>>(
        items: results,
        totalCount: pagination?['items']?['total'] ?? 0,
        currentPage: page,
        hasNextPage: pagination?['has_next_page'] ?? false,
        perPage: perPage,
      );
    } catch (e, stackTrace) {
      Logger.error(
        'Jikan advanced search failed',
        tag: 'JikanDataSource',
        error: e,
        stackTrace: stackTrace,
      );
      throw ServerException('Failed to search Jikan: $e');
    }
  }

  /// Get media details with rich metadata
  Future<MediaDetailsEntity> getMediaDetails(
    String id,
    MediaType type, {
    bool includeCharacters = false,
    bool includeStaff = false,
    bool includeReviews = false,
  }) async {
    try {
      final endpoint = type == MediaType.anime ? 'anime' : 'manga';

      // Get main media details
      final response = await _dio.get('/$endpoint/$id');
      final media = response.data['data'];

      // Get additional data if requested
      List<CharacterEntity>? characters;
      List<StaffEntity>? staff;
      List<ReviewEntity>? reviews;
      List<RecommendationEntity>? recommendations;

      if (includeCharacters) {
        try {
          final charsResponse = await _dio.get('/$endpoint/$id/characters');
          final charsList = charsResponse.data['data'] ?? [];
          characters = (charsList as List).take(10).map<CharacterEntity>((
            char,
          ) {
            return CharacterEntity(
              id: char['character']?['mal_id'].toString() ?? '',
              name: char['character']?['name'] ?? '',
              nativeName: null,
              image: char['character']?['images']?['jpg']?['image_url'],
              role: char['role'] ?? 'Unknown',
            );
          }).toList();
        } catch (e) {
          Logger.error('Failed to load characters', error: e);
        }
      }

      if (includeReviews) {
        try {
          final reviewsResponse = await _dio.get('/$endpoint/$id/reviews');
          final reviewsList = reviewsResponse.data['data'] ?? [];
          reviews = (reviewsList as List).take(5).map<ReviewEntity>((review) {
            return ReviewEntity(
              id: review['mal_id'].toString(),
              score: (review['score'] ?? 0) is double
                  ? (review['score'] as double).toInt()
                  : review['score'] ?? 0,
              summary: null,
              body: review['review'],
              user: UserEntity(
                id: review['user']['user_id'].toString(),
                username: review['user']['username'] ?? '',
                avatarUrl: review['user']['images']?['jpg']?['image_url'],
                service: TrackingService.mal,
              ),
            );
          }).toList();
        } catch (e) {
          Logger.error('Failed to load reviews', error: e);
        }
      }

      // Get recommendations
      try {
        final recResponse = await _dio.get('/$endpoint/$id/recommendations');
        final recList = recResponse.data['data'] ?? [];
        recommendations = (recList as List).take(10).map<RecommendationEntity>((
          rec,
        ) {
          final entry = rec['entry'];
          return RecommendationEntity(
            id: entry['mal_id'].toString(),
            title: entry['title'] ?? '',
            englishTitle: null,
            romajiTitle: null,
            coverImage: entry['images']?['jpg']?['image_url'] ?? '',
            rating: 0, // Jikan doesn't provide this
          );
        }).toList();
      } catch (e) {
        Logger.error('Failed to load recommendations', error: e);
      }

      return type == MediaType.anime
          ? _mapAnimeToMediaDetailsEntity(
              media,
              characters,
              staff,
              reviews,
              recommendations,
            )
          : _mapMangaToMediaDetailsEntity(
              media,
              characters,
              staff,
              reviews,
              recommendations,
            );
    } catch (e) {
      Logger.error('Jikan get details failed', error: e);
      throw ServerException('Failed to get Jikan details: $e');
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

  /// Enhanced trending/popular with filtering
  Future<List<MediaEntity>> getTrending(
    MediaType type, {
    int page = 1,
    String? subtype = 'airing',
  }) async {
    try {
      if (type == MediaType.anime) {
        final response = await _dio.get(
          '/top/anime',
          queryParameters: {
            'type': subtype == 'airing' ? 'tv' : subtype,
            'filter': 'airing',
            'page': page,
            'limit': 25,
          },
        );
        final List topList = response.data['data'] ?? [];

        // Batch load details for better data quality
        final results = <MediaEntity>[];
        for (var top in topList.take(10)) {
          try {
            final detailResponse = await _dio.get('/anime/${top['mal_id']}');
            final media = detailResponse.data['data'];
            results.add(_mapAnimeToMediaEntity(media));
          } catch (e) {
            // Fallback to top list data
            results.add(_mapTopAnimeToMediaEntity(top));
          }
          await Future.delayed(
            const Duration(milliseconds: 100),
          ); // Rate limiting
        }
        return results;
      } else if (type == MediaType.manga) {
        final response = await _dio.get(
          '/top/manga',
          queryParameters: {'page': page, 'limit': 25},
        );
        final List topList = response.data['data'] ?? [];

        final results = <MediaEntity>[];
        for (var top in topList.take(10)) {
          try {
            final detailResponse = await _dio.get('/manga/${top['mal_id']}');
            final media = detailResponse.data['data'];
            results.add(_mapMangaToMediaEntity(media));
          } catch (e) {
            results.add(_mapTopMangaToMediaEntity(top));
          }
          await Future.delayed(const Duration(milliseconds: 100));
        }
        return results;
      } else {
        return [];
      }
    } catch (e) {
      Logger.error('Jikan trending failed', error: e);
      throw ServerException('Failed to get Jikan trending: $e');
    }
  }

  Future<List<MediaEntity>> getPopular(MediaType type, {int page = 1}) async {
    try {
      if (type == MediaType.anime) {
        final response = await _dio.get(
          '/top/anime',
          queryParameters: {
            'filter': 'bypopularity',
            'page': page,
            'limit': 25,
          },
        );
        final List topList = response.data['data'] ?? [];

        final results = <MediaEntity>[];
        for (var top in topList.take(10)) {
          try {
            final detailResponse = await _dio.get('/anime/${top['mal_id']}');
            final media = detailResponse.data['data'];
            results.add(_mapAnimeToMediaEntity(media));
          } catch (e) {
            results.add(_mapTopAnimeToMediaEntity(top));
          }
          await Future.delayed(const Duration(milliseconds: 100));
        }
        return results;
      } else if (type == MediaType.manga) {
        final response = await _dio.get(
          '/top/manga',
          queryParameters: {
            'filter': 'bypopularity',
            'page': page,
            'limit': 25,
          },
        );
        final List topList = response.data['data'] ?? [];

        final results = <MediaEntity>[];
        for (var top in topList.take(10)) {
          try {
            final detailResponse = await _dio.get('/manga/${top['mal_id']}');
            final media = detailResponse.data['data'];
            results.add(_mapMangaToMediaEntity(media));
          } catch (e) {
            results.add(_mapTopMangaToMediaEntity(top));
          }
          await Future.delayed(const Duration(milliseconds: 100));
        }
        return results;
      } else {
        return [];
      }
    } catch (e) {
      Logger.error('Jikan popular failed', error: e);
      throw ServerException('Failed to get Jikan popular: $e');
    }
  }

  /// Get seasonal anime
  Future<List<MediaEntity>> getSeasonalAnime({
    int? year,
    String? season,
    int page = 1,
  }) async {
    try {
      final now = DateTime.now();
      final seasonYear = year ?? now.year;
      final seasonName = season ?? _getCurrentSeason();

      final response = await _dio.get(
        '/seasons/$seasonYear/$seasonName',
        queryParameters: {'page': page, 'limit': 24},
      );

      final List mediaList = response.data['data'] ?? [];
      return mediaList.map((anime) => _mapAnimeToMediaEntity(anime)).toList();
    } catch (e) {
      Logger.error('Jikan seasonal failed', error: e);
      throw ServerException('Failed to get Jikan seasonal: $e');
    }
  }

  String _getCurrentSeason() {
    final month = DateTime.now().month;
    if (month >= 1 && month <= 3) return 'winter';
    if (month >= 4 && month <= 6) return 'spring';
    if (month >= 7 && month <= 9) return 'summer';
    return 'fall';
  }

  MediaEntity _mapAnimeToMediaEntity(Map<String, dynamic> anime) {
    return MediaEntity(
      id: anime['mal_id'].toString(),
      title: anime['title'] ?? '',
      coverImage: anime['images']?['jpg']?['image_url'],
      bannerImage: null,
      description: anime['synopsis'],
      type: MediaType.anime,
      rating: (anime['score'] ?? 0).toDouble(),
      genres: List<String>.from(anime['genres']?.map((g) => g['name']) ?? []),
      status: _mapJikanStatus(anime['status']),
      totalEpisodes: anime['episodes'],
      totalChapters: null,
      sourceId: 'jikan',
      sourceName: 'Jikan',
    );
  }

  MediaEntity _mapMangaToMediaEntity(Map<String, dynamic> manga) {
    return MediaEntity(
      id: manga['mal_id'].toString(),
      title: manga['title'] ?? '',
      coverImage: manga['images']?['jpg']?['image_url'],
      bannerImage: null,
      description: manga['synopsis'],
      type: MediaType.manga,
      rating: (manga['score'] ?? 0).toDouble(),
      genres: List<String>.from(manga['genres']?.map((g) => g['name']) ?? []),
      status: _mapJikanStatus(manga['status']),
      totalEpisodes: null,
      totalChapters: manga['chapters'],
      sourceId: 'jikan',
      sourceName: 'Jikan',
    );
  }

  MediaEntity _mapTopAnimeToMediaEntity(Map<String, dynamic> top) {
    return MediaEntity(
      id: top['mal_id'].toString(),
      title: top['title'] ?? '',
      coverImage: top['images']?['jpg']?['image_url'],
      bannerImage: null,
      description: null,
      type: MediaType.anime,
      rating: (top['score'] ?? 0).toDouble(),
      genres: [],
      status: MediaStatus.ongoing,
      totalEpisodes: null,
      totalChapters: null,
      sourceId: 'jikan',
      sourceName: 'Jikan',
    );
  }

  MediaEntity _mapTopMangaToMediaEntity(Map<String, dynamic> top) {
    return MediaEntity(
      id: top['mal_id'].toString(),
      title: top['title'] ?? '',
      coverImage: top['images']?['jpg']?['image_url'],
      bannerImage: null,
      description: null,
      type: MediaType.manga,
      rating: (top['score'] ?? 0).toDouble(),
      genres: [],
      status: MediaStatus.ongoing,
      totalEpisodes: null,
      totalChapters: null,
      sourceId: 'jikan',
      sourceName: 'Jikan',
    );
  }

  MediaDetailsEntity _mapAnimeToMediaDetailsEntity(
    Map<String, dynamic> anime,
    List<CharacterEntity>? characters,
    List<StaffEntity>? staff,
    List<ReviewEntity>? reviews,
    List<RecommendationEntity>? recommendations,
  ) {
    // Parse dates
    DateTime? startDate;
    DateTime? endDate;
    try {
      if (anime['aired']?['from'] != null) {
        startDate = DateTime.parse(anime['aired']['from']);
      }
      if (anime['aired']?['to'] != null &&
          anime['aired']['to'] != "0000-00-00T00:00:00+00:00") {
        endDate = DateTime.parse(anime['aired']['to']);
      }
    } catch (e) {
      // Invalid dates
    }

    // Safe type conversion for numeric fields
    int? safeToInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    // Parse producers as studios
    final studios = anime['producers'] != null
        ? (anime['producers'] as List).map((producer) {
            return StudioEntity(
              id: producer['mal_id'].toString(),
              name: producer['name'] ?? '',
              isMain: false,
              isAnimationStudio: true,
            );
          }).toList()
        : null;

    // Parse duration - handle various formats like "24 min per ep", "1 hr 30 min"
    int? parseDuration(String? durationStr) {
      if (durationStr == null) return null;
      final parts = durationStr.toLowerCase().split(' ');
      int totalMinutes = 0;
      for (int i = 0; i < parts.length - 1; i++) {
        final num = int.tryParse(parts[i]);
        if (num != null) {
          if (parts[i + 1].startsWith('hr')) {
            totalMinutes += num * 60;
          } else if (parts[i + 1].startsWith('min')) {
            totalMinutes += num;
          }
        }
      }
      return totalMinutes > 0 ? totalMinutes : int.tryParse(parts[0]);
    }

    return MediaDetailsEntity(
      id: anime['mal_id'].toString(),
      title: anime['title'] ?? '',
      englishTitle: anime['title_english'],
      romajiTitle: null, // Jikan doesn't provide this
      nativeTitle: null,
      coverImage:
          anime['images']?['jpg']?['large_image_url'] ??
          anime['images']?['jpg']?['image_url'] ??
          '',
      bannerImage: null,
      description: anime['synopsis'],
      type: MediaType.anime,
      status: _mapJikanStatus(anime['status']),
      rating: (anime['score'] ?? 0).toDouble(),
      averageScore: safeToInt(anime['score']),
      popularity: safeToInt(anime['members']),
      favorites: safeToInt(anime['favorites']),
      genres: List<String>.from(anime['genres']?.map((g) => g['name']) ?? []),
      tags: [],
      startDate: startDate,
      endDate: endDate,
      episodes: safeToInt(anime['episodes']),
      chapters: null,
      volumes: null,
      duration: parseDuration(anime['duration']),
      season: anime['season'],
      seasonYear: safeToInt(anime['year']),
      isAdult: anime['rating'] == 'Rx',
      siteUrl: anime['url'],
      sourceId: 'jikan',
      sourceName: 'Jikan',
      characters: characters,
      staff: staff,
      reviews: reviews,
      recommendations: recommendations,
      relations: null, // Jikan doesn't provide this easily
      studios: studios,
      rankings: null, // Would need to fetch separately
      trailer: anime['trailer']?['url'] != null
          ? TrailerEntity(id: anime['trailer']['url'] ?? '', site: 'youtube')
          : null,
    );
  }

  MediaDetailsEntity _mapMangaToMediaDetailsEntity(
    Map<String, dynamic> manga,
    List<CharacterEntity>? characters,
    List<StaffEntity>? staff,
    List<ReviewEntity>? reviews,
    List<RecommendationEntity>? recommendations,
  ) {
    // Parse dates
    DateTime? startDate;
    DateTime? endDate;
    try {
      if (manga['published']?['from'] != null) {
        startDate = DateTime.parse(manga['published']['from']);
      }
      if (manga['published']?['to'] != null &&
          manga['published']['to'] != "0000-00-00T00:00:00+00:00") {
        endDate = DateTime.parse(manga['published']['to']);
      }
    } catch (e) {
      // Invalid dates
    }

    // Safe type conversion for numeric fields
    int? safeToInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    return MediaDetailsEntity(
      id: manga['mal_id'].toString(),
      title: manga['title'] ?? '',
      englishTitle: manga['title_english'],
      romajiTitle: null,
      nativeTitle: null,
      coverImage:
          manga['images']?['jpg']?['large_image_url'] ??
          manga['images']?['jpg']?['image_url'] ??
          '',
      bannerImage: null,
      description: manga['synopsis'],
      type: MediaType.manga,
      status: _mapJikanStatus(manga['status']),
      rating: (manga['score'] ?? 0).toDouble(),
      averageScore: safeToInt(manga['score']),
      popularity: safeToInt(manga['members']),
      favorites: safeToInt(manga['favorites']),
      genres: List<String>.from(manga['genres']?.map((g) => g['name']) ?? []),
      tags: [],
      startDate: startDate,
      endDate: endDate,
      episodes: null,
      chapters: safeToInt(manga['chapters']),
      volumes: safeToInt(manga['volumes']),
      duration: null,
      season: null,
      seasonYear: safeToInt(manga['year']),
      isAdult: false, // Jikan doesn't provide NSFW for manga easily
      siteUrl: manga['url'],
      sourceId: 'jikan',
      sourceName: 'Jikan',
      characters: characters,
      staff: staff,
      reviews: reviews,
      recommendations: recommendations,
      relations: null,
      studios: null, // Jikan doesn't provide manga studios
      rankings: null,
      trailer: null,
    );
  }

  MediaStatus _mapJikanStatus(String? status) {
    if (status == null) return MediaStatus.ongoing;
    switch (status.toLowerCase()) {
      case 'finished':
      case 'completed':
        return MediaStatus.completed;
      case 'currently airing':
      case 'publishing':
        return MediaStatus.ongoing;
      case 'not yet aired':
      case 'not yet published':
        return MediaStatus.upcoming;
      default:
        return MediaStatus.ongoing;
    }
  }

  Future<List<EpisodeEntity>> getEpisodes(
    String id, {
    String? coverImage,
  }) async {
    try {
      Map<int, String> episodeImages = {};
      String? animeCoverImage = await _ensureAnimeCoverImage(id, coverImage);

      // Get basic episode info
      List episodesList = [];
      try {
        final response = await _dio.get('/anime/$id/episodes');
        episodesList = response.data['data'] ?? [];
      } catch (e) {
        Logger.warning('Jikan episodes endpoint failed for anime $id: $e');
        // Return empty list - other providers may have episodes
        return [];
      }

      // Add delay before videos/episodes call to avoid rate limiting
      await Future.delayed(const Duration(milliseconds: 400));
      try {
        final videosResponse = await _dio.get('/anime/$id/videos/episodes');
        final List videoEpisodes = videosResponse.data['data'] ?? [];
        Logger.info(
          'Jikan videos/episodes returned ${videoEpisodes.length} episodes for anime $id',
        );

        // Log the first episode structure for debugging
        if (videoEpisodes.isNotEmpty) {
          Logger.debug(
            'Jikan episode structure sample: ${videoEpisodes.first}',
          );
        }

        for (final ep in videoEpisodes) {
          final epNum = ep['mal_id'];
          final images = ep['images'];
          if (epNum != null && images != null) {
            // Try different image paths
            final imageUrl =
                images['jpg']?['image_url'] ??
                images['webp']?['image_url'] ??
                images['webp']?['small_image_url'];
            if (imageUrl != null) {
              final epNumInt = epNum is int
                  ? epNum
                  : int.tryParse(epNum.toString()) ?? 0;
              episodeImages[epNumInt] = imageUrl;
              Logger.debug('Jikan episode $epNumInt has image: $imageUrl');
            }
          }
        }
        Logger.info(
          'Jikan found ${episodeImages.length} episode images for anime $id',
        );
      } catch (e) {
        // Videos endpoint might not be available for all anime
        Logger.info('No episode images available for anime $id: $e');
      }

      final episodes = episodesList
          .map(
            (ep) => _mapEpisodeEntity(
              ep,
              animeId: id,
              defaultThumbnail: episodeImages,
              fallbackCover: animeCoverImage,
            ),
          )
          .toList();

      // Log thumbnail assignment summary
      final episodesWithThumbnails = episodes
          .where((e) => e.thumbnail != null && e.thumbnail!.isNotEmpty)
          .length;
      Logger.info(
        'Jikan returning ${episodes.length} episodes, $episodesWithThumbnails with thumbnails (fallback cover: ${animeCoverImage != null})',
      );
      if (episodes.isNotEmpty && episodes.first.thumbnail != null) {
        Logger.debug(
          'Jikan first episode thumbnail: ${episodes.first.thumbnail}',
        );
      }

      return episodes;
    } catch (e) {
      Logger.error('Jikan get episodes failed', error: e);
      return [];
    }
  }

  /// Get chapters for a manga
  /// Note: MAL/Jikan doesn't provide chapter-level data via API.
  /// We generate placeholder chapters based on the manga's chapter count.
  ///
  /// If Jikan doesn't have chapter count, we fall back to MAL's official API
  /// which requires user authentication.
  Future<List<ChapterEntity>> getChapters(String id) async {
    try {
      // Fetch manga details to get chapter count
      final response = await _dio.get('/manga/$id');
      final manga = response.data['data'];
      int? totalChapters = manga['chapters'] as int?;

      // If Jikan doesn't have chapter count, try MAL API fallback
      if ((totalChapters == null || totalChapters <= 0) &&
          _authRepository != null &&
          _malDataSource != null) {
        Logger.info(
          'Jikan manga $id has no chapter count, attempting MAL fallback',
          tag: 'JikanDataSource',
        );

        try {
          totalChapters = await _tryMalChapterFallback(id);
        } on MalAuthRequiredException {
          // Bubble up so UI can prompt for authentication
          rethrow;
        }
      }

      if (totalChapters == null || totalChapters <= 0) {
        Logger.info(
          'No chapter count available for manga $id after all fallbacks',
          tag: 'JikanDataSource',
        );
        return [];
      }

      Logger.info(
        'Generating $totalChapters placeholder chapters for manga $id',
        tag: 'JikanDataSource',
      );

      // Generate placeholder chapters
      return List.generate(totalChapters, (index) {
        final chapterNum = index + 1;
        return ChapterEntity(
          id: 'jikan_chapter_${id}_$chapterNum',
          mediaId: id,
          number: chapterNum.toDouble(),
          title: 'Chapter $chapterNum',
          releaseDate: null,
          pageCount: null,
          sourceProvider: 'jikan',
        );
      });
    } on MalAuthRequiredException {
      rethrow;
    } catch (e) {
      Logger.error('Jikan get chapters failed', error: e);
      return [];
    }
  }

  /// Try to get chapter count from MAL's official API.
  ///
  /// This requires a valid MAL access token. If no token is available
  /// or the request fails, returns null.
  Future<int?> _tryMalChapterFallback(String malId) async {
    try {
      // Get valid MAL token
      final token = await _authRepository?.getValidToken(TrackingService.mal);

      if (token == null) {
        Logger.info(
          'No MAL token available for chapter fallback',
          tag: 'JikanDataSource',
        );
        throw const MalAuthRequiredException();
      }

      Logger.info(
        'Using MAL API fallback for manga $malId chapter count',
        tag: 'JikanDataSource',
      );

      final chapterCount = await _malDataSource?.getChapterCount(malId, token);

      if (chapterCount != null && chapterCount > 0) {
        Logger.info(
          'MAL fallback returned $chapterCount chapters for manga $malId',
          tag: 'JikanDataSource',
        );
      }

      return chapterCount;
    } on MalAuthRequiredException {
      rethrow;
    } on MalAuthExpiredException {
      Logger.warning(
        'MAL token expired during chapter fallback for manga $malId',
        tag: 'JikanDataSource',
      );
      return null;
    } on RateLimitException catch (e) {
      Logger.warning(
        'MAL rate limited during chapter fallback: ${e.message}',
        tag: 'JikanDataSource',
      );
      return null;
    } catch (e) {
      Logger.warning(
        'MAL fallback failed for manga $malId: $e',
        tag: 'JikanDataSource',
      );
      return null;
    }
  }
}
