import 'package:dartz/dartz.dart';
import '../entities/media_entity.dart';
import '../entities/search_result_entity.dart';
import '../entities/episode_entity.dart';
import '../entities/chapter_entity.dart';
import '../../../core/error/failures.dart';

/// Repository interface for media-related operations
/// Provides methods to search, fetch, and manage media content from extensions
class SourceSearchProgress {
  final String sourceId;
  final String sourceName;
  final bool isLoading;
  final bool hasError;
  final String? errorMessage;
  final List<MediaEntity> results;

  const SourceSearchProgress({
    required this.sourceId,
    required this.sourceName,
    required this.isLoading,
    required this.hasError,
    this.errorMessage,
    required this.results,
  });
}

typedef SourceProgressCallback = void Function(SourceSearchProgress progress);

abstract class MediaRepository {
  /// Search for media across all enabled extensions or external sources
  ///
  /// [query] - The search query string
  /// [type] - The type of media to search for (anime, manga, movie, tvShow)
  /// [sourceId] - Optional source ID for external sources (tmdb, anilist, simkl, jikan)
  ///
  /// Returns a list of media entities or a failure
  Future<Either<Failure, List<MediaEntity>>> searchMedia(
    String query,
    MediaType type, {
    String? sourceId,
    SourceProgressCallback? onSourceProgress,
  });

  /// Advanced search for media with filtering and pagination (external sources only)
  ///
  /// [query] - The search query string
  /// [type] - The type of media to search for (anime, manga, movie, tvShow)
  /// [sourceId] - Required source ID for external sources (tmdb, anilist, simkl, jikan)
  /// [genres] - Optional list of genre names to filter by
  /// [year] - Optional year to filter by (season year for anime/manga)
  /// [season] - Optional season (winter, spring, summer, fall)
  /// [status] - Optional status (finished, airing, completed, etc.)
  /// [format] - Optional format (tv, movie, special, ova, etc.)
  /// [minScore] - Optional minimum score rating
  /// [maxScore] - Optional maximum score rating
  /// [sort] - Optional sort order
  /// [page] - Page number for pagination
  /// [perPage] - Number of results per page
  ///
  /// Returns a SearchResult containing media entities or a failure
  Future<Either<Failure, SearchResult<List<MediaEntity>>>> searchMediaAdvanced(
    String query,
    MediaType type,
    String sourceId, {
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
  });

  /// Get detailed information about a specific media item
  ///
  /// [id] - The unique identifier of the media
  /// [sourceId] - The extension source ID
  ///
  /// Returns the media entity with full details or a failure
  Future<Either<Failure, MediaEntity>> getMediaDetails(
    String id,
    String sourceId,
  );

  /// Get trending media for a specific type
  ///
  /// [type] - The type of media (anime, manga, movie, tvShow)
  /// [page] - The page number for pagination
  /// [sourceId] - Optional source ID for external sources
  ///
  /// Returns a list of trending media entities or a failure
  Future<Either<Failure, List<MediaEntity>>> getTrending(
    MediaType type,
    int page, {
    String? sourceId,
  });

  /// Get popular media for a specific type
  ///
  /// [type] - The type of media (anime, manga, movie, tvShow)
  /// [page] - The page number for pagination
  /// [sourceId] - Optional source ID for external sources
  ///
  /// Returns a list of popular media entities or a failure
  Future<Either<Failure, List<MediaEntity>>> getPopular(
    MediaType type,
    int page, {
    String? sourceId,
  });

  /// Get episodes for a specific media item
  ///
  /// [mediaId] - The unique identifier of the media
  /// [sourceId] - The extension source ID
  ///
  /// Returns a list of episode entities or a failure
  Future<Either<Failure, List<EpisodeEntity>>> getEpisodes(
    String mediaId,
    String sourceId,
  );

  /// Get episodes with cross-provider aggregation for external sources
  ///
  /// This method uses the full MediaEntity to perform cross-provider matching
  /// and data aggregation, providing the most complete episode information.
  ///
  /// [media] - The media entity to fetch episodes for
  ///
  /// Returns a list of aggregated episode entities or a failure
  Future<Either<Failure, List<EpisodeEntity>>> getEpisodesWithAggregation(
    MediaEntity media,
  );

  /// Get chapters for a specific media item
  ///
  /// [mediaId] - The unique identifier of the media
  /// [sourceId] - The extension source ID
  ///
  /// Returns a list of chapter entities or a failure
  Future<Either<Failure, List<ChapterEntity>>> getChapters(
    String mediaId,
    String sourceId,
  );

  /// Get chapters with cross-provider aggregation for external sources
  ///
  /// This method uses the full MediaEntity to perform cross-provider matching
  /// and data aggregation, providing the most complete chapter information.
  ///
  /// [media] - The media entity to fetch chapters for
  ///
  /// Returns a list of aggregated chapter entities or a failure
  Future<Either<Failure, List<ChapterEntity>>> getChaptersWithAggregation(
    MediaEntity media,
  );

  /// Get pages for a specific manga chapter
  ///
  /// [chapterId] - The unique identifier of the chapter
  /// [sourceId] - The extension source ID
  ///
  /// Returns a list of page URLs or a failure
  Future<Either<Failure, List<String>>> getChapterPages(
    String chapterId,
    String sourceId,
  );

  /// Get the raw text/HTML content for a novel chapter from a source
  Future<Either<Failure, String>> getNovelChapterContent(
    String chapterId,
    String chapterTitle,
    String sourceId,
  );
}
