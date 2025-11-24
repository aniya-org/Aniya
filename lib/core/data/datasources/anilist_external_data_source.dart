import 'package:dio/dio.dart';
import '../../domain/entities/entities.dart';
import '../../error/exceptions.dart';
import '../../utils/logger.dart';

class AnilistExternalDataSourceImpl {
  late final Dio _dio;

  AnilistExternalDataSourceImpl() {
    _dio = Dio();
    _dio.options.baseUrl = 'https://graphql.anilist.co';
    // No auth needed for basic search
  }

  /// Advanced search with filtering, sorting, and pagination
  Future<SearchResult<List<MediaEntity>>> searchMedia(
    String query,
    MediaType type, {
    List<String>? genres,
    int? year,
    int? seasonYear,
    String? season,
    String? status,
    String? format,
    int? minScore,
    int? maxScore,
    String? sort = 'POPULARITY_DESC',
    int page = 1,
    int perPage = 20,
    bool includeFull = false,
  }) async {
    try {
      final String mediaType = _mapMediaTypeToAnilist(type);

      // Advanced GraphQL query with filtering
      final String queryBody = '''
        query (
          \$search: String,
          \$type: MediaType,
          \$genres: [String],
          \$year: Int,
          \$seasonYear: Int,
          \$season: MediaSeason,
          \$status: MediaStatus,
          \$format: MediaFormat,
          \$minScore: Int,
          \$maxScore: Int,
          \$sort: [MediaSort],
          \$page: Int,
          \$perPage: Int
        ) {
          Page(page: \$page, perPage: \$perPage) {
            pageInfo {
              total
              currentPage
              lastPage
              hasNextPage
              perPage
            }
            media(
              search: \$search,
              type: \$type,
              genre_in: \$genres,
              seasonYear: \$seasonYear,
              season: \$season,
              status: \$status,
              format: \$format,
              averageScore_greater: \$minScore,
              averageScore_lesser: \$maxScore,
              sort: \$sort
            ) {
              id
              title {
                romaji
                english
                native
              }
              coverImage {
                extraLarge
                large
                medium
              }
              bannerImage
              description
              format
              status
              episodes
              chapters
              volumes
              duration
              startDate {
                year
                month
                day
              }
              endDate {
                year
                month
                day
              }
              genres
              averageScore
              meanScore
              popularity
              favourites
              studios(isMain: true) {
                edges {
                  node {
                    id
                    name
                  }
                }
              }
              season
              seasonYear
              isAdult
              siteUrl
            }
          }
        }
      ''';

      final variables = <String, dynamic>{
        'search': query.isNotEmpty ? query : null,
        'type': mediaType,
        'page': page,
        'perPage': perPage,
      };

      // Add optional filters
      if (genres != null && genres.isNotEmpty) {
        variables['genres'] = genres;
      }
      if (year != null) {
        variables['seasonYear'] = year;
      }
      if (seasonYear != null) {
        variables['seasonYear'] = seasonYear;
      }
      if (season != null) {
        variables['season'] = season.toUpperCase();
      }
      if (status != null) {
        variables['status'] = status.toUpperCase();
      }
      if (format != null) {
        variables['format'] = format.toUpperCase();
      }
      if (minScore != null && minScore > 0) {
        variables['minScore'] = minScore;
      }
      if (maxScore != null && maxScore < 100) {
        variables['maxScore'] = maxScore;
      }
      if (sort != null) {
        variables['sort'] = [sort];
      }

      final response = await _dio.post(
        '',
        data: {'query': queryBody, 'variables': variables},
      );

      final pageInfo = response.data['data']['Page']['pageInfo'];
      final List mediaList = response.data['data']['Page']['media'] ?? [];

      final results = mediaList
          .map((m) => _mapToMediaEntity(m, type, 'anilist', 'AniList'))
          .toList();

      return SearchResult(
        items: results,
        totalCount: pageInfo?['total'] ?? 0,
        currentPage: pageInfo?['currentPage'] ?? page,
        hasNextPage: pageInfo?['hasNextPage'] ?? false,
        perPage: perPage,
      );
    } catch (e) {
      Logger.error('AniList advanced search failed', error: e);
      throw ServerException('Failed to search AniList: $e');
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
      final String mediaType = _mapMediaTypeToAnilist(type);

      // Build dynamic query based on requested data
      String charactersFragment = '';
      String staffFragment = '';
      String reviewsFragment = '';

      if (includeCharacters) {
        charactersFragment = '''
        characters(page: 1, perPage: 10, role: MAIN) {
          edges {
            role
            node {
              id
              name {
                full
                native
              }
              image {
                large
                medium
              }
            }
          }
        }
        ''';
      }

      if (includeStaff) {
        staffFragment = '''
        staff(page: 1, perPage: 10) {
          edges {
            role
            node {
              id
              name {
                full
                native
              }
              image {
                large
                medium
              }
            }
          }
        }
        ''';
      }

      if (includeReviews) {
        reviewsFragment = '''
        reviews(page: 1, perPage: 5, sort: RATING_DESC) {
          nodes {
            id
            score
            summary
            body
            user {
              id
              name
              avatar {
                medium
              }
            }
          }
        }
        ''';
      }

      final String queryBody =
          '''
        query (\$id: Int, \$type: MediaType) {
          Media(id: \$id, type: \$type) {
            id
            title {
              romaji
              english
              native
            }
            coverImage {
              extraLarge
              large
              medium
            }
            bannerImage
            description
            format
            status
            episodes
            chapters
            volumes
            duration
            startDate {
              year
              month
              day
            }
            endDate {
              year
              month
              day
            }
            genres
            tags {
              name
              rank
            }
            averageScore
            meanScore
            popularity
            favourites
            rankings {
              rank
              type
              year
              season
            }
            studios(isMain: true) {
              edges {
                node {
                  id
                  name
                  isAnimationStudio
                }
              }
            }
            season
            seasonYear
            isAdult
            siteUrl
            trailer {
              id
              site
            }
            relations {
              edges {
                relationType
                node {
                  id
                  title {
                    english
                    romaji
                  }
                  type
                  format
                }
              }
            }
            $charactersFragment
            $staffFragment
            $reviewsFragment
            recommendations(sort: RATING_DESC, page: 1, perPage: 10) {
              nodes {
                rating
                mediaRecommendation {
                  id
                  title {
                    english
                    romaji
                  }
                  coverImage {
                    large
                  }
                }
              }
            }
          }
        }
      ''';

      final response = await _dio.post(
        '',
        data: {
          'query': queryBody,
          'variables': {'id': int.parse(id), 'type': mediaType},
        },
      );

      final media = response.data['data']['Media'];
      return _mapToMediaDetailsEntity(media, type);
    } catch (e) {
      Logger.error('AniList get details failed', error: e);
      throw ServerException('Failed to get AniList details: $e');
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

  Future<List<MediaEntity>> getTrending(MediaType type, {int page = 1}) async {
    try {
      final String mediaType = _mapMediaTypeToAnilist(type);
      final String queryBody = '''
        query (\$type: MediaType, \$page: Int, \$perPage: Int) {
          Page(page: \$page, perPage: \$perPage) {
            media(type: \$type, sort: [TRENDING_DESC], status: RELEASING) {
              id
              title {
                romaji
                english
                native
              }
              coverImage {
                extraLarge
                large
              }
              bannerImage
              description
              format
              status
              episodes
              chapters
              volumes
              startDate {
                year
                month
                day
              }
              endDate {
                year
                month
                day
              }
              genres
              averageScore
              meanScore
              popularity
              favourites
            }
          }
        }
      ''';

      final response = await _dio.post(
        '',
        data: {
          'query': queryBody,
          'variables': {'type': mediaType, 'page': page, 'perPage': 20},
        },
      );

      final List mediaList = response.data['data']['Page']['media'] ?? [];
      return mediaList
          .map((m) => _mapToMediaEntity(m, type, 'anilist', 'AniList'))
          .toList();
    } catch (e) {
      Logger.error('AniList trending failed', error: e);
      throw ServerException('Failed to get AniList trending: $e');
    }
  }

  Future<List<MediaEntity>> getPopular(MediaType type, {int page = 1}) async {
    try {
      final String mediaType = _mapMediaTypeToAnilist(type);
      final String queryBody = '''
        query (\$type: MediaType, \$page: Int, \$perPage: Int) {
          Page(page: \$page, perPage: \$perPage) {
            media(type: \$type, sort: [POPULARITY_DESC]) {
              id
              title {
                romaji
                english
                native
              }
              coverImage {
                extraLarge
                large
              }
              bannerImage
              description
              format
              status
              episodes
              chapters
              volumes
              startDate {
                year
                month
                day
              }
              endDate {
                year
                month
                day
              }
              genres
              averageScore
              meanScore
              popularity
              favourites
            }
          }
        }
      ''';

      final response = await _dio.post(
        '',
        data: {
          'query': queryBody,
          'variables': {'type': mediaType, 'page': page, 'perPage': 20},
        },
      );

      final List mediaList = response.data['data']['Page']['media'] ?? [];
      return mediaList
          .map((m) => _mapToMediaEntity(m, type, 'anilist', 'AniList'))
          .toList();
    } catch (e) {
      Logger.error('AniList popular failed', error: e);
      throw ServerException('Failed to get AniList popular: $e');
    }
  }

  String _mapMediaTypeToAnilist(MediaType type) {
    switch (type) {
      case MediaType.anime:
        return 'ANIME';
      case MediaType.manga:
        return 'MANGA';
      case MediaType.movie:
        return 'ANIME'; // AniList treats movies as anime
      case MediaType.tvShow:
        return 'ANIME'; // AniList treats TV shows as anime
    }
  }

  MediaEntity _mapToMediaEntity(
    Map<String, dynamic> json,
    MediaType type,
    String sourceId,
    String sourceName,
  ) {
    // Choose title: english > romaji > native
    String title =
        json['title']['english'] ??
        json['title']['romaji'] ??
        json['title']['native'] ??
        '';

    return MediaEntity(
      id: json['id'].toString(),
      title: title,
      coverImage:
          json['coverImage']['extraLarge'] ?? json['coverImage']['large'],
      bannerImage: json['bannerImage'],
      description: _cleanDescription(json['description']),
      type: type,
      rating: (json['meanScore'] ?? 0) / 10.0, // AniList uses 0-100 scale
      genres: List<String>.from(json['genres'] ?? []),
      status: _mapAnilistStatus(json['status']),
      totalEpisodes: json['episodes'],
      totalChapters: json['chapters'],
      sourceId: sourceId,
      sourceName: sourceName,
    );
  }

  String? _cleanDescription(String? description) {
    if (description == null) return null;
    return description.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }

  MediaStatus _mapAnilistStatus(String? status) {
    if (status == null) return MediaStatus.ongoing;
    switch (status.toUpperCase()) {
      case 'FINISHED':
      case 'COMPLETED':
        return MediaStatus.completed;
      case 'RELEASING':
      case 'AIRING':
        return MediaStatus.ongoing;
      case 'NOT_YET_RELEASED':
      case 'UPCOMING':
        return MediaStatus.upcoming;
      default:
        return MediaStatus.ongoing;
    }
  }

  MediaDetailsEntity _mapToMediaDetailsEntity(
    Map<String, dynamic> json,
    MediaType type,
  ) {
    // Parse dates
    DateTime? startDate;
    DateTime? endDate;
    if (json['startDate'] != null) {
      try {
        startDate = DateTime(
          json['startDate']['year'] ?? 0,
          json['startDate']['month'] ?? 1,
          json['startDate']['day'] ?? 1,
        );
      } catch (e) {
        // Invalid date, leave as null
      }
    }
    if (json['endDate'] != null) {
      try {
        endDate = DateTime(
          json['endDate']['year'] ?? 0,
          json['endDate']['month'] ?? 1,
          json['endDate']['day'] ?? 1,
        );
      } catch (e) {
        // Invalid date, leave as null
      }
    }

    // Choose title
    String title =
        json['title']['english'] ??
        json['title']['romaji'] ??
        json['title']['native'] ??
        '';

    // Parse tags
    final tags = json['tags'] != null
        ? List<String>.from((json['tags'] as List).map((tag) => tag['name']))
        : <String>[];

    // Parse characters
    final characters = json['characters'] != null
        ? (json['characters']['edges'] as List?)?.map((edge) {
            final node = edge['node'] as Map<String, dynamic>;
            return CharacterEntity(
              id: node['id'].toString(),
              name: node['name']['full'] ?? node['name']['native'] ?? '',
              nativeName: node['name']['native'],
              image: node['image']['large'] ?? node['image']['medium'],
              role: edge['role'] ?? 'Unknown',
            );
          }).toList()
        : null;

    // Parse staff
    final staff = json['staff'] != null
        ? (json['staff']['edges'] as List?)?.map((edge) {
            final node = edge['node'] as Map<String, dynamic>;
            return StaffEntity(
              id: node['id'].toString(),
              name: node['name']['full'] ?? node['name']['native'] ?? '',
              nativeName: node['name']['native'],
              image: node['image']['large'] ?? node['image']['medium'],
              role: edge['role'] ?? 'Unknown',
            );
          }).toList()
        : null;

    // Parse reviews
    final reviews = json['reviews'] != null
        ? (json['reviews']['nodes'] as List?)?.map((node) {
            final user = node['user'] as Map<String, dynamic>?;
            return ReviewEntity(
              id: node['id'].toString(),
              score: node['score'] ?? 0,
              summary: node['summary'],
              body: node['body'],
              user: user != null
                  ? UserEntity(
                      id: user['id'].toString(),
                      username: user['name'] ?? '',
                      avatarUrl: user['avatar']['medium'],
                      service: TrackingService.anilist,
                    )
                  : null,
            );
          }).toList()
        : null;

    // Parse recommendations
    final recommendations = json['recommendations'] != null
        ? (json['recommendations']['nodes'] as List?)?.map((node) {
            final mediaNode =
                node['mediaRecommendation'] as Map<String, dynamic>;
            return RecommendationEntity(
              id: mediaNode['id'].toString(),
              title:
                  mediaNode['title']['english'] ??
                  mediaNode['title']['romaji'] ??
                  '',
              englishTitle: mediaNode['title']['english'],
              romajiTitle: mediaNode['title']['romaji'],
              coverImage: mediaNode['coverImage']['large'] ?? '',
              rating: node['rating'] ?? 0,
            );
          }).toList()
        : null;

    // Parse relations
    final relations = json['relations'] != null
        ? (json['relations']['edges'] as List?)?.map((edge) {
            final node = edge['node'] as Map<String, dynamic>;
            return MediaRelationEntity(
              relationType: edge['relationType'] ?? '',
              id: node['id'].toString(),
              title: node['title']['english'] ?? node['title']['romaji'] ?? '',
              englishTitle: node['title']['english'],
              romajiTitle: node['title']['romaji'],
              type: _mapAnilistTypeToMediaType(node['type']),
            );
          }).toList()
        : null;

    // Parse studios
    final studios = json['studios'] != null
        ? (json['studios']['edges'] as List?)?.map((edge) {
            final node = edge['node'] as Map<String, dynamic>;
            return StudioEntity(
              id: node['id'].toString(),
              name: node['name'] ?? '',
              isMain: true,
              isAnimationStudio: node['isAnimationStudio'] ?? false,
            );
          }).toList()
        : null;

    // Parse rankings
    final rankings = json['rankings'] != null
        ? (json['rankings'] as List?)?.map((ranking) {
            return RankingEntity(
              rank: ranking['rank'] ?? 0,
              type: ranking['type'] ?? '',
              year: ranking['year'],
              season: ranking['season'],
            );
          }).toList()
        : null;

    // Parse trailer
    TrailerEntity? trailer;
    if (json['trailer'] != null) {
      trailer = TrailerEntity(
        id: json['trailer']['id'] ?? '',
        site: json['trailer']['site'] ?? '',
      );
    }

    return MediaDetailsEntity(
      id: json['id'].toString(),
      title: title,
      englishTitle: json['title']['english'],
      romajiTitle: json['title']['romaji'],
      nativeTitle: json['title']['native'],
      coverImage:
          json['coverImage']['extraLarge'] ??
          json['coverImage']['large'] ??
          json['coverImage']['medium'] ??
          '',
      bannerImage: json['bannerImage'],
      description: _cleanDescription(json['description']),
      type: type,
      status: _mapAnilistStatus(json['status']),
      rating: json['meanScore'] != null ? json['meanScore'] / 10.0 : null,
      averageScore: json['averageScore'],
      meanScore: json['meanScore'],
      popularity: json['popularity'],
      favorites: json['favourites'],
      genres: List<String>.from(json['genres'] ?? []),
      tags: tags,
      startDate: startDate,
      endDate: endDate,
      episodes: json['episodes'],
      chapters: json['chapters'],
      volumes: json['volumes'],
      duration: json['duration'],
      season: json['season'],
      seasonYear: json['seasonYear'],
      isAdult: json['isAdult'] ?? false,
      siteUrl: json['siteUrl'],
      sourceId: 'anilist',
      sourceName: 'AniList',
      characters: characters,
      staff: staff,
      reviews: reviews,
      recommendations: recommendations,
      relations: relations,
      studios: studios,
      rankings: rankings,
      trailer: trailer,
    );
  }

  MediaType _mapAnilistTypeToMediaType(String? type) {
    if (type == null) return MediaType.anime;
    switch (type.toUpperCase()) {
      case 'ANIME':
        return MediaType.anime;
      case 'MANGA':
        return MediaType.manga;
      default:
        return MediaType.anime;
    }
  }

  Future<List<EpisodeEntity>> getEpisodes(String id) async {
    try {
      final queryBody = '''
        query (\$id: Int) {
          Media(id: \$id) {
            streamingEpisodes {
              title
              thumbnail
              url
              site
            }
          }
        }
      ''';

      final response = await _dio.post(
        '',
        data: {
          'query': queryBody,
          'variables': {'id': int.parse(id)},
        },
      );

      final media = response.data['data']['Media'];
      final streamingEpisodes = media['streamingEpisodes'] as List?;

      if (streamingEpisodes == null) return [];

      return streamingEpisodes.asMap().entries.map((entry) {
        final index = entry.key;
        final episode = entry.value;
        return EpisodeEntity(
          id: 'anilist_streaming_$index',
          mediaId: id,
          number: index + 1,
          title: episode['title'] ?? 'Episode ${index + 1}',
          thumbnail: episode['thumbnail'],
          releaseDate: null,
        );
      }).toList();
    } catch (e) {
      Logger.error('AniList get episodes failed', error: e);
      return [];
    }
  }
}
