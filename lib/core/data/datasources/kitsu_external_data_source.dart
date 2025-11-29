import 'package:dio/dio.dart';
import '../../domain/entities/media_entity.dart';
import '../../domain/entities/media_details_entity.dart' hide SearchResult;
import '../../domain/entities/episode_entity.dart';
import '../../domain/entities/episode_page_result.dart';
import '../../domain/entities/chapter_entity.dart';
import '../../domain/entities/chapter_page_result.dart';
import '../../domain/entities/search_result_entity.dart';
import '../../error/exceptions.dart';
import '../../utils/logger.dart';

class _KitsuChapterPage {
  final List<dynamic> data;
  final String? nextLink;

  const _KitsuChapterPage({required this.data, this.nextLink});
}

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
    int? year,
    String? season,
  }) async {
    try {
      Logger.info(
        'Kitsu search: query="$query", type=$type, page=$page',
        tag: 'KitsuDataSource',
      );

      if (type != MediaType.anime &&
          type != MediaType.manga &&
          type != MediaType.novel) {
        Logger.debug(
          'Kitsu does not support type: $type',
          tag: 'KitsuDataSource',
        );
        return SearchResult<List<MediaEntity>>(
          items: [],
          totalCount: 0,
          currentPage: 1,
          hasNextPage: false,
          perPage: perPage,
        );
      }

      // Novels are under manga endpoint in Kitsu with subtype filter
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

      Logger.info(
        'Kitsu search completed: ${results.length} results',
        tag: 'KitsuDataSource',
      );

      return SearchResult<List<MediaEntity>>(
        items: results,
        totalCount: totalCount,
        currentPage: page,
        hasNextPage: mediaList.length == perPage,
        perPage: perPage,
      );
    } catch (e, stackTrace) {
      Logger.error(
        'Kitsu search failed',
        tag: 'KitsuDataSource',
        error: e,
        stackTrace: stackTrace,
      );
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
      // Always include categories for genres, and optionally include characters/staff
      final includes = <String>['categories'];
      if (includeCharacters) {
        includes.add(
          type == MediaType.anime
              ? 'animeCharacters.character'
              : 'mangaCharacters.character',
        );
      }
      if (includeStaff && type == MediaType.anime) {
        includes.add('animeStaff.person');
      }
      if (type == MediaType.anime) {
        includes.add('animeProductions.producer');
      }

      final includeParam = includes.join(',');

      Logger.debug('Kitsu fetching $endpoint/$id with includes: $includeParam');

      final response = await _dio.get(
        '/$endpoint/$id',
        queryParameters: {'include': includeParam},
      );

      final media = response.data['data'];
      final included = response.data['included'] as List<dynamic>? ?? [];

      // Parse genres from categories
      List<String> genres = [];
      try {
        for (final item in included) {
          if (item is Map<String, dynamic> && item['type'] == 'categories') {
            final attrs = item['attributes'] as Map<String, dynamic>? ?? {};
            final title = attrs['title']?.toString();
            if (title != null && title.isNotEmpty) {
              genres.add(title);
            }
          }
        }
        Logger.debug('Kitsu parsed ${genres.length} genres/categories');
      } catch (e) {
        Logger.error('Failed to parse genres from Kitsu response', error: e);
      }

      // Parse characters from included
      List<CharacterEntity>? characters;
      try {
        if (includeCharacters) {
          characters = <CharacterEntity>[];
          for (final item in included) {
            if (item is Map<String, dynamic> && item['type'] == 'characters') {
              final attrs = item['attributes'] as Map<String, dynamic>? ?? {};
              final imageObj = attrs['image'] as Map<String, dynamic>?;
              characters.add(
                CharacterEntity(
                  id: item['id']?.toString() ?? '',
                  name:
                      attrs['canonicalName']?.toString() ??
                      attrs['name']?.toString() ??
                      '',
                  nativeName: attrs['names']?['ja_jp']?.toString(),
                  image:
                      imageObj?['original']?.toString() ??
                      imageObj?['large']?.toString(),
                  role: 'Unknown',
                ),
              );
              if (characters.length >= 10) break; // Limit to 10 characters
            }
          }
          if (characters.isEmpty) characters = null;
          Logger.debug('Kitsu parsed ${characters?.length ?? 0} characters');
        }
      } catch (e) {
        Logger.error(
          'Failed to parse characters from Kitsu response',
          error: e,
        );
        characters = null;
      }

      // Parse staff from included (anime only)
      List<StaffEntity>? staff;
      try {
        if (includeStaff && type == MediaType.anime) {
          staff = <StaffEntity>[];
          for (final item in included) {
            if (item is Map<String, dynamic> && item['type'] == 'people') {
              final attrs = item['attributes'] as Map<String, dynamic>? ?? {};
              final imageObj = attrs['image'] as Map<String, dynamic>?;
              staff.add(
                StaffEntity(
                  id: item['id']?.toString() ?? '',
                  name:
                      attrs['canonicalName']?.toString() ??
                      attrs['name']?.toString() ??
                      '',
                  nativeName: attrs['names']?['ja_jp']?.toString(),
                  image:
                      imageObj?['original']?.toString() ??
                      imageObj?['large']?.toString(),
                  role: 'Staff',
                ),
              );
              if (staff.length >= 10) break; // Limit to 10 staff
            }
          }
          if (staff.isEmpty) staff = null;
          Logger.debug('Kitsu parsed ${staff?.length ?? 0} staff members');
        }
      } catch (e) {
        Logger.error('Failed to parse staff from Kitsu response', error: e);
        staff = null;
      }

      // Parse studios/producers from included (anime only)
      List<StudioEntity>? studios;
      try {
        if (type == MediaType.anime) {
          studios = <StudioEntity>[];
          for (final item in included) {
            if (item is Map<String, dynamic> && item['type'] == 'producers') {
              final attrs = item['attributes'] as Map<String, dynamic>? ?? {};
              studios.add(
                StudioEntity(
                  id: item['id']?.toString() ?? '',
                  name: attrs['name']?.toString() ?? '',
                  isMain: true,
                  isAnimationStudio: true,
                ),
              );
            }
          }
          if (studios.isEmpty) studios = null;
          Logger.debug('Kitsu parsed ${studios?.length ?? 0} studios');
        }
      } catch (e) {
        Logger.error('Failed to parse studios from Kitsu response', error: e);
        studios = null;
      }

      return type == MediaType.anime
          ? _mapToAnimeDetailsEntity(
              media,
              characters,
              staff,
              null,
              null,
              genres: genres,
              studios: studios,
            )
          : _mapToMangaDetailsEntity(
              media,
              characters,
              null,
              null,
              null,
              genres: genres,
            );
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
  Future<List<EpisodeEntity>> getEpisodes(
    String animeId, {
    String? coverImage,
  }) async {
    try {
      // Use provided cover image or fetch from API
      String? animePosterImage = coverImage;
      if (animePosterImage == null) {
        animePosterImage = await _fetchAnimePosterImage(animeId);
      } else {
        Logger.debug('Kitsu using provided cover image for fallback');
      }

      // Kitsu API: Use the episodes endpoint
      // The relationship endpoint /anime/{id}/episodes is the correct approach
      List episodesList = [];
      try {
        Logger.debug('Kitsu fetching episodes for anime ID: $animeId');
        final response = await _dio.get(
          '/anime/$animeId/episodes',
          queryParameters: {'page[limit]': 100, 'sort': 'number'},
        );
        episodesList = response.data['data'] ?? [];
        Logger.info(
          'Kitsu episodes endpoint returned ${episodesList.length} episodes',
        );
      } catch (e) {
        // Log the specific error for debugging
        Logger.warning('Kitsu episodes endpoint failed for anime $animeId: $e');
        // Return empty list - the anime might not have episodes in Kitsu
        return [];
      }

      // Log episode count for debugging
      Logger.info(
        'Kitsu returned ${episodesList.length} episodes for anime $animeId',
      );
      return episodesList
          .map((ep) => _mapEpisodeEntity(ep, animeId, animePosterImage))
          .toList();
    } catch (e) {
      Logger.error('Kitsu get episodes failed', error: e);
      throw ServerException('Failed to get Kitsu episodes: $e');
    }
  }

  Future<EpisodePageResult> getEpisodePage({
    required String animeId,
    int offset = 0,
    int limit = 50,
    String? coverImage,
  }) async {
    final safeLimit = limit <= 0 ? 50 : limit.clamp(1, 100);
    final safeOffset = offset < 0 ? 0 : offset;

    try {
      String? animePosterImage =
          coverImage ?? await _fetchAnimePosterImage(animeId);
      final response = await _dio.get(
        '/anime/$animeId/episodes',
        queryParameters: {
          'page[limit]': safeLimit,
          'page[offset]': safeOffset,
          'sort': 'number',
        },
      );

      final List episodesList = response.data['data'] ?? [];
      final links = response.data['links'] as Map<String, dynamic>?;
      final hasNext = links?['next'] != null && episodesList.isNotEmpty;

      final episodes = episodesList
          .map((ep) => _mapEpisodeEntity(ep, animeId, animePosterImage))
          .toList();

      final nextOffset = hasNext ? safeOffset + episodes.length : null;

      return EpisodePageResult(
        episodes: episodes,
        nextOffset: nextOffset,
        providerId: 'kitsu',
        providerMediaId: animeId,
      );
    } catch (e, stackTrace) {
      Logger.error(
        'Kitsu getEpisodePage failed for anime $animeId',
        error: e,
        stackTrace: stackTrace,
      );
      throw ServerException('Failed to get Kitsu paged episodes: $e');
    }
  }

  Future<String?> _fetchAnimePosterImage(String animeId) async {
    try {
      final animeResponse = await _dio.get('/anime/$animeId');
      final animeData = animeResponse.data['data'];
      final posterObj =
          animeData?['attributes']?['posterImage'] as Map<String, dynamic>?;
      final poster =
          posterObj?['large'] ?? posterObj?['medium'] ?? posterObj?['small'];
      Logger.debug('Kitsu anime poster for fallback: $poster');
      return poster;
    } catch (e) {
      Logger.warning('Could not fetch Kitsu anime details for fallback: $e');
      return null;
    }
  }

  EpisodeEntity _mapEpisodeEntity(
    dynamic episode,
    String animeId,
    String? animePosterImage,
  ) {
    final epMap = episode as Map<String, dynamic>;
    final attrs = epMap['attributes'] as Map<String, dynamic>? ?? {};
    final titlesObj = attrs['titles'] as Map<String, dynamic>?;
    final thumbnailObj = attrs['thumbnail'] as Map<String, dynamic>?;

    int safeToInt(dynamic value, int defaultValue) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? defaultValue;
      return defaultValue;
    }

    String? thumbnailUrl;
    if (thumbnailObj != null) {
      thumbnailUrl =
          thumbnailObj['original']?.toString() ??
          thumbnailObj['large']?.toString() ??
          thumbnailObj['small']?.toString();
    } else if (attrs['thumbnail'] is String) {
      thumbnailUrl = attrs['thumbnail'] as String;
    }

    final finalThumbnail = thumbnailUrl ?? animePosterImage;

    if (thumbnailUrl != null) {
      Logger.debug(
        'Kitsu episode ${attrs['number']} has thumbnail: $thumbnailUrl',
      );
    } else if (animePosterImage != null) {
      Logger.debug(
        'Kitsu episode ${attrs['number']} using anime poster as fallback',
      );
    }

    return EpisodeEntity(
      id: epMap['id']?.toString() ?? '',
      mediaId: animeId,
      number: safeToInt(attrs['number'], 0),
      title:
          attrs['canonicalTitle']?.toString() ??
          titlesObj?['en_jp']?.toString() ??
          titlesObj?['en']?.toString() ??
          'Episode ${attrs['number'] ?? 0}',
      thumbnail: finalThumbnail,
      duration: safeToInt(attrs['length'], 0) > 0
          ? safeToInt(attrs['length'], 0)
          : null,
      releaseDate: attrs['airdate'] != null
          ? DateTime.tryParse(attrs['airdate'].toString())
          : null,
    );
  }

  /// Get chapters for a manga with pagination.
  /// Falls back to placeholder generation when the chapters endpoint fails.
  Future<List<ChapterEntity>> getChapters(String mangaId) async {
    try {
      final totalChapters = await _getChapterCount(mangaId);
      final fetchedChapters = await _fetchChaptersPaged(mangaId);

      if (fetchedChapters.isNotEmpty) {
        return fetchedChapters;
      }

      if (totalChapters != null && totalChapters > 0) {
        Logger.info(
          'Kitsu fallback: generating $totalChapters placeholder chapters for manga $mangaId',
        );
        return _generatePlaceholderChapters(mangaId, totalChapters);
      }

      Logger.warning(
        'Kitsu chapters unavailable for $mangaId and no total count to fallback on',
      );
      return [];
    } catch (e, stackTrace) {
      Logger.error(
        'Kitsu getChapters failed for manga $mangaId',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  Future<int?> _getChapterCount(String mangaId) async {
    try {
      final mangaResponse = await _dio.get('/manga/$mangaId');
      final mangaData = mangaResponse.data['data'];
      final attrs = mangaData?['attributes'] as Map<String, dynamic>? ?? {};
      final count = attrs['chapterCount'] as int?;
      Logger.debug('Kitsu manga $mangaId chapterCount=$count');
      return count;
    } catch (e) {
      Logger.warning('Kitsu chapter count lookup failed for $mangaId: $e');
      return null;
    }
  }

  /// Public getter used by aggregators needing chapter totals
  Future<int?> getChapterCount(String mangaId) => _getChapterCount(mangaId);

  Future<ChapterPageResult> getChapterPage({
    required String mangaId,
    int offset = 0,
    int limit = 20,
  }) async {
    final uri = Uri.parse('${_dio.options.baseUrl}/manga/$mangaId/chapters')
        .replace(
          queryParameters: {
            'page[limit]': '$limit',
            'page[offset]': '$offset',
            'sort': 'number',
          },
        );

    try {
      final page = await _fetchChapterPage(uri);
      final nextOffset = _extractOffsetFromLink(page.nextLink);
      return ChapterPageResult(
        chapters: page.data
            .map((e) => _mapChapter(e as Map<String, dynamic>, mangaId))
            .toList(),
        nextOffset: nextOffset,
        providerId: 'kitsu',
        providerMediaId: mangaId,
      );
    } on DioException catch (e) {
      final fallback = await _fetchChapterPageWithFallback(
        mangaId,
        originalUri: uri,
        exception: e,
      );

      if (fallback == null) {
        rethrow;
      }

      final nextOffset = _extractOffsetFromLink(fallback.nextLink);
      return ChapterPageResult(
        chapters: fallback.data
            .map((e) => _mapChapter(e as Map<String, dynamic>, mangaId))
            .toList(),
        nextOffset: nextOffset,
        providerId: 'kitsu',
        providerMediaId: mangaId,
      );
    }
  }

  int? _extractOffsetFromLink(String? link) {
    if (link == null) return null;
    final uri = Uri.tryParse(link);
    if (uri == null) return null;
    final offsetParam = uri.queryParameters['page[offset]'];
    if (offsetParam == null) return null;
    return int.tryParse(offsetParam);
  }

  Future<List<ChapterEntity>> _fetchChaptersPaged(
    String mangaId, {
    int? maxTotal,
  }) async {
    const pageLimit = 20;
    final maxChapters = maxTotal ?? 400;
    final chapters = <ChapterEntity>[];

    Uri? nextUri = Uri.parse('${_dio.options.baseUrl}/manga/$mangaId/chapters')
        .replace(
          queryParameters: {
            'page[limit]': '$pageLimit',
            'page[offset]': '0',
            'sort': 'number',
          },
        );

    while (nextUri != null) {
      final currentUri = nextUri;
      try {
        final page = await _fetchChapterPage(currentUri);

        if (page.data.isEmpty) {
          break;
        }

        chapters.addAll(page.data.map((ch) => _mapChapter(ch, mangaId)));

        if (page.nextLink == null || page.nextLink!.isEmpty) {
          nextUri = null;
        } else {
          try {
            nextUri = Uri.parse(page.nextLink!);
          } catch (e) {
            Logger.warning('Invalid Kitsu next link: ${page.nextLink}');
            nextUri = null;
          }
        }
        if (chapters.length >= maxChapters) {
          nextUri = null;
        }
      } on DioException catch (relationshipError) {
        // Attempt fallback to legacy /chapters endpoint
        Logger.warning(
          'Kitsu chapters request failed for $mangaId at $nextUri: ${relationshipError.message}',
        );
        final fallback = await _fetchChapterPageWithFallback(
          mangaId,
          originalUri: currentUri,
          exception: relationshipError,
        );

        if (fallback == null || fallback.data.isEmpty) {
          return [];
        }

        chapters.addAll(fallback.data.map((ch) => _mapChapter(ch, mangaId)));
        if (fallback.nextLink == null || fallback.nextLink!.isEmpty) {
          nextUri = null;
        } else {
          try {
            nextUri = Uri.parse(fallback.nextLink!);
          } catch (e) {
            Logger.warning(
              'Invalid Kitsu next link from fallback: ${fallback.nextLink}',
            );
            nextUri = null;
          }
        }
        if (chapters.length >= maxChapters) {
          nextUri = null;
        }
      } catch (e) {
        Logger.warning(
          'Kitsu chapters page fetch failed for $mangaId at $nextUri: $e',
        );
        return [];
      }
    }

    Logger.info('Kitsu fetched ${chapters.length} chapters for $mangaId');
    return chapters;
  }

  Future<_KitsuChapterPage> _fetchChapterPage(Uri uri) async {
    Logger.debug('Kitsu chapters request: $uri');
    final response = await _dio.getUri(uri);
    return _parseKitsuChapterResponse(response);
  }

  Future<_KitsuChapterPage?> _fetchChapterPageWithFallback(
    String mangaId, {
    required Uri originalUri,
    required DioException exception,
  }) async {
    Logger.debug(
      'Kitsu manga/$mangaId/chapters request failed: ${exception.message}. Response: ${exception.response?.data}. Trying fallback filters.',
    );

    final fallbackFilters = ['filter[mangaId]', 'filter[manga_id]'];

    for (final filterKey in fallbackFilters) {
      try {
        final fallbackParams = Map<String, String>.from(
          originalUri.queryParameters,
        );
        fallbackParams[filterKey] = mangaId;
        final fallbackUri = Uri.parse(
          '${_dio.options.baseUrl}/chapters',
        ).replace(queryParameters: fallbackParams);
        Logger.debug(
          'Kitsu chapters fallback request ($filterKey): $fallbackUri',
        );
        final response = await _dio.getUri(fallbackUri);
        Logger.debug(
          'Kitsu chapters fallback succeeded for $mangaId using $filterKey',
        );
        return _parseKitsuChapterResponse(response);
      } on DioException catch (e) {
        Logger.debug(
          'Kitsu chapters fallback attempt failed for $mangaId using $filterKey: ${e.message}. Response: ${e.response?.data}',
        );
      }
    }

    return null;
  }

  _KitsuChapterPage _parseKitsuChapterResponse(Response response) {
    final data = response.data['data'] as List? ?? [];
    final links = response.data['links'] as Map<String, dynamic>?;
    final nextLink = links?['next'] as String?;
    return _KitsuChapterPage(data: data, nextLink: nextLink);
  }

  double safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  ChapterEntity _mapChapter(Map<String, dynamic> json, String mangaId) {
    final chMap = json;
    final attrs = chMap['attributes'] as Map<String, dynamic>? ?? {};
    final titlesObj = attrs['titles'] as Map<String, dynamic>?;

    return ChapterEntity(
      id: chMap['id']?.toString() ?? '',
      mediaId: mangaId,
      number: safeToDouble(attrs['number']),
      title:
          attrs['canonicalTitle']?.toString() ??
          titlesObj?['en_jp']?.toString() ??
          titlesObj?['en']?.toString() ??
          'Chapter ${attrs['number'] ?? 0}',
      releaseDate: attrs['published'] != null
          ? DateTime.tryParse(attrs['published'].toString())
          : null,
      pageCount: null,
      sourceProvider: 'kitsu',
    );
  }

  List<ChapterEntity> _generatePlaceholderChapters(
    String mangaId,
    int totalChapters,
  ) {
    return List.generate(totalChapters, (index) {
      final chapterNum = index + 1;
      return ChapterEntity(
        id: 'kitsu_chapter_${mangaId}_$chapterNum',
        mediaId: mangaId,
        number: chapterNum.toDouble(),
        title: 'Chapter $chapterNum',
        releaseDate: null,
        pageCount: null,
        sourceProvider: 'kitsu',
      );
    });
  }

  // Mapping functions

  MediaEntity _mapToMediaEntity(
    Map<String, dynamic> json,
    MediaType type,
    String sourceId,
    String sourceName,
  ) {
    final attrs = json['attributes'] as Map<String, dynamic>? ?? {};
    final titlesObj = attrs['titles'] as Map<String, dynamic>?;
    final posterObj = attrs['posterImage'] as Map<String, dynamic>?;
    final coverObj = attrs['coverImage'] as Map<String, dynamic>?;

    // Safe type conversion
    int? safeToInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    // Safe rating conversion (Kitsu uses 0-100 scale as string)
    double safeRating(dynamic rating) {
      if (rating == null) return 0.0;
      final parsed = double.tryParse(rating.toString());
      return parsed != null ? parsed / 10.0 : 0.0;
    }

    return MediaEntity(
      id: json['id']?.toString() ?? '',
      title:
          attrs['canonicalTitle']?.toString() ??
          titlesObj?['en_jp']?.toString() ??
          titlesObj?['en']?.toString() ??
          '',
      coverImage: posterObj?['medium'] ?? posterObj?['small'],
      bannerImage: coverObj?['original'] ?? coverObj?['large'],
      description:
          attrs['synopsis']?.toString() ?? attrs['description']?.toString(),
      type: type,
      rating: safeRating(attrs['averageRating']),
      genres: [], // Genres require separate API call in Kitsu
      status: _mapKitsuStatus(attrs['status']?.toString()),
      totalEpisodes: safeToInt(attrs['episodeCount']),
      totalChapters: safeToInt(attrs['chapterCount']),
      sourceId: sourceId,
      sourceName: sourceName,
    );
  }

  MediaDetailsEntity _mapToAnimeDetailsEntity(
    Map<String, dynamic> json,
    List<CharacterEntity>? characters,
    List<StaffEntity>? staff,
    List<ReviewEntity>? reviews,
    List<RecommendationEntity>? recommendations, {
    List<String>? genres,
    List<StudioEntity>? studios,
  }) {
    final attrs = json['attributes'] as Map<String, dynamic>? ?? {};
    final titlesObj = attrs['titles'] as Map<String, dynamic>?;
    final posterObj = attrs['posterImage'] as Map<String, dynamic>?;
    final coverObj = attrs['coverImage'] as Map<String, dynamic>?;

    // Safe type conversion
    int? safeToInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    // Safe rating conversion (Kitsu uses 0-100 scale as string)
    double safeRating(dynamic rating) {
      if (rating == null) return 0.0;
      final parsed = double.tryParse(rating.toString());
      return parsed != null ? parsed / 10.0 : 0.0;
    }

    // Parse dates
    DateTime? startDate;
    DateTime? endDate;
    try {
      if (attrs['startDate'] != null) {
        startDate = DateTime.parse(attrs['startDate'].toString());
      }
      if (attrs['endDate'] != null) {
        endDate = DateTime.parse(attrs['endDate'].toString());
      }
    } catch (e) {
      // Invalid dates
    }

    return MediaDetailsEntity(
      id: json['id']?.toString() ?? '',
      title:
          attrs['canonicalTitle']?.toString() ??
          titlesObj?['en_jp']?.toString() ??
          titlesObj?['en']?.toString() ??
          '',
      englishTitle: titlesObj?['en']?.toString(),
      romajiTitle: titlesObj?['en_jp']?.toString(),
      nativeTitle: titlesObj?['ja_jp']?.toString(),
      coverImage: posterObj?['large'] ?? posterObj?['medium'] ?? '',
      bannerImage: coverObj?['original'] ?? coverObj?['large'],
      description:
          attrs['synopsis']?.toString() ?? attrs['description']?.toString(),
      type: MediaType.anime,
      status: _mapKitsuStatus(attrs['status']?.toString()),
      rating: safeRating(attrs['averageRating']),
      averageScore: attrs['averageRating'] != null
          ? (double.tryParse(attrs['averageRating'].toString())?.toInt())
          : null,
      popularity: safeToInt(attrs['userCount']),
      favorites: safeToInt(attrs['favoritesCount']),
      genres: genres ?? [],
      tags: [],
      startDate: startDate,
      endDate: endDate,
      episodes: safeToInt(attrs['episodeCount']),
      chapters: null,
      volumes: null,
      duration: safeToInt(attrs['episodeLength']),
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
      studios: studios,
      rankings: null,
      trailer: attrs['youtubeVideoId'] != null
          ? TrailerEntity(
              id: attrs['youtubeVideoId']?.toString() ?? '',
              site: 'youtube',
            )
          : null,
    );
  }

  MediaDetailsEntity _mapToMangaDetailsEntity(
    Map<String, dynamic> json,
    List<CharacterEntity>? characters,
    List<StaffEntity>? staff,
    List<ReviewEntity>? reviews,
    List<RecommendationEntity>? recommendations, {
    List<String>? genres,
  }) {
    final attrs = json['attributes'] as Map<String, dynamic>? ?? {};
    final titlesObj = attrs['titles'] as Map<String, dynamic>?;
    final posterObj = attrs['posterImage'] as Map<String, dynamic>?;
    final coverObj = attrs['coverImage'] as Map<String, dynamic>?;

    // Safe type conversion
    int? safeToInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    // Safe rating conversion (Kitsu uses 0-100 scale as string)
    double safeRating(dynamic rating) {
      if (rating == null) return 0.0;
      final parsed = double.tryParse(rating.toString());
      return parsed != null ? parsed / 10.0 : 0.0;
    }

    // Parse dates
    DateTime? startDate;
    DateTime? endDate;
    try {
      if (attrs['startDate'] != null) {
        startDate = DateTime.parse(attrs['startDate'].toString());
      }
      if (attrs['endDate'] != null) {
        endDate = DateTime.parse(attrs['endDate'].toString());
      }
    } catch (e) {
      // Invalid dates
    }

    return MediaDetailsEntity(
      id: json['id']?.toString() ?? '',
      title:
          attrs['canonicalTitle']?.toString() ??
          titlesObj?['en_jp']?.toString() ??
          titlesObj?['en']?.toString() ??
          '',
      englishTitle: titlesObj?['en']?.toString(),
      romajiTitle: titlesObj?['en_jp']?.toString(),
      nativeTitle: titlesObj?['ja_jp']?.toString(),
      coverImage: posterObj?['large'] ?? posterObj?['medium'] ?? '',
      bannerImage: coverObj?['original'] ?? coverObj?['large'],
      description:
          attrs['synopsis']?.toString() ?? attrs['description']?.toString(),
      type: MediaType.manga,
      status: _mapKitsuStatus(attrs['status']?.toString()),
      rating: safeRating(attrs['averageRating']),
      averageScore: attrs['averageRating'] != null
          ? (double.tryParse(attrs['averageRating'].toString())?.toInt())
          : null,
      popularity: safeToInt(attrs['userCount']),
      favorites: safeToInt(attrs['favoritesCount']),
      genres: genres ?? [],
      tags: [],
      startDate: startDate,
      endDate: endDate,
      episodes: null,
      chapters: safeToInt(attrs['chapterCount']),
      volumes: safeToInt(attrs['volumeCount']),
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
