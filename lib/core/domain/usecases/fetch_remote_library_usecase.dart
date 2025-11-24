import 'package:dartz/dartz.dart';
import '../repositories/tracking_repository.dart';
import '../entities/library_item_entity.dart';
import '../entities/user_entity.dart';
import '../../error/failures.dart';

/// Use case for fetching library from tracking services
///
/// This use case imports the user's library from external tracking services
/// (AniList, MAL, Simkl) to sync their watch/read list
class FetchRemoteLibraryUseCase {
  final TrackingRepository repository;

  FetchRemoteLibraryUseCase(this.repository);

  /// Execute the use case to fetch library from tracking service
  ///
  /// [params] - The parameters containing the tracking service to fetch from
  ///
  /// Returns Either a Failure or a list of LibraryItemEntity
  Future<Either<Failure, List<LibraryItemEntity>>> call(
    FetchRemoteLibraryParams params,
  ) {
    return repository.fetchRemoteLibrary(params.service);
  }
}

/// Parameters for fetching remote library from tracking service
class FetchRemoteLibraryParams {
  final TrackingService service;

  FetchRemoteLibraryParams({required this.service});
}
