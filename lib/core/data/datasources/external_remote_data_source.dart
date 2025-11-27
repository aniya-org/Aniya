import '../../domain/entities/media_entity.dart';
import '../../domain/entities/media_details_entity.dart' hide SearchResult;
import '../../domain/entities/episode_entity.dart';
import '../../domain/entities/chapter_entity.dart';
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
  }) async {
    try {
      final dataSource = _getDataSource(sourceId);
      final result = await dataSource.searchMedia(query, type, page: page);
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
      final results = await searchMedia(title, targetSourceId, type);
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

    return aggregatedChapters;
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
