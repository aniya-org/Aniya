import 'package:dartz/dartz.dart';
import '../entities/extension_entity.dart';
import '../entities/media_entity.dart';
import '../entities/episode_entity.dart';
import '../entities/source_entity.dart';
import '../../error/failures.dart';

/// Repository interface for searching media within extensions and retrieving sources
/// Provides methods to search for media titles and scrape available sources
/// Requirements: 3.2, 4.1
abstract class ExtensionSearchRepository {
  /// Search for media in an extension by query
  ///
  /// [query] - The search query string (media title)
  /// [extension] - The extension to search in
  /// [page] - The page number for pagination (default 1)
  ///
  /// Returns a list of matching media entities or a failure
  /// Requirements: 3.2
  Future<Either<Failure, List<MediaEntity>>> searchMedia(
    String query,
    ExtensionEntity extension,
    int page,
  );

  /// Get available sources for a media item from an extension
  ///
  /// [media] - The media item to get sources for
  /// [extension] - The extension to scrape sources from
  /// [episode] - The episode/chapter to get sources for
  ///
  /// Returns a list of available source entities or a failure
  /// Requirements: 4.1
  Future<Either<Failure, List<SourceEntity>>> getSources(
    MediaEntity media,
    ExtensionEntity extension,
    EpisodeEntity episode,
  );
}
