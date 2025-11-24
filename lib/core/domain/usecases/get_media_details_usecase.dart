import 'package:dartz/dartz.dart';
import '../entities/media_entity.dart';
import '../repositories/media_repository.dart';
import '../../error/failures.dart';

/// Use case for fetching detailed information about a media item
///
/// This use case retrieves comprehensive details about a specific media item
/// including metadata from TMDB for movies and TV shows
class GetMediaDetailsUseCase {
  final MediaRepository repository;

  GetMediaDetailsUseCase(this.repository);

  /// Execute the use case to get media details
  ///
  /// [params] - The parameters containing media ID and source ID
  ///
  /// Returns Either a Failure or a MediaEntity with full details
  Future<Either<Failure, MediaEntity>> call(GetMediaDetailsParams params) {
    return repository.getMediaDetails(params.id, params.sourceId);
  }
}

/// Parameters for fetching media details
class GetMediaDetailsParams {
  final String id;
  final String sourceId;

  GetMediaDetailsParams({required this.id, required this.sourceId});
}
