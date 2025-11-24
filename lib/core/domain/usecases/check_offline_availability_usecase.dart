import 'package:dartz/dartz.dart';
import '../repositories/download_repository.dart';
import '../../error/failures.dart';

/// Use case for checking if content is available offline
class CheckOfflineAvailabilityUseCase {
  final DownloadRepository _repository;

  CheckOfflineAvailabilityUseCase(this._repository);

  /// Execute the use case
  ///
  /// [mediaId] - The media ID
  /// [episodeId] - The episode ID (optional)
  /// [chapterId] - The chapter ID (optional)
  /// Returns true if content is available offline
  Future<Either<Failure, bool>> call({
    required String mediaId,
    String? episodeId,
    String? chapterId,
  }) async {
    return await _repository.isContentDownloaded(
      mediaId: mediaId,
      episodeId: episodeId,
      chapterId: chapterId,
    );
  }
}
