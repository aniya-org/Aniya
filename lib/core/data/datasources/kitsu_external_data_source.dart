import 'package:dio/dio.dart';
import '../../domain/entities/entities.dart';
import '../../error/exceptions.dart';
import '../../utils/logger.dart';

class KitsuExternalDataSourceImpl {
  late final Dio _dio;

  KitsuExternalDataSourceImpl() {
    _dio = Dio();
    _dio.options.baseUrl = 'https://kitsu.io/api/edge';
    _dio.options.headers = {
      'Accept': 'application/vnd.api+json',
      'Content-Type': 'application/vnd.api+json',
    };
  }

  /// Advanced search with filtering and pagination (Kitsu JSON:API)
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
    String? sort = 'popularityRank',
    int page = 1,
    int perPage = 20,
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
        'filter[text]': query,
        'page[limit]': perPage,
        'page[offset]': (page - 1) * perPage,
      };

      if (sort != null) {
        queryParams['sort'] = sort;
      }

      final response = await _dio.get(
        '/$endpoint',
        queryParameters: queryParams,
      );

      final List mediaList = response.data['data'] ?? [];
      final meta = response.data['meta'] ?? {};
      final totalCount = meta['count'] ?? 0;

      final results = mediaList
          .map((item) => _mapToMediaEntity(item, type, 'kitsu', 'Kitsu'))
          .toList();

      return SearchResult<List<MediaEntity>>(
        items: results,
        totalCount: totalCount,
        currentPage: page,
        hasNextPage: mediaList.length == perPage,
        perPage: perPage,
      );
    } catch (e) {
      Logger.error('Kitsu search failed', error: e);
      throw ServerException('Failed to search Kitsu: $e');
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

      // Get main media details with optional includes
      final includes = <String>[];
      if (includeCharacters) includes.add('characters');
      if (type == MediaType.anime) includes.add('animeStaff');

      final includeParam = includes.isNotEmpty ? includes.join(',') : null;

      final response = await _dio.get(
        '/$endpoint/$id',
        queryParameters: includeParam != null
            ? {'include': includeParam}
            : null,
      );

      final media = response.data['data'];
      final included = response.data['included'] ?? [];

      // Parse characters from included
      List<CharacterEntity>? characters;
      if (includeCharacters && included.isNotEmpty) {
        characters = included
            .where((item) => item['type'] == 'characters')
            .take(10)
            .map((char) {
              final attrs = char['attributes'] ?? {};
              return CharacterEntity(
                id: char['id']?.toString() ?? '',
                name: attrs['name'] ?? attrs['canonicalName'] ?? '',
                nativeName: null,
                image: attrs['image']?['original'],
                role: 'Unknown',
              );
            })
            .toList();
      }

      return type == MediaType.anime
          ? _mapToAnimeDetailsEntity(media, characters, null, null, null)
          : _mapToMangaDetailsEntity(media, characters, null, null, null);
    } catch (e) {
      Logger.error('Kitsu get details failed', error: e);
      throw ServerException('Failed to get Kitsu details: $e');
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

  /// Get trending anime/manga
  Future<List<MediaEntity>> getTrending(MediaType type, {int page = 1}) async {
    try {
      final response = await _dio.get(
        '/${type == MediaType.anime ? 'anime' : 'manga'}/trending',
        queryParameters: {'page[limit]': 20, 'page[offset]': (page - 1) * 20},
      );

      final List mediaList = response.data['data'] ?? [];
      return mediaList
          .map((item) => _mapToMediaEntity(item, type, 'kitsu', 'Kitsu'))
          .toList();
    } catch (e) {
      Logger.error('Kitsu trending failed', error: e);
      throw ServerException('Failed to get Kitsu trending: $e');
    }
  }

  /// Get popular anime/manga
  Future<List<MediaEntity>> getPopular(MediaType type, {int page = 1}) async {
    try {
      final endpoint = type == MediaType.anime ? 'anime' : 'manga';

      final response = await _dio.get(
        '/$endpoint',
        queryParameters: {
          'page[limit]': 20,
          'page[offset]': (page - 1) * 20,
          'sort': '-userCount', // Sort by popularity
        },
      );

      final List mediaList = response.data['data'] ?? [];
      return mediaList
          .map((item) => _mapToMediaEntity(item, type, 'kitsu', 'Kitsu'))
          .toList();
    } catch (e) {
      Logger.error('Kitsu popular failed', error: e);
      throw ServerException('Failed to get Kitsu popular: $e');
    }
  }

  /// Get episodes for an anime (with thumbnail images)
  Future<List<EpisodeEntity>> getEpisodes(String animeId) async {
    try {
      final response = await _dio.get(
        '/episodes',
        queryParameters: {
          'filter[mediaId]': animeId,
          'page[limit]': 100,
          'sort': 'number',
        },
      );

      final List episodesList = response.data['data'] ?? [];
      return episodesList.map((ep) {
        final attrs = ep['attributes'] ?? {};
        return EpisodeEntity(
          id: ep['id']?.toString() ?? '',
          mediaId: animeId,
          number: attrs['number'] ?? 0,
          title: attrs['canonicalTitle'] ?? attrs['titles']?['en_jp'] ?? '',
          thumbnail: attrs['thumbnail']?['original'],
          duration: attrs['length'],
          releaseDate: attrs['airdate'] != null
              ? DateTime.tryParse(attrs['airdate'])
              : null,
        );
      }).toList();
    } catch (e) {
      Logger.error('Kitsu get episodes failed', error: e);
      throw ServerException('Failed to get Kitsu episodes: $e');
    }
  }

  /// Get chapters for a manga
  Future<List<ChapterEntity>> getChapters(String mangaId) async {
    try {
      final response = await _dio.get(
        '/chapters',
        queryParameters: {
          'filter[mangaId]': mangaId,
          'page[limit]': 100,
          'sort': 'number',
        },
      );

      final List chaptersList = response.data['data'] ?? [];
      return chaptersList.map((ch) {
        final attrs = ch['attributes'] ?? {};
        return ChapterEntity(
          id: ch['id']?.toString() ?? '',
          mediaId: mangaId,
          number: double.tryParse(attrs['number']?.toString() ?? '0') ?? 0.0,
          title: attrs['canonicalTitle'] ?? attrs['titles']?['en_jp'] ?? '',
          releaseDate: attrs['published'] != null
              ? DateTime.tryParse(attrs['published'])
              : null,
          pageCount: null,
        );
      }).toList();
    } catch (e) {
      Logger.error('Kitsu get chapters failed', error: e);
      throw ServerException('Failed to get Kitsu chapters: $e');
    }
  }

  // Mapping functions

  MediaEntity _mapToMediaEntity(
    Map<String, dynamic> json,
    MediaType type,
    String sourceId,
    String sourceName,
  ) {
    final attrs = json['attributes'] ?? {};

    return MediaEntity(
      id: json['id']?.toString() ?? '',
      title:
          attrs['canonicalTitle'] ??
          attrs['titles']?['en_jp'] ??
          attrs['titles']?['en'] ??
          '',
      coverImage:
          attrs['posterImage']?['medium'] ?? attrs['posterImage']?['small'],
      bannerImage:
          attrs['coverImage']?['original'] ?? attrs['coverImage']?['large'],
      description: attrs['synopsis'] ?? attrs['description'],
      type: type,
      rating:
          (attrs['averageRating'] != null
              ? double.tryParse(attrs['averageRating'].toString())
              : null) ??
          0.0,
      genres: [], // Genres require separate API call in Kitsu
      status: _mapKitsuStatus(attrs['status']),
      totalEpisodes: attrs['episodeCount'],
      totalChapters: attrs['chapterCount'],
      sourceId: sourceId,
      sourceName: sourceName,
    );
  }

  MediaDetailsEntity _mapToAnimeDetailsEntity(
    Map<String, dynamic> json,
    List<CharacterEntity>? characters,
    List<StaffEntity>? staff,
    List<ReviewEntity>? reviews,
    List<RecommendationEntity>? recommendations,
  ) {
    final attrs = json['attributes'] ?? {};

    // Parse dates
    DateTime? startDate;
    DateTime? endDate;
    try {
      if (attrs['startDate'] != null) {
        startDate = DateTime.parse(attrs['startDate']);
      }
      if (attrs['endDate'] != null) {
        endDate = DateTime.parse(attrs['endDate']);
      }
    } catch (e) {
      // Invalid dates
    }

    return MediaDetailsEntity(
      id: json['id']?.toString() ?? '',
      title:
          attrs['canonicalTitle'] ??
          attrs['titles']?['en_jp'] ??
          attrs['titles']?['en'] ??
          '',
      englishTitle: attrs['titles']?['en'],
      romajiTitle: attrs['titles']?['en_jp'],
      nativeTitle: attrs['titles']?['ja_jp'],
      coverImage:
          attrs['posterImage']?['large'] ??
          attrs['posterImage']?['medium'] ??
          '',
      bannerImage:
          attrs['coverImage']?['original'] ?? attrs['coverImage']?['large'],
      description: attrs['synopsis'] ?? attrs['description'],
      type: MediaType.anime,
      status: _mapKitsuStatus(attrs['status']),
      rating:
          (attrs['averageRating'] != null
              ? double.tryParse(attrs['averageRating'].toString())
              : null) ??
          0.0,
      averageScore: attrs['averageRating'] != null
          ? double.tryParse(attrs['averageRating'].toString())?.toInt()
          : null,
      popularity: attrs['userCount'],
      favorites: attrs['favoritesCount'],
      genres: [], // Genres require separate call
      tags: [],
      startDate: startDate,
      endDate: endDate,
      episodes: attrs['episodeCount'],
      chapters: null,
      volumes: null,
      duration: attrs['episodeLength']?.toInt(),
      season: null,
      seasonYear: startDate?.year,
      isAdult: attrs['nsfw'] == true,
      siteUrl: 'https://kitsu.io/anime/${json['id']}',
      sourceId: 'kitsu',
      sourceName: 'Kitsu',
      characters: characters,
      staff: staff,
      reviews: reviews,
      recommendations: recommendations,
      relations: null,
      studios: null,
      rankings: null,
      trailer: attrs['youtubeVideoId'] != null
          ? TrailerEntity(id: attrs['youtubeVideoId'] ?? '', site: 'youtube')
          : null,
    );
  }

  MediaDetailsEntity _mapToMangaDetailsEntity(
    Map<String, dynamic> json,
    List<CharacterEntity>? characters,
    List<StaffEntity>? staff,
    List<ReviewEntity>? reviews,
    List<RecommendationEntity>? recommendations,
  ) {
    final attrs = json['attributes'] ?? {};

    // Parse dates
    DateTime? startDate;
    DateTime? endDate;
    try {
      if (attrs['startDate'] != null) {
        startDate = DateTime.parse(attrs['startDate']);
      }
      if (attrs['endDate'] != null) {
        endDate = DateTime.parse(attrs['endDate']);
      }
    } catch (e) {
      // Invalid dates
    }

    return MediaDetailsEntity(
      id: json['id']?.toString() ?? '',
      title:
          attrs['canonicalTitle'] ??
          attrs['titles']?['en_jp'] ??
          attrs['titles']?['en'] ??
          '',
      englishTitle: attrs['titles']?['en'],
      romajiTitle: attrs['titles']?['en_jp'],
      nativeTitle: attrs['titles']?['ja_jp'],
      coverImage:
          attrs['posterImage']?['large'] ??
          attrs['posterImage']?['medium'] ??
          '',
      bannerImage:
          attrs['coverImage']?['original'] ?? attrs['coverImage']?['large'],
      description: attrs['synopsis'] ?? attrs['description'],
      type: MediaType.manga,
      status: _mapKitsuStatus(attrs['status']),
      rating:
          (attrs['averageRating'] != null
              ? double.tryParse(attrs['averageRating'].toString())
              : null) ??
          0.0,
      averageScore: attrs['averageRating'] != null
          ? double.tryParse(attrs['averageRating'].toString())?.toInt()
          : null,
      popularity: attrs['userCount'],
      favorites: attrs['favoritesCount'],
      genres: [],
      tags: [],
      startDate: startDate,
      endDate: endDate,
      episodes: null,
      chapters: attrs['chapterCount'],
      volumes: attrs['volumeCount'],
      duration: null,
      season: null,
      seasonYear: startDate?.year,
      isAdult: attrs['nsfw'] == true,
      siteUrl: 'https://kitsu.io/manga/${json['id']}',
      sourceId: 'kitsu',
      sourceName: 'Kitsu',
      characters: characters,
      staff: staff,
      reviews: reviews,
      recommendations: recommendations,
      relations: null,
      studios: null,
      rankings: null,
      trailer: null,
    );
  }

  MediaStatus _mapKitsuStatus(String? status) {
    if (status == null) return MediaStatus.ongoing;
    switch (status.toLowerCase()) {
      case 'finished':
        return MediaStatus.completed;
      case 'current':
      case 'publishing':
        return MediaStatus.ongoing;
      case 'upcoming':
      case 'unreleased':
        return MediaStatus.upcoming;
      default:
        return MediaStatus.ongoing;
    }
  }
}
