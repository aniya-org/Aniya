import 'package:dartz/dartz.dart';
import '../repositories/tracking_repository.dart';
import '../entities/library_item_entity.dart';
import '../../error/failures.dart';

/// Use case for updating status on tracking services
///
/// This use case updates the library status of a media item
/// on connected tracking services (AniList, MAL, Simkl)
class UpdateTrackingStatusUseCase {
  final TrackingRepository repository;

  UpdateTrackingStatusUseCase(this.repository);

  /// Execute the use case to update status on tracking service
  ///
  /// [params] - The parameters containing media ID and new status
  ///
  /// Returns Either a Failure or Unit on success
  Future<Either<Failure, Unit>> call(UpdateTrackingStatusParams params) {
    return repository.updateStatus(params.mediaId, params.status);
  }
}

/// Parameters for updating status on tracking service
class UpdateTrackingStatusParams {
  final String mediaId;
  final LibraryStatus status;

  UpdateTrackingStatusParams({required this.mediaId, required this.status});
}
