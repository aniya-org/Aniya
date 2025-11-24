import 'package:dartz/dartz.dart';
import '../entities/chapter_entity.dart';
import '../repositories/media_repository.dart';
import '../../error/failures.dart';

/// Use case for fetching chapters for a media item
///
/// This use case retrieves the list of chapters for a specific manga or light novel
/// from the extension source
class GetChaptersUseCase {
  final MediaRepository repository;

  GetChaptersUseCase(this.repository);

  /// Execute the use case to get chapters
  ///
  /// [params] - The parameters containing media ID and source ID
  ///
  /// Returns Either a Failure or a list of ChapterEntity
  Future<Either<Failure, List<ChapterEntity>>> call(GetChaptersParams params) {
    return repository.getChapters(params.mediaId, params.sourceId);
  }
}

/// Parameters for fetching chapters
class GetChaptersParams {
  final String mediaId;
  final String sourceId;

  GetChaptersParams({required this.mediaId, required this.sourceId});
}
