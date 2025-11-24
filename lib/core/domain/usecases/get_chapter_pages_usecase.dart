import 'package:dartz/dartz.dart';
import '../repositories/media_repository.dart';
import '../../error/failures.dart';

/// Use case for fetching pages for a manga chapter
///
/// This use case retrieves the list of page URLs for a specific manga chapter
/// from the extension source
class GetChapterPagesUseCase {
  final MediaRepository repository;

  GetChapterPagesUseCase(this.repository);

  /// Execute the use case to get chapter pages
  ///
  /// [params] - The parameters containing chapter ID and source ID
  ///
  /// Returns Either a Failure or a list of page URLs
  Future<Either<Failure, List<String>>> call(GetChapterPagesParams params) {
    return repository.getChapterPages(params.chapterId, params.sourceId);
  }
}

/// Parameters for fetching chapter pages
class GetChapterPagesParams {
  final String chapterId;
  final String sourceId;

  GetChapterPagesParams({required this.chapterId, required this.sourceId});
}
