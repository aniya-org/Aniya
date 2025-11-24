import 'package:dartz/dartz.dart';
import '../entities/episode_entity.dart';
import '../repositories/media_repository.dart';
import '../../error/failures.dart';

/// Use case for fetching episodes for a media item
///
/// This use case retrieves the list of episodes for a specific anime or TV show
/// from the extension source
class GetEpisodesUseCase {
  final MediaRepository repository;

  GetEpisodesUseCase(this.repository);

  /// Execute the use case to get episodes
  ///
  /// [params] - The parameters containing media ID and source ID
  ///
  /// Returns Either a Failure or a list of EpisodeEntity
  Future<Either<Failure, List<EpisodeEntity>>> call(GetEpisodesParams params) {
    return repository.getEpisodes(params.mediaId, params.sourceId);
  }
}

/// Parameters for fetching episodes
class GetEpisodesParams {
  final String mediaId;
  final String sourceId;

  GetEpisodesParams({required this.mediaId, required this.sourceId});
}
