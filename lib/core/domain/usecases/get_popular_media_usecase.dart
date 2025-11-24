import 'package:dartz/dartz.dart';
import '../entities/media_entity.dart';
import '../repositories/media_repository.dart';
import '../../error/failures.dart';

/// Use case for fetching popular media content
///
/// This use case retrieves popular media for a specific type
/// (anime, manga, movie, or TV show) with pagination support
class GetPopularMediaUseCase {
  final MediaRepository repository;

  GetPopularMediaUseCase(this.repository);

  /// Execute the use case to get popular media
  ///
  /// [params] - The parameters containing media type and page number
  ///
  /// Returns Either a Failure or a list of popular MediaEntity
  Future<Either<Failure, List<MediaEntity>>> call(
    GetPopularMediaParams params,
  ) {
    return repository.getPopular(
      params.type,
      params.page,
      sourceId: params.sourceId,
    );
  }
}

/// Parameters for fetching popular media
class GetPopularMediaParams {
  final MediaType type;
  final int page;
  final String? sourceId;

  GetPopularMediaParams({
    required this.type,
    required this.page,
    this.sourceId,
  });
}
