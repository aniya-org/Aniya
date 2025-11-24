import 'package:dartz/dartz.dart';
import '../repositories/library_repository.dart';
import '../../error/failures.dart';

/// Use case for removing media from the library
///
/// This use case removes a media item from the user's personal library
/// by deleting the local library entry
class RemoveFromLibraryUseCase {
  final LibraryRepository repository;

  RemoveFromLibraryUseCase(this.repository);

  /// Execute the use case to remove media from library
  ///
  /// [params] - The parameters containing the item ID to remove
  ///
  /// Returns Either a Failure or Unit on success
  Future<Either<Failure, Unit>> call(RemoveFromLibraryParams params) {
    return repository.removeFromLibrary(params.itemId);
  }
}

/// Parameters for removing media from library
class RemoveFromLibraryParams {
  final String itemId;

  RemoveFromLibraryParams({required this.itemId});
}
