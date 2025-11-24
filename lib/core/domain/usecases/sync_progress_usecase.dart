import 'package:dartz/dartz.dart';
import '../repositories/tracking_repository.dart';
import '../../error/failures.dart';

/// Use case for syncing progress to tracking services
///
/// This use case synchronizes the user's watch/read progress
/// to connected tracking services (AniList, MAL, Simkl)
class SyncProgressUseCase {
  final TrackingRepository repository;

  SyncProgressUseCase(this.repository);

  /// Execute the use case to sync progress to tracking service
  ///
  /// [params] - The parameters containing media ID and progress information
  ///
  /// Returns Either a Failure or Unit on success
  Future<Either<Failure, Unit>> call(SyncProgressParams params) {
    return repository.syncProgress(
      params.mediaId,
      params.episode,
      params.chapter,
    );
  }
}

/// Parameters for syncing progress to tracking service
class SyncProgressParams {
  final String mediaId;
  final int episode;
  final int chapter;

  SyncProgressParams({
    required this.mediaId,
    required this.episode,
    required this.chapter,
  });
}
