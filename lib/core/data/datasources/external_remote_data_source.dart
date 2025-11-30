import 'dart:math' as math;

import '../../domain/entities/media_entity.dart';
import '../../domain/entities/media_details_entity.dart' hide SearchResult;
import '../../domain/entities/episode_entity.dart';
import '../../domain/entities/chapter_entity.dart';
import '../../domain/entities/chapter_page_result.dart';
import '../../domain/entities/episode_page_result.dart';
import '../../domain/entities/search_result_entity.dart';
import '../../error/exceptions.dart';
import '../../utils/logger.dart';
import '../../utils/cross_provider_matcher.dart';
import '../../utils/data_aggregator.dart';
import '../../utils/provider_cache.dart';
import 'tmdb_external_data_source.dart';
import 'anilist_external_data_source.dart';
import 'simkl_external_data_source.dart';
import 'jikan_external_data_source.dart';
import 'kitsu_external_data_source.dart';

class ExternalRemoteDataSource {
  static const _aggregatedProviderId = 'aggregated';
  final TmdbExternalDataSourceImpl _tmdbDataSource;
  final AnilistExternalDataSourceImpl _anilistDataSource;
  final SimklExternalDataSourceImpl _simklDataSource;
  final JikanExternalDataSourceImpl _jikanDataSource;
  final KitsuExternalDataSourceImpl _kitsuDataSource;
  final CrossProviderMatcher _matcher;
  final DataAggregator _aggregator;
  final ProviderCache _cache;

  ExternalRemoteDataSource({
    TmdbExternalDataSourceImpl? tmdbDataSource,
    AnilistExternalDataSourceImpl? anilistDataSource,
    SimklExternalDataSourceImpl? simklDataSource,
    JikanExternalDataSourceImpl? jikanDataSource,
    KitsuExternalDataSourceImpl? kitsuDataSource,
    CrossProviderMatcher? matcher,
    DataAggregator? aggregator,
    ProviderCache? cache,
  }) : _tmdbDataSource = tmdbDataSource ?? TmdbExternalDataSourceImpl(),
       _anilistDataSource =
           anilistDataSource ?? AnilistExternalDataSourceImpl(),
       _simklDataSource = simklDataSource ?? SimklExternalDataSourceImpl(),
       _jikanDataSource = jikanDataSource ?? JikanExternalDataSourceImpl(),
       _kitsuDataSource = kitsuDataSource ?? KitsuExternalDataSourceImpl(),
       _matcher = matcher ?? CrossProviderMatcher(),
       _aggregator = aggregator ?? DataAggregator(),
       _cache = cache ?? ProviderCache() {
    // Initialize cache
    _cache.init().catchError((error) {
      Logger.error('Failed to initialize provider cache', error: error);
    });
  }

