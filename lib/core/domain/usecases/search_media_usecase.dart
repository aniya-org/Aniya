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
  /// [params] - The search parameters containing query, media type, and optional sourceId
  ///
  /// Returns Either a Failure or a list of MediaEntity or SearchResult depending on params
  Future<Either<Failure, dynamic>> call(SearchMediaParams params) {
    if (params is SearchMediaParamsAdvanced) {
      return repository.searchMediaAdvanced(
        params.query,
        params.type,
        params.sourceId!,
        genres: params.genres,
        year: params.year,
        season: params.season,
        status: params.status,
        format: params.format,
        minScore: params.minScore,
        maxScore: params.maxScore,
        sort: params.sort,
      );
    } else {
      return repository.searchMedia(
        params.query,
        params.type,
        sourceId: params.sourceId,
      );
    }
  }
}

/// Parameters for searching media
class SearchMediaParams {
  final String query;
  final MediaType type;
  final String? sourceId;

  SearchMediaParams({required this.query, required this.type, this.sourceId});
}

/// Advanced search parameters (extends basic params)
class SearchMediaParamsAdvanced extends SearchMediaParams {
  final List<String>? genres;
  final int? year;
  final String? season;
  final String? status;
  final String? format;
  final int? minScore;
  final int? maxScore;
  final String? sort;

  SearchMediaParamsAdvanced({
    required String query,
    required MediaType type,
    required String sourceId,
    this.genres,
    this.year,
    this.season,
    this.status,
    this.format,
    this.minScore,
    this.maxScore,
    this.sort,
  }) : super(query: query, type: type, sourceId: sourceId);
}
