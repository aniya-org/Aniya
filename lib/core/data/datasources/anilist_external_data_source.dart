import 'package:dio/dio.dart';
import '../../domain/entities/media_entity.dart';
import '../../domain/entities/media_details_entity.dart' hide SearchResult;
import '../../domain/entities/episode_entity.dart';
import '../../domain/entities/episode_page_result.dart';
import '../../domain/entities/chapter_entity.dart';
import '../../domain/entities/search_result_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../../error/exceptions.dart';
import '../../utils/logger.dart';

class AnilistExternalDataSourceImpl {
  late final Dio _dio;

  AnilistExternalDataSourceImpl() {
    _dio = Dio();
    _dio.options.baseUrl = 'https://graphql.anilist.co';
    // No auth needed for basic search
  }

  Future<EpisodePageResult> getEpisodePage({
    required String id,
    int offset = 0,
    int limit = 50,
  }) async {
    final safeLimit = limit <= 0 ? 50 : limit;
    final safeOffset = offset < 0 ? 0 : offset;

    try {
      final episodes = await getEpisodes(id);
      if (episodes.isEmpty || safeOffset >= episodes.length) {
        return EpisodePageResult(
          episodes: const [],
          nextOffset: null,
          providerId: 'anilist',
          providerMediaId: id,
        );
      }

      final end = (safeOffset + safeLimit) > episodes.length
          ? episodes.length
          : safeOffset + safeLimit;
      final pageEpisodes = episodes.sublist(safeOffset, end);
      final nextOffset = end < episodes.length ? end : null;

      return EpisodePageResult(
        episodes: pageEpisodes,
        nextOffset: nextOffset,
        providerId: 'anilist',
        providerMediaId: id,
      );
    } catch (e, stackTrace) {
      Logger.error(
        'AniList getEpisodePage failed',
        error: e,
        stackTrace: stackTrace,
      );
      throw ServerException('Failed to get AniList paged episodes: $e');
    }
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
      Logger.info(
        'AniList search: query="$query", type=$type, page=$page',
        tag: 'AniListDataSource',
      );

      final String mediaType = _mapMediaTypeToAnilist(type);

      // Advanced GraphQL query with filtering
      // Note: Only include parameters that are actually being used to avoid 400 errors
      final String queryBody = '''
        query (
          \$search: String,
          \$type: MediaType,
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
              sort: [SEARCH_MATCH, POPULARITY_DESC]
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

      final response = await _dio.post(
        '',
        data: {'query': queryBody, 'variables': variables},
      );

      final pageInfo = response.data['data']['Page']['pageInfo'];
      final List mediaList = response.data['data']['Page']['media'] ?? [];

      final results = mediaList
          .map((m) => _mapToMediaEntity(m, type, 'anilist', 'AniList'))
          .toList();

      Logger.info(
        'AniList search completed: ${results.length} results',
        tag: 'AniListDataSource',
      );

      return SearchResult(
        items: results,
        totalCount: pageInfo?['total'] ?? 0,
        currentPage: pageInfo?['currentPage'] ?? page,
        hasNextPage: pageInfo?['hasNextPage'] ?? false,
        perPage: perPage,
      );
    } catch (e, stackTrace) {
      Logger.error(
        'AniList advanced search failed',
        tag: 'AniListDataSource',
        error: e,
        stackTrace: stackTrace,
      );
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
    // Choose title: english > romaji > native (with null safety)
    final titleObj = json['title'] as Map<String, dynamic>?;
    String title =
        titleObj?['english'] ??
        titleObj?['romaji'] ??
        titleObj?['native'] ??
        '';

    // Safe cover image extraction
    final coverImageObj = json['coverImage'] as Map<String, dynamic>?;
    String? coverImage =
        coverImageObj?['extraLarge'] ??
        coverImageObj?['large'] ??
        coverImageObj?['medium'];

    // Safe rating conversion
    double safeRating(dynamic score) {
      if (score == null) return 0.0;
      if (score is int) return score / 10.0;
      if (score is double) return score / 10.0;
      return 0.0;
    }

    return MediaEntity(
      id: json['id'].toString(),
      title: title,
      coverImage: coverImage,
      bannerImage: json['bannerImage'],
      description: _cleanDescription(json['description']),
      type: type,
      rating: safeRating(json['meanScore']), // AniList uses 0-100 scale
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
    // Safe type conversion helper
    int? safeToInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    // Parse dates safely
    DateTime? startDate;
    DateTime? endDate;
    final startDateObj = json['startDate'] as Map<String, dynamic>?;
    final endDateObj = json['endDate'] as Map<String, dynamic>?;

    if (startDateObj != null && startDateObj['year'] != null) {
      try {
        final year = safeToInt(startDateObj['year']);
        if (year != null && year > 0) {
          startDate = DateTime(
            year,
            safeToInt(startDateObj['month']) ?? 1,
            safeToInt(startDateObj['day']) ?? 1,
          );
        }
      } catch (e) {
        // Invalid date, leave as null
      }
    }
    if (endDateObj != null && endDateObj['year'] != null) {
      try {
        final year = safeToInt(endDateObj['year']);
        if (year != null && year > 0) {
          endDate = DateTime(
            year,
            safeToInt(endDateObj['month']) ?? 1,
            safeToInt(endDateObj['day']) ?? 1,
          );
        }
      } catch (e) {
        // Invalid date, leave as null
      }
    }

    // Choose title safely
    final titleObj = json['title'] as Map<String, dynamic>?;
    String title =
        titleObj?['english'] ??
        titleObj?['romaji'] ??
        titleObj?['native'] ??
        '';

    // Parse tags safely
    final tags = json['tags'] != null
        ? List<String>.from(
            (json['tags'] as List).map(
              (tag) => (tag as Map<String, dynamic>)['name']?.toString() ?? '',
            ),
          )
        : <String>[];

    // Parse characters safely
    List<CharacterEntity>? characters;
    if (json['characters'] != null) {
      final edges =
          (json['characters'] as Map<String, dynamic>)['edges'] as List?;
      if (edges != null) {
        characters = edges.map((edge) {
          final edgeMap = edge as Map<String, dynamic>;
          final node = edgeMap['node'] as Map<String, dynamic>?;
          final nameObj = node?['name'] as Map<String, dynamic>?;
          final imageObj = node?['image'] as Map<String, dynamic>?;
          return CharacterEntity(
            id: node?['id']?.toString() ?? '',
            name: nameObj?['full'] ?? nameObj?['native'] ?? '',
            nativeName: nameObj?['native'],
            image: imageObj?['large'] ?? imageObj?['medium'],
            role: edgeMap['role']?.toString() ?? 'Unknown',
          );
        }).toList();
      }
    }

    // Parse staff safely
    List<StaffEntity>? staff;
    if (json['staff'] != null) {
      final edges = (json['staff'] as Map<String, dynamic>)['edges'] as List?;
      if (edges != null) {
        staff = edges.map((edge) {
          final edgeMap = edge as Map<String, dynamic>;
          final node = edgeMap['node'] as Map<String, dynamic>?;
          final nameObj = node?['name'] as Map<String, dynamic>?;
          final imageObj = node?['image'] as Map<String, dynamic>?;
          return StaffEntity(
            id: node?['id']?.toString() ?? '',
            name: nameObj?['full'] ?? nameObj?['native'] ?? '',
            nativeName: nameObj?['native'],
            image: imageObj?['large'] ?? imageObj?['medium'],
            role: edgeMap['role']?.toString() ?? 'Unknown',
          );
        }).toList();
      }
    }

    // Parse reviews safely
    List<ReviewEntity>? reviews;
    if (json['reviews'] != null) {
      final nodes = (json['reviews'] as Map<String, dynamic>)['nodes'] as List?;
      if (nodes != null) {
        reviews = nodes.map((node) {
          final nodeMap = node as Map<String, dynamic>;
          final user = nodeMap['user'] as Map<String, dynamic>?;
          final avatarObj = user?['avatar'] as Map<String, dynamic>?;
          return ReviewEntity(
            id: nodeMap['id']?.toString() ?? '',
            score: safeToInt(nodeMap['score']) ?? 0,
            summary: nodeMap['summary']?.toString(),
            body: nodeMap['body']?.toString(),
            user: user != null
                ? UserEntity(
                    id: user['id']?.toString() ?? '',
                    username: user['name']?.toString() ?? '',
                    avatarUrl: avatarObj?['medium'],
                    service: TrackingService.anilist,
                  )
                : null,
          );
        }).toList();
      }
    }

    // Parse recommendations safely
    List<RecommendationEntity>? recommendations;
    if (json['recommendations'] != null) {
      final nodes =
          (json['recommendations'] as Map<String, dynamic>)['nodes'] as List?;
      if (nodes != null) {
        recommendations = nodes
            .where((node) {
              final nodeMap = node as Map<String, dynamic>;
              return nodeMap['mediaRecommendation'] != null;
            })
            .map((node) {
              final nodeMap = node as Map<String, dynamic>;
              final mediaNode =
                  nodeMap['mediaRecommendation'] as Map<String, dynamic>;
              final mediaTitleObj = mediaNode['title'] as Map<String, dynamic>?;
              final coverObj = mediaNode['coverImage'] as Map<String, dynamic>?;
              return RecommendationEntity(
                id: mediaNode['id']?.toString() ?? '',
                title:
                    mediaTitleObj?['english'] ?? mediaTitleObj?['romaji'] ?? '',
                englishTitle: mediaTitleObj?['english'],
                romajiTitle: mediaTitleObj?['romaji'],
                coverImage: coverObj?['large'] ?? '',
                rating: safeToInt(nodeMap['rating']) ?? 0,
              );
            })
            .toList();
      }
    }

    // Parse relations safely
    List<MediaRelationEntity>? relations;
    if (json['relations'] != null) {
      final edges =
          (json['relations'] as Map<String, dynamic>)['edges'] as List?;
      if (edges != null) {
        relations = edges.map((edge) {
          final edgeMap = edge as Map<String, dynamic>;
          final node = edgeMap['node'] as Map<String, dynamic>?;
          final nodeTitleObj = node?['title'] as Map<String, dynamic>?;
          return MediaRelationEntity(
            relationType: edgeMap['relationType']?.toString() ?? '',
            id: node?['id']?.toString() ?? '',
            title: nodeTitleObj?['english'] ?? nodeTitleObj?['romaji'] ?? '',
            englishTitle: nodeTitleObj?['english'],
            romajiTitle: nodeTitleObj?['romaji'],
            type: _mapAnilistTypeToMediaType(node?['type']?.toString()),
          );
        }).toList();
      }
    }

    // Parse studios safely
    List<StudioEntity>? studios;
    if (json['studios'] != null) {
      final edges = (json['studios'] as Map<String, dynamic>)['edges'] as List?;
      if (edges != null) {
        studios = edges.map((edge) {
          final edgeMap = edge as Map<String, dynamic>;
          final node = edgeMap['node'] as Map<String, dynamic>?;
          return StudioEntity(
            id: node?['id']?.toString() ?? '',
            name: node?['name']?.toString() ?? '',
            isMain: true,
            isAnimationStudio: node?['isAnimationStudio'] == true,
          );
        }).toList();
      }
    }

    // Parse rankings safely
    List<RankingEntity>? rankings;
    if (json['rankings'] != null) {
      final rankingsList = json['rankings'] as List?;
      if (rankingsList != null) {
        rankings = rankingsList.map((ranking) {
          final rankingMap = ranking as Map<String, dynamic>;
          return RankingEntity(
            rank: safeToInt(rankingMap['rank']) ?? 0,
            type: rankingMap['type']?.toString() ?? '',
            year: safeToInt(rankingMap['year']),
            season: rankingMap['season']?.toString(),
          );
        }).toList();
      }
    }

    // Parse trailer safely
    TrailerEntity? trailer;
    final trailerObj = json['trailer'] as Map<String, dynamic>?;
    if (trailerObj != null && trailerObj['id'] != null) {
      trailer = TrailerEntity(
        id: trailerObj['id']?.toString() ?? '',
        site: trailerObj['site']?.toString() ?? '',
      );
    }

    // Safe cover image extraction
    final coverImageObj = json['coverImage'] as Map<String, dynamic>?;
    String coverImage =
        coverImageObj?['extraLarge'] ??
        coverImageObj?['large'] ??
        coverImageObj?['medium'] ??
        '';

    return MediaDetailsEntity(
      id: json['id'].toString(),
      title: title,
      englishTitle: titleObj?['english'],
      romajiTitle: titleObj?['romaji'],
      nativeTitle: titleObj?['native'],
      coverImage: coverImage,
      bannerImage: json['bannerImage'],
      description: _cleanDescription(json['description']),
      type: type,
      status: _mapAnilistStatus(json['status']),
      rating: json['meanScore'] != null
          ? (json['meanScore'] as num) / 10.0
          : null,
      averageScore: safeToInt(json['averageScore']),
      meanScore: safeToInt(json['meanScore']),
      popularity: safeToInt(json['popularity']),
      favorites: safeToInt(json['favourites']),
      genres: List<String>.from(json['genres'] ?? []),
      tags: tags,
      startDate: startDate,
      endDate: endDate,
      episodes: safeToInt(json['episodes']),
      chapters: safeToInt(json['chapters']),
      volumes: safeToInt(json['volumes']),
      duration: safeToInt(json['duration']),
      season: json['season']?.toString(),
      seasonYear: safeToInt(json['seasonYear']),
      isAdult: json['isAdult'] == true,
      siteUrl: json['siteUrl']?.toString(),
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

  /// Get chapters for a manga
  /// Note: AniList doesn't provide chapter-level data via API.
  /// We generate placeholder chapters based on the manga's chapter count.
  Future<List<ChapterEntity>> getChapters(String id) async {
    try {
      final queryBody = '''
        query (\$id: Int) {
          Media(id: \$id, type: MANGA) {
            chapters
            title {
              romaji
              english
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
      final totalChapters = media['chapters'] as int?;

      if (totalChapters == null || totalChapters <= 0) {
        Logger.info('AniList manga $id has no chapter count');
        return [];
      }

      Logger.info(
        'AniList generating $totalChapters placeholder chapters for manga $id',
      );

      // Generate placeholder chapters
      return List.generate(totalChapters, (index) {
        final chapterNum = index + 1;
        return ChapterEntity(
          id: 'anilist_chapter_${id}_$chapterNum',
          mediaId: id,
          number: chapterNum.toDouble(),
          title: 'Chapter $chapterNum',
          releaseDate: null,
          pageCount: null,
          sourceProvider: 'anilist',
        );
      });
    } catch (e) {
      Logger.error('AniList get chapters failed', error: e);
      return [];
    }
  }
}
