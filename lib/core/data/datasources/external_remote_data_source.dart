import '../../domain/entities/media_entity.dart';
import '../../domain/entities/media_details_entity.dart' hide SearchResult;
import '../../domain/entities/episode_entity.dart';
import '../../domain/entities/chapter_entity.dart';
import '../../domain/entities/search_result_entity.dart';
import '../../error/exceptions.dart';
import '../../utils/logger.dart';
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

  ExternalRemoteDataSource({
    TmdbExternalDataSourceImpl? tmdbDataSource,
    AnilistExternalDataSourceImpl? anilistDataSource,
    SimklExternalDataSourceImpl? simklDataSource,
    JikanExternalDataSourceImpl? jikanDataSource,
    KitsuExternalDataSourceImpl? kitsuDataSource,
  }) : _tmdbDataSource = tmdbDataSource ?? TmdbExternalDataSourceImpl(),
       _anilistDataSource =
           anilistDataSource ?? AnilistExternalDataSourceImpl(),
       _simklDataSource = simklDataSource ?? SimklExternalDataSourceImpl(),
       _jikanDataSource = jikanDataSource ?? JikanExternalDataSourceImpl(),
       _kitsuDataSource = kitsuDataSource ?? KitsuExternalDataSourceImpl();

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
      return await dataSource.searchMedia(query, type, page: page);
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
      final dataSource = _getDataSource(sourceId);
      return await dataSource.searchMedia(
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
    } catch (e) {
      Logger.error(
        'External advanced search failed for source $sourceId',
        error: e,
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
    List<EpisodeEntity> episodes = [];

    // 1. Try primary source
    try {
      final dataSource = _getDataSource(media.sourceId);
      if (dataSource is KitsuExternalDataSourceImpl) {
        episodes = await dataSource.getEpisodes(media.id);
      } else if (dataSource is AnilistExternalDataSourceImpl) {
        episodes = await dataSource.getEpisodes(media.id);
      } else if (dataSource is JikanExternalDataSourceImpl) {
        episodes = await dataSource.getEpisodes(media.id);
      }
    } catch (e) {
      Logger.error(
        'Primary source episodes failed for ${media.sourceName}',
        error: e,
      );
    }

    if (episodes.isNotEmpty) return episodes;

    // 2. Fallback: Kitsu (Best for images)
    if (media.sourceId != 'kitsu') {
      final match = await _findMatchInSource(media.title, media.type, 'kitsu');
      if (match != null) {
        try {
          episodes = await _kitsuDataSource.getEpisodes(match.id);
          if (episodes.isNotEmpty) return episodes;
        } catch (e) {
          Logger.error('Kitsu fallback episodes failed', error: e);
        }
      }
    }

    // 3. Fallback: Jikan
    if (media.sourceId != 'jikan') {
      final match = await _findMatchInSource(media.title, media.type, 'jikan');
      if (match != null) {
        try {
          episodes = await _jikanDataSource.getEpisodes(match.id);
          if (episodes.isNotEmpty) return episodes;
        } catch (e) {
          Logger.error('Jikan fallback episodes failed', error: e);
        }
      }
    }

    // 4. Fallback: AniList
    if (media.sourceId != 'anilist') {
      final match = await _findMatchInSource(
        media.title,
        media.type,
        'anilist',
      );
      if (match != null) {
        try {
          episodes = await _anilistDataSource.getEpisodes(match.id);
          if (episodes.isNotEmpty) return episodes;
        } catch (e) {
          Logger.error('AniList fallback episodes failed', error: e);
        }
      }
    }

    return episodes;
  }

  Future<List<ChapterEntity>> getChapters(MediaEntity media) async {
    List<ChapterEntity> chapters = [];

    // 1. Try primary source
    try {
      final dataSource = _getDataSource(media.sourceId);
      if (dataSource is KitsuExternalDataSourceImpl) {
        chapters = await dataSource.getChapters(media.id);
      }
      // AniList and Jikan don't support chapters via API yet
    } catch (e) {
      Logger.error(
        'Primary source chapters failed for ${media.sourceName}',
        error: e,
      );
    }

    if (chapters.isNotEmpty) return chapters;

    // 2. Fallback: Kitsu (Primary source for chapters)
    if (media.sourceId != 'kitsu') {
      final match = await _findMatchInSource(media.title, media.type, 'kitsu');
      if (match != null) {
        try {
          chapters = await _kitsuDataSource.getChapters(match.id);
          if (chapters.isNotEmpty) return chapters;
        } catch (e) {
          Logger.error('Kitsu fallback chapters failed', error: e);
        }
      }
    }

    return chapters;
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
