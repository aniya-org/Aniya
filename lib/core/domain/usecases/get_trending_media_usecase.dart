import 'package:dartz/dartz.dart';
import '../entities/media_entity.dart';
import '../repositories/media_repository.dart';
import '../../error/failures.dart';

/// Use case for fetching trending media content
///
/// This use case retrieves trending media for a specific type
/// (anime, manga, movie, or TV show) with pagination support
class GetTrendingMediaUseCase {
  final MediaRepository repository;

  GetTrendingMediaUseCase(this.repository);

  /// Execute the use case to get trending media
  ///
  /// [params] - The parameters containing media type and page number
  ///
  /// Returns Either a Failure or a list of trending MediaEntity
  Future<Either<Failure, List<MediaEntity>>> call(
    GetTrendingMediaParams params,
  ) {
    return repository.getTrending(params.type, params.page);
  }
}

/// Parameters for fetching trending media
class GetTrendingMediaParams {
  final MediaType type;
  final int page;

  GetTrendingMediaParams({required this.type, required this.page});
}
