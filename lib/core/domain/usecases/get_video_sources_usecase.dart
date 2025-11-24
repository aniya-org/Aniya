import 'package:dartz/dartz.dart';
import '../entities/video_source_entity.dart';
import '../repositories/video_repository.dart';
import '../../error/failures.dart';

/// Use case for fetching video sources for an episode
///
/// This use case retrieves available video sources from the extension
/// for a specific episode, including quality options and server choices
class GetVideoSourcesUseCase {
  final VideoRepository repository;

  GetVideoSourcesUseCase(this.repository);

  /// Execute the use case to get video sources
  ///
  /// [params] - The parameters containing episode ID and source ID
  ///
  /// Returns Either a Failure or a list of VideoSource
  Future<Either<Failure, List<VideoSource>>> call(
    GetVideoSourcesParams params,
  ) {
    return repository.getVideoSources(params.episodeId, params.sourceId);
  }
}

/// Parameters for fetching video sources
class GetVideoSourcesParams {
  final String episodeId;
  final String sourceId;

  GetVideoSourcesParams({required this.episodeId, required this.sourceId});
}
