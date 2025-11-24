import 'package:dartz/dartz.dart';
import '../entities/user_entity.dart';
import '../entities/library_item_entity.dart';
import '../../../core/error/failures.dart';

/// Repository interface for tracking service integration
/// Provides methods to authenticate and sync with external tracking services
abstract class TrackingRepository {
  /// Authenticate with a tracking service
  ///
  /// [service] - The tracking service to authenticate with (anilist, mal, simkl)
  /// [token] - The authentication token
  ///
  /// Returns the authenticated user entity or a failure
  Future<Either<Failure, UserEntity>> authenticate(
    TrackingService service,
    String token,
  );

  /// Sync progress to a tracking service
  ///
  /// [mediaId] - The unique identifier of the media
  /// [episode] - The current episode number
  /// [chapter] - The current chapter number
  ///
  /// Returns success (Unit) or a failure
  Future<Either<Failure, Unit>> syncProgress(
    String mediaId,
    int episode,
    int chapter,
  );

  /// Fetch the user's library from a tracking service
  ///
  /// [service] - The tracking service to fetch from
  ///
  /// Returns a list of library items from the remote service or a failure
  Future<Either<Failure, List<LibraryItemEntity>>> fetchRemoteLibrary(
    TrackingService service,
  );

  /// Update the status of a media item on a tracking service
  ///
  /// [mediaId] - The unique identifier of the media
  /// [status] - The new library status
  ///
  /// Returns success (Unit) or a failure
  Future<Either<Failure, Unit>> updateStatus(
    String mediaId,
    LibraryStatus status,
  );
}
