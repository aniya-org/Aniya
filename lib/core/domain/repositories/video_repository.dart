import 'package:dartz/dartz.dart';
import '../entities/video_source_entity.dart';
import '../../../core/error/failures.dart';

/// Repository interface for video playback operations
/// Provides methods to fetch and extract video sources
abstract class VideoRepository {
  /// Get available video sources for an episode
  ///
  /// [episodeId] - The unique identifier of the episode
  /// [sourceId] - The extension source ID
  ///
  /// Returns a list of video source entities or a failure
  Future<Either<Failure, List<VideoSource>>> getVideoSources(
    String episodeId,
    String sourceId,
  );

  /// Extract the playable video URL from a video source
  ///
  /// [source] - The video source to extract from
  ///
  /// Returns the extracted video URL or a failure
  Future<Either<Failure, String>> extractVideoUrl(VideoSource source);
}
