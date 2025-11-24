import 'package:dartz/dartz.dart';
import '../entities/media_entity.dart';
import '../entities/episode_entity.dart';
import '../entities/chapter_entity.dart';
import '../../../core/error/failures.dart';

/// Repository interface for media-related operations
/// Provides methods to search, fetch, and manage media content from extensions
abstract class MediaRepository {
  /// Search for media across all enabled extensions
  ///
  /// [query] - The search query string
  /// [type] - The type of media to search for (anime, manga, movie, tvShow)
  ///
  /// Returns a list of media entities or a failure
  Future<Either<Failure, List<MediaEntity>>> searchMedia(
    String query,
    MediaType type,
  );

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
  ///
  /// Returns a list of trending media entities or a failure
  Future<Either<Failure, List<MediaEntity>>> getTrending(
    MediaType type,
    int page,
  );

  /// Get popular media for a specific type
  ///
  /// [type] - The type of media (anime, manga, movie, tvShow)
  /// [page] - The page number for pagination
  ///
  /// Returns a list of popular media entities or a failure
  Future<Either<Failure, List<MediaEntity>>> getPopular(
    MediaType type,
    int page,
  );

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
}
