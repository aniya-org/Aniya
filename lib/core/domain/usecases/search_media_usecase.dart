import 'package:dartz/dartz.dart';
import '../entities/media_entity.dart';
import '../repositories/media_repository.dart';
import '../../error/failures.dart';

/// Use case for searching media across all enabled extensions
///
/// This use case searches for media content across all enabled extensions
/// and aggregates the results from multiple sources
class SearchMediaUseCase {
  final MediaRepository repository;

  SearchMediaUseCase(this.repository);

  /// Execute the use case to search for media
  ///
  /// [params] - The search parameters containing query and media type
  ///
  /// Returns Either a Failure or a list of MediaEntity
  Future<Either<Failure, List<MediaEntity>>> call(SearchMediaParams params) {
    return repository.searchMedia(params.query, params.type);
  }
}

/// Parameters for searching media
class SearchMediaParams {
  final String query;
  final MediaType type;

  SearchMediaParams({required this.query, required this.type});
}
