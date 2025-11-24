import 'package:dio/dio.dart';
import '../../domain/entities/entities.dart';
import '../../error/exceptions.dart';
import '../../utils/logger.dart';

class JikanExternalDataSourceImpl {
  late final Dio _dio;

  JikanExternalDataSourceImpl() {
    _dio = Dio();
    _dio.options.baseUrl = 'https://api.jikan.moe/v4';
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
  }) async {
    try {
      if (type != MediaType.anime && type != MediaType.manga) {
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

      final response = await _dio.get(
        '/$endpoint',
        queryParameters: queryParams,
      );

      final List mediaList = response.data['data'] ?? [];
      final pagination = response.data['pagination'] ?? {};

      final results = mediaList.map((item) {
        return type == MediaType.anime
            ? _mapAnimeToMediaEntity(item)
            : _mapMangaToMediaEntity(item);
      }).toList();

      return SearchResult<List<MediaEntity>>(
        items: results,
        totalCount: pagination?['items']?['total'] ?? 0,
        currentPage: page,
        hasNextPage: pagination?['has_next_page'] ?? false,
        perPage: perPage,
      );
    } catch (e) {
      Logger.error('Jikan advanced search failed', error: e);
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
          characters = charsList.take(10).map((char) {
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
          reviews = reviewsList.take(5).map((review) {
            return ReviewEntity(
              id: review['mal_id'].toString(),
              score: review['score'] ?? 0,
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
        recommendations = recList.take(10).map((rec) {
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
      averageScore: anime['score'],
      popularity: anime['members'],
      favorites: anime['favorites'],
      genres: List<String>.from(anime['genres']?.map((g) => g['name']) ?? []),
      tags: [],
      startDate: startDate,
      endDate: endDate,
      episodes: anime['episodes'],
      chapters: null,
      volumes: null,
      duration: anime['duration'] != null
          ? int.tryParse(anime['duration'].split(' ')[0])
          : null,
      season: anime['season'],
      seasonYear: anime['year'],
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
      averageScore: manga['score'],
      popularity: manga['members'],
      favorites: manga['favorites'],
      genres: List<String>.from(manga['genres']?.map((g) => g['name']) ?? []),
      tags: [],
      startDate: startDate,
      endDate: endDate,
      episodes: null,
      chapters: manga['chapters'],
      volumes: manga['volumes'],
      duration: null,
      season: null,
      seasonYear: manga['year'],
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

  Future<List<EpisodeEntity>> getEpisodes(String id) async {
    try {
      final response = await _dio.get('/anime/$id/episodes');
      final List episodesList = response.data['data'] ?? [];
      // final pagination = response.data['pagination']; // Unused

      return episodesList.map((ep) {
        return EpisodeEntity(
          id: ep['mal_id'].toString(),
          mediaId: id,
          number: ep['mal_id'] is int
              ? ep['mal_id']
              : int.tryParse(ep['mal_id'].toString()) ?? 0,
          title: ep['title'] ?? 'Episode ${ep['mal_id']}',
          thumbnail: null,
          releaseDate: ep['aired'] != null
              ? DateTime.tryParse(ep['aired'])
              : null,
        );
      }).toList();
    } catch (e) {
      Logger.error('Jikan get episodes failed', error: e);
      return [];
    }
  }
}
