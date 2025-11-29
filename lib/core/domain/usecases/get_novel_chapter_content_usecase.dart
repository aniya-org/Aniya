import 'package:dartz/dartz.dart';

import '../repositories/media_repository.dart';
import '../../error/failures.dart';

/// Use case for fetching raw novel chapter content from an extension source.
class GetNovelChapterContentUseCase {
  final MediaRepository repository;

  GetNovelChapterContentUseCase(this.repository);

  Future<Either<Failure, String>> call(GetNovelChapterContentParams params) {
    return repository.getNovelChapterContent(
      params.chapterId,
      params.chapterTitle,
      params.sourceId,
    );
  }
}

class GetNovelChapterContentParams {
  final String chapterId;
  final String chapterTitle;
  final String sourceId;

  GetNovelChapterContentParams({
    required this.chapterId,
    required this.chapterTitle,
    required this.sourceId,
  });
}