  Future<EpisodePageResult> _buildAggregatedEpisodePage(
    EpisodePageRequest request,
  ) async {
    final limit = request.limit <= 0 ? 50 : request.limit;
    final safeOffset = request.offset < 0 ? 0 : request.offset;

    try {
      final aggregatedEpisodes = await getEpisodes(request.media);
      if (aggregatedEpisodes.isEmpty ||
          safeOffset >= aggregatedEpisodes.length) {
        return EpisodePageResult(
          episodes: const [],
          nextOffset: null,
          providerId: _aggregatedProviderId,
          providerMediaId: request.media.id,
        );
      }

      final end = math.min(safeOffset + limit, aggregatedEpisodes.length);
      final pageEpisodes = aggregatedEpisodes.sublist(safeOffset, end);
      final nextOffset = end < aggregatedEpisodes.length ? end : null;

      return EpisodePageResult(
        episodes: pageEpisodes,
        nextOffset: nextOffset,
        providerId: _aggregatedProviderId,
        providerMediaId: request.media.id,
      );
    } catch (e, stackTrace) {
      Logger.error(
        'Aggregated episode paging failed',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  MediaEntity? _selectBestProviderMatch({
    required MediaEntity primary,
    required List<MediaEntity> candidates,
    required String providerId,
  }) {
    if (candidates.isEmpty) return null;

    MediaEntity? best;
    double bestScore = -1;
    final primaryYear = primary.startDate?.year;
    final primaryEpisodes = primary.totalEpisodes;

    for (final candidate in candidates) {
      var score = _matcher.calculateMatchConfidence(
        sourceTitle: primary.title,
        targetTitle: candidate.title,
        sourceEnglishTitle: null,
        targetEnglishTitle: null,
        sourceRomajiTitle: null,
        targetRomajiTitle: null,
        sourceYear: primaryYear,
        targetYear: candidate.startDate?.year,
        sourceType: primary.type,
        targetType: candidate.type,
      );

      if (primaryYear != null && candidate.startDate?.year != null) {
        final diff = (primaryYear - candidate.startDate!.year).abs();
        if (diff >= 15) {
          // Live-action remakes usually fall here; skip entirely
          Logger.debug(
            'Skipping ${candidate.title} due to large year gap ($diff years)',
          );
          continue;
        } else if (diff >= 10) {
          score -= 0.2;
        } else if (diff >= 5) {
          score -= 0.1;
        } else if (diff >= 3) {
          score -= 0.05;
        }
      }

      if (primaryEpisodes != null && primaryEpisodes > 0) {
        final candidateEpisodes = candidate.totalEpisodes ?? 0;
        if (candidateEpisodes == 0) {
          score -= 0.15;
        } else {
          final diff = (primaryEpisodes - candidateEpisodes).abs();
          final ratio = diff / primaryEpisodes;
          if (primaryEpisodes >= 100 && ratio >= 0.5) {
            Logger.debug(
              'Skipping ${candidate.title} due to large episode mismatch (${candidateEpisodes} vs $primaryEpisodes)',
            );
            continue;
          }

          if (ratio <= 0.05) {
            score += 0.15;
          } else if (ratio <= 0.15) {
            score += 0.08;
          } else if (ratio <= 0.3) {
            score += 0.02;
          } else {
            score -= 0.08;
          }
        }
      }

      if (score > bestScore) {
        bestScore = score;
        best = candidate;
      }
    }

    if (best != null) {
      final bestTitle = best.title;
      Logger.info(
        'Selected $bestTitle (score: ${bestScore.toStringAsFixed(2)}) from $providerId fallback candidates',
      );
    }

    return best ?? candidates.first;
  }

  Future<void> _invalidateEpisodeMatchCache(MediaEntity media) async {
    for (final year in <int?>{null, media.startDate?.year}) {
      try {
        await _matcher.invalidateCachedMatches(
          title: media.title,
          englishTitle: null,
          romajiTitle: null,
          year: year,
          type: media.type,
          primarySourceId: media.sourceId,
          cache: _cache,
        );
      } catch (e) {
        Logger.warning(
          'Failed to invalidate cached matches for ${media.title} (year=$year): $e',
        );
      }
    }
  }

  Future<EpisodePageResult> getEpisodePage(EpisodePageRequest request) async {
    final media = request.media;
    var providerId = request.providerId;
    var providerMediaId = request.providerMediaId;

    if (providerId?.toLowerCase() == _aggregatedProviderId) {
      return _buildAggregatedEpisodePage(request);
    }

    if (providerId == null || providerMediaId == null) {
      final primarySource = media.sourceId.toLowerCase();
      if (primarySource == 'jikan' ||
          primarySource == 'mal' ||
          primarySource == 'myanimelist' ||
          primarySource == 'anilist' ||
          primarySource == 'kitsu') {
        // Route MAL/MyAnimeList to Jikan (unofficial MAL API)
        providerId = (primarySource == 'mal' || primarySource == 'myanimelist')
            ? 'jikan'
            : primarySource;
        providerMediaId = media.id;
      } else {
        final matches = await _matcher.findMatches(
          title: media.title,
          type: media.type,
          primarySourceId: media.sourceId,
          searchFunction: searchMedia,
          cache: _cache,
        );

        for (final candidate in ['jikan', 'kitsu', 'anilist']) {
          final match = matches[candidate];
          if (match != null) {
            providerId = candidate;
            providerMediaId = match.providerMediaId;
            break;
          }
        }
      }
    }

    if (providerId == null || providerMediaId == null) {
      Logger.warning(
        'Episode paging provider could not be resolved, falling back to aggregation',
      );
      return _buildAggregatedEpisodePage(request);
    }

    try {
      switch (providerId.toLowerCase()) {
        case 'jikan':
          final result = await _jikanDataSource.getEpisodePage(
            id: providerMediaId,
            offset: request.offset,
            limit: request.limit,
            coverImage: media.coverImage,
          );
          return EpisodePageResult(
            episodes: result.episodes,
            nextOffset: result.nextOffset,
            providerId: providerId,
            providerMediaId: providerMediaId,
          );
        case 'anilist':
          final result = await _anilistDataSource.getEpisodePage(
            id: providerMediaId,
            offset: request.offset,
            limit: request.limit,
          );
          return result;
        case 'kitsu':
          final result = await _kitsuDataSource.getEpisodePage(
            animeId: providerMediaId,
            offset: request.offset,
            limit: request.limit,
            coverImage: media.coverImage,
          );
          return result;
        default:
          Logger.warning(
            'Episode paging not implemented for provider $providerId, using aggregation fallback',
          );
          break;
      }
    } catch (e, stackTrace) {
      Logger.warning(
        'Episode paging via provider $providerId failed, falling back to aggregation',
      );
      Logger.error(
        'Episode paging failure details',
        error: e,
        stackTrace: stackTrace,
      );
    }

    return _buildAggregatedEpisodePage(request);
  }

  Future<ChapterPageResult> getChapterPage(ChapterPageRequest request) async {
    final media = request.media;
    var providerId = request.providerId;
    var providerMediaId = request.providerMediaId;

    if (providerId == null || providerMediaId == null) {
      if (media.sourceId.toLowerCase() == 'kitsu') {
        providerId = 'kitsu';
        providerMediaId = media.id;
      } else {
        final matches = await _matcher.findMatches(
          title: media.title,
          type: media.type,
          primarySourceId: media.sourceId,
          searchFunction: searchMedia,
          cache: _cache,
        );

        final kitsuMatch = matches['kitsu'];
        if (kitsuMatch != null) {
          providerId = 'kitsu';
          providerMediaId = kitsuMatch.providerMediaId;
        }
      }
    }

    if (providerId == null || providerMediaId == null) {
      throw ServerException('No provider available for chapter paging');
    }

    switch (providerId.toLowerCase()) {
      case 'kitsu':
        final result = await _kitsuDataSource.getChapterPage(
          mangaId: providerMediaId,
          offset: request.offset,
          limit: request.limit,
        );
        return ChapterPageResult(
          chapters: result.chapters,
          nextOffset: result.nextOffset,
          providerId: providerId,
          providerMediaId: providerMediaId,
        );
      default:
        throw ServerException('Chapter paging not supported for $providerId');
    }
  }

  int? _getBestKnownChapterCount(
    MediaEntity media,
    Map<String, ProviderMatch> matches,
  ) {
    if (media.totalChapters != null && media.totalChapters! > 0) {
      return media.totalChapters;
    }

    int? best;
    String? bestProvider;

    for (final entry in matches.entries) {
      final candidate = entry.value.mediaEntity?.totalChapters;
      if (candidate != null && candidate > 0) {
        if (best == null || candidate > best) {
          best = candidate;
          bestProvider = entry.key;
        }
      }
    }

    if (best != null) {
      Logger.info(
        'Best known chapter count $best sourced from ${bestProvider ?? 'unknown provider'}',
      );
    }

    return best;
  }

  /// Get data source by source ID
  dynamic _getDataSource(String sourceId) {
    switch (sourceId.toLowerCase()) {
      case 'tmdb':
        return _tmdbDataSource;
      case 'anilist':
        return _anilistDataSource;
      case 'simkl':
        return _simklDataSource;
      case 'jikan':
      case 'mal':
      case 'myanimelist':
        // Jikan is the unofficial MyAnimeList API
        return _jikanDataSource;
      case 'kitsu':
        return _kitsuDataSource;
      default:
        throw ServerException('Unsupported external source: $sourceId');
    }
  }

  Future<List<MediaEntity>> searchMedia(
    String query,
    String sourceId,
    MediaType type, {
    int page = 1,
    int? year,
  }) async {
    try {
      final dataSource = _getDataSource(sourceId);
      final result = await dataSource.searchMedia(
        query,
        type,
        page: page,
        year: year,
      );
      // Handle both SearchResult and plain List return types
      if (result is SearchResult<List<MediaEntity>>) {
        return result.items;
      } else if (result is List<MediaEntity>) {
        return result;
      }
      // Fallback: try to access items property
      return (result as dynamic).items as List<MediaEntity>;
    } catch (e) {
      Logger.error('External search failed for source $sourceId', error: e);
      rethrow;
    }
  }

  /// Advanced search with filtering and pagination
  Future<SearchResult<List<MediaEntity>>> searchMediaAdvanced(
    String query,
    String sourceId,
    MediaType type, {
    List<String>? genres,
    int? year,
    String? season,
    String? status,
    String? format,
    int? minScore,
    int? maxScore,
    String? sort,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      Logger.info(
        'ExternalRemoteDataSource.searchMediaAdvanced: sourceId=$sourceId, type=$type, query="$query"',
        tag: 'ExternalRemoteDataSource',
      );

      final dataSource = _getDataSource(sourceId);
      Logger.debug(
        'Got data source for $sourceId: ${dataSource.runtimeType}',
        tag: 'ExternalRemoteDataSource',
      );

      final result = await dataSource.searchMedia(
        query,
        type,
        genres: genres,
        year: year,
        season: season,
        status: status,
        format: format,
        minScore: minScore,
        maxScore: maxScore,
        sort: sort,
        page: page,
        perPage: perPage,
      );

      Logger.info(
        'ExternalRemoteDataSource.searchMediaAdvanced completed: ${result.items.length} results',
        tag: 'ExternalRemoteDataSource',
      );

      return result;
    } catch (e, stackTrace) {
      Logger.error(
        'External advanced search failed for source $sourceId',
        tag: 'ExternalRemoteDataSource',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<List<MediaEntity>> getTrending(
    String sourceId,
    MediaType type, {
    int page = 1,
  }) async {
    try {
      final dataSource = _getDataSource(sourceId);
      return await dataSource.getTrending(type, page: page);
    } catch (e) {
      Logger.error('External trending failed for source $sourceId', error: e);
      rethrow;
    }
  }

  Future<List<MediaEntity>> getPopular(
    String sourceId,
    MediaType type, {
    int page = 1,
  }) async {
    try {
      final dataSource = _getDataSource(sourceId);
      return await dataSource.getPopular(type, page: page);
    } catch (e) {
      Logger.error('External popular failed for source $sourceId', error: e);
      rethrow;
    }
  }

  Future<MediaDetailsEntity> getMediaDetails(
    String id,
    String sourceId,
    MediaType type, {
    bool includeCharacters = true,
    bool includeStaff = true,
    bool includeReviews = false,
  }) async {
    try {
      final dataSource = _getDataSource(sourceId);
      var details = await dataSource.getMediaDetails(
        id,
        type,
        includeCharacters: includeCharacters,
        includeStaff: includeStaff,
        includeReviews: includeReviews,
      );

      // Unified Data Strategy: Supplement missing images
      // Priority: TMDB > Kitsu > AniList
      if (details.bannerImage == null || details.coverImage.isEmpty) {
        // Try TMDB first (best for high-res images)
        if (sourceId != 'tmdb') {
          final match = await _findMatchInSource(details.title, type, 'tmdb');
          if (match != null) {
            details = details.copyWith(
              bannerImage: details.bannerImage ?? match.bannerImage,
              coverImage: details.coverImage.isEmpty
                  ? match.coverImage ?? ''
                  : details.coverImage,
            );
          }
        }

        // If still missing banner, try Kitsu
        if (details.bannerImage == null && sourceId != 'kitsu') {
          final match = await _findMatchInSource(details.title, type, 'kitsu');
          if (match != null) {
            details = details.copyWith(
              bannerImage: details.bannerImage ?? match.bannerImage,
              coverImage: details.coverImage.isEmpty
                  ? match.coverImage ?? ''
                  : details.coverImage,
            );
          }
        }
      }

      return details;
    } catch (e) {
      Logger.error(
        'External get details failed for source $sourceId',
        error: e,
      );
      rethrow;
    }
  }

  Future<MediaEntity?> _findMatchInSource(
    String title,
    MediaType type,
    String targetSourceId,
  ) async {
    try {
      // Map anime to TV shows for TMDB compatibility
      final searchType = (targetSourceId == 'tmdb' && type == MediaType.anime)
          ? MediaType.tvShow
          : type;
      final results = await searchMedia(title, targetSourceId, searchType);
      if (results.isNotEmpty) {
        // Simple matching: return first result
        // TODO: Implement better matching (e.g. Levenshtein distance)
        return results.first;
      }
    } catch (e) {
      Logger.error('Failed to find match in $targetSourceId', error: e);
    }
    return null;
  }

  Future<List<EpisodeEntity>> getEpisodes(MediaEntity media) async {
    Logger.info('Fetching episodes for ${media.title} from ${media.sourceId}');

    // Use CrossProviderMatcher to find matches across all providers
    var matches = await _matcher.findMatches(
      title: media.title,
      type: media.type,
      primarySourceId: media.sourceId,
      searchFunction: searchMedia,
      cache: _cache,
    );

    // Ensure AniList is always included for anime episodes (it has good episode data)
    // This helps when the cache doesn't have AniList or when other providers fail
    Logger.info(
      'AniList fallback check: type=${media.type}, sourceId=${media.sourceId}, hasAniList=${matches.containsKey('anilist')}, matchKeys=${matches.keys.toList()}',
    );
    if (media.type == MediaType.anime &&
        media.sourceId != 'anilist' &&
        !matches.containsKey('anilist')) {
      Logger.info(
        'Attempting to add AniList as fallback provider for "${media.title}"',
      );
      try {
        final anilistResults = await searchMedia(
          media.title,
          'anilist',
          media.type,
        );
        Logger.info('AniList search returned ${anilistResults.length} results');
        if (anilistResults.isNotEmpty) {
          final anilistMatch = anilistResults.first;
          matches = Map.from(matches);
          matches['anilist'] = ProviderMatch(
            providerId: 'anilist',
            providerMediaId: anilistMatch.id,
            confidence: 0.85,
            matchedTitle: anilistMatch.title,
            mediaEntity: anilistMatch,
          );
          Logger.info(
            'Added AniList as fallback provider for episodes (ID: ${anilistMatch.id})',
          );
        } else {
          Logger.warning('No AniList results found for "${media.title}"');
        }
      } catch (e) {
        Logger.warning('Could not add AniList as fallback: $e');
      }
    }

    // Ensure TMDB is included for anime items
    if (media.type == MediaType.anime && media.sourceId != 'tmdb') {
      final existingTmdbMatch = matches['tmdb'];
      if (existingTmdbMatch != null) {
        final entity = existingTmdbMatch.mediaEntity;
        final candidateEpisodes = entity?.totalEpisodes ?? 0;
        final primaryEpisodes = media.totalEpisodes ?? 0;
        final yearDiff =
            (media.startDate?.year != null && entity?.startDate?.year != null)
            ? (media.startDate!.year - entity!.startDate!.year).abs()
            : null;

        bool forceRefresh = false;

        if (entity == null) {
          Logger.warning(
            'Cached TMDB mapping has no metadata (likely stale cache). Dropping and re-searching.',
          );
          forceRefresh = true;
        } else {
          final episodesMismatch =
              candidateEpisodes > 0 &&
              primaryEpisodes > 0 &&
              primaryEpisodes >= 100 &&
              (primaryEpisodes - candidateEpisodes).abs() >=
                  (primaryEpisodes * 0.5);
          final yearMismatch = yearDiff != null && yearDiff >= 10;
          if (episodesMismatch || yearMismatch) {
            Logger.warning(
              'Cached TMDB mapping looks like a live-action mismatch (episodes: $candidateEpisodes, year diff: ${yearDiff ?? 'unknown'}). Dropping and re-searching.',
            );
            forceRefresh = true;
          }
        }

        if (forceRefresh) {
          matches = Map.from(matches)..remove('tmdb');
          await _invalidateEpisodeMatchCache(media);
        } else {
          Logger.info('Reusing cached TMDB mapping for episodes aggregation');
        }
      }

      if (!matches.containsKey('tmdb')) {
        Logger.info(
          'Attempting to add TMDB as fallback provider for "${media.title}"',
        );
        try {
          final tmdbResults = await searchMedia(
            media.title,
            'tmdb',
            MediaType.tvShow, // Search TMDB as TV shows for anime
            year: media.startDate?.year,
          );
          Logger.info('TMDB search returned ${tmdbResults.length} results');
          final tmdbMatch = _selectBestProviderMatch(
            primary: media,
            candidates: tmdbResults,
            providerId: 'tmdb',
          );
          if (tmdbMatch != null) {
            matches = Map.from(matches);
            matches['tmdb'] = ProviderMatch(
              providerId: 'tmdb',
              providerMediaId: tmdbMatch.id,
              confidence: 0.85,
              matchedTitle: tmdbMatch.title,
              mediaEntity: tmdbMatch,
            );
            Logger.info(
              'Added TMDB as fallback provider for episodes (ID: ${tmdbMatch.id})',
            );
          } else {
            Logger.warning('No TMDB results found for "${media.title}"');
          }
        } catch (e) {
          Logger.warning('Could not add TMDB as fallback: $e');
        }
      }
    }

    Logger.info(
      'Found ${matches.length} high-confidence matches for episode aggregation: ${matches.keys.toList()}',
    );

    // Use DataAggregator to merge episodes from all providers
    // This implements the fallback strategy: Kitsu → AniList → Jikan
    // Pass the cover image to avoid extra API calls
    final aggregatedEpisodes = await _aggregator.aggregateEpisodes(
      primaryMedia: media,
      matches: matches,
      episodeFetcher: (mediaId, providerId) {
        // Get cover image from primary media or matched provider
        String? coverImage;
        if (providerId == media.sourceId) {
          coverImage = media.coverImage;
        } else if (matches.containsKey(providerId)) {
          coverImage = matches[providerId]?.mediaEntity?.coverImage;
        }
        return _fetchEpisodesFromProvider(
          mediaId,
          providerId,
          coverImage: coverImage,
        );
      },
    );

    Logger.info(
      'Aggregated ${aggregatedEpisodes.length} episodes for ${media.title}',
    );

    return aggregatedEpisodes;
  }

  /// Fetch episodes from a specific provider
  ///
  /// This is a helper method used by DataAggregator to fetch episodes
  /// from individual providers. It handles provider-specific logic and
  /// error handling.
  Future<List<EpisodeEntity>> _fetchEpisodesFromProvider(
    String mediaId,
    String providerId, {
    String? coverImage,
  }) async {
    try {
      final dataSource = _getDataSource(providerId);

      // Only fetch episodes from providers that support them
      // Pass cover image when available to avoid extra API calls
      if (dataSource is KitsuExternalDataSourceImpl) {
        return await dataSource.getEpisodes(mediaId, coverImage: coverImage);
      } else if (dataSource is AnilistExternalDataSourceImpl) {
        Logger.info('Fetching episodes from AniList for media ID: $mediaId');
        final episodes = await dataSource.getEpisodes(mediaId);
        Logger.info('AniList returned ${episodes.length} episodes');
        return episodes;
      } else if (dataSource is JikanExternalDataSourceImpl) {
        return await dataSource.getEpisodes(mediaId, coverImage: coverImage);
      } else if (dataSource is TmdbExternalDataSourceImpl) {
        Logger.info('Fetching episodes from TMDB for media ID: $mediaId');
        final episodes = await dataSource.getEpisodes(mediaId);
        Logger.info('TMDB returned ${episodes.length} episodes');
        return episodes;
      }

      // Provider doesn't support episodes
      return [];
    } catch (e) {
      Logger.error(
        'Failed to fetch episodes from provider $providerId',
        error: e,
      );
      return [];
    }
  }

  /// Fetch chapters from a specific provider
  ///
  /// This is a helper method used by DataAggregator to fetch chapters
  /// from individual providers. It handles provider-specific logic and
  /// error handling.
  ///
  /// Note: Most manga APIs don't provide chapter-level data. We generate
  /// placeholder chapters based on the manga's total chapter count.
  Future<List<ChapterEntity>> _fetchChaptersFromProvider(
    String mediaId,
    String providerId,
  ) async {
    try {
      final dataSource = _getDataSource(providerId);

      // Fetch chapters from providers that support them
      if (dataSource is KitsuExternalDataSourceImpl) {
        Logger.info('Fetching chapters from Kitsu for manga ID: $mediaId');
        final chapters = await dataSource.getChapters(mediaId);
        Logger.info('Kitsu returned ${chapters.length} chapters');
        return chapters;
      } else if (dataSource is AnilistExternalDataSourceImpl) {
        Logger.info('Fetching chapters from AniList for manga ID: $mediaId');
        final chapters = await dataSource.getChapters(mediaId);
        Logger.info('AniList returned ${chapters.length} chapters');
        return chapters;
      } else if (dataSource is JikanExternalDataSourceImpl) {
        Logger.info('Fetching chapters from Jikan for manga ID: $mediaId');
        final chapters = await dataSource.getChapters(mediaId);
        Logger.info('Jikan returned ${chapters.length} chapters');
        return chapters;
      }

      // Provider doesn't support chapters
      return [];
    } on MalAuthRequiredException {
      rethrow;
    } catch (e) {
      Logger.error(
        'Failed to fetch chapters from provider $providerId',
        error: e,
      );
      return [];
    }
  }

  Future<List<ChapterEntity>> getChapters(MediaEntity media) async {
    Logger.info('Fetching chapters for ${media.title} from ${media.sourceId}');

    try {
      // Use CrossProviderMatcher to find matches across all providers
      final matches = await _matcher.findMatches(
        title: media.title,
        type: media.type,
        primarySourceId: media.sourceId,
        searchFunction: searchMedia,
        cache: _cache,
      );

      Logger.info(
        'Found ${matches.length} high-confidence matches for chapter aggregation',
      );

      // Use DataAggregator to merge chapters from all providers
      // This implements the Kitsu-first fallback strategy
      final aggregatedChapters = await _aggregator.aggregateChapters(
        primaryMedia: media,
        matches: matches,
        chapterFetcher: _fetchChaptersFromProvider,
      );

      Logger.info(
        'Aggregated ${aggregatedChapters.length} chapters for ${media.title}',
      );

      if (aggregatedChapters.isNotEmpty) {
        return aggregatedChapters;
      }

      // Direct provider fallback when aggregation produced nothing
      List<ChapterEntity> providerFallback = [];
      final sourceKey = media.sourceId.toLowerCase();
      try {
        if (sourceKey == 'anilist') {
          providerFallback = await _anilistDataSource.getChapters(media.id);
        } else if (sourceKey == 'jikan') {
          providerFallback = await _jikanDataSource.getChapters(media.id);
        } else if (sourceKey == 'kitsu') {
          providerFallback = await _kitsuDataSource.getChapters(media.id);
        }
      } on MalAuthRequiredException {
        rethrow;
      } catch (e) {
        Logger.warning(
          'Direct chapter fallback failed for ${media.sourceId}: $e',
          tag: 'ExternalRemoteDataSource',
        );
      }

      if (providerFallback.isNotEmpty) {
        Logger.info(
          'Direct provider fallback returned ${providerFallback.length} chapters for ${media.title}',
        );
        return providerFallback;
      }

      // Final fallback: generate placeholder chapters from known totals
      final fallbackTotal = _getBestKnownChapterCount(media, matches);
      if (fallbackTotal != null && fallbackTotal > 0) {
        Logger.info(
          'Generating $fallbackTotal placeholder chapters for ${media.title} using best-known totals',
        );
        return List.generate(fallbackTotal, (index) {
          final chapterNum = index + 1;
          return ChapterEntity(
            id: '${media.sourceId}_chapter_${media.id}_$chapterNum',
            mediaId: media.id,
            number: chapterNum.toDouble(),
            title: 'Chapter $chapterNum',
            releaseDate: null,
            pageCount: null,
            sourceProvider: media.sourceId,
          );
        });
      }

      Logger.warning(
        'No chapter data available for ${media.title} (${media.sourceId}) after all fallbacks',
        tag: 'ExternalRemoteDataSource',
      );
      return [];
    } on MalAuthRequiredException {
      rethrow;
    }
  }

  /// Get available external sources
  List<Map<String, String>> getAvailableSources() {
    return [
      {'id': 'tmdb', 'name': 'TMDB', 'description': 'Movies and TV Shows'},
      {'id': 'anilist', 'name': 'AniList', 'description': 'Anime and Manga'},
      {
        'id': 'simkl',
        'name': 'Simkl',
        'description': 'Anime, Manga, Movies and TV',
      },
      {
        'id': 'jikan',
        'name': 'Jikan',
        'description': 'Anime and Manga (MyAnimeList)',
      },
      {'id': 'kitsu', 'name': 'Kitsu', 'description': 'Anime and Manga'},
    ];
  }
}
