import 'package:dartz/dartz.dart';
import '../entities/library_item_entity.dart';
import '../repositories/library_repository.dart';
import '../../error/failures.dart';

/// Use case for adding media to the library
///
/// This use case adds a media item to the user's personal library
/// with a specified status (watching, plan to watch, etc.)
class AddToLibraryUseCase {
  final LibraryRepository repository;

  AddToLibraryUseCase(this.repository);

  /// Execute the use case to add media to library
  ///
  /// [params] - The parameters containing the library item to add
  ///
  /// Returns Either a Failure or Unit on success
  Future<Either<Failure, Unit>> call(AddToLibraryParams params) {
    return repository.addToLibrary(params.item);
  }
}

/// Parameters for adding media to library
class AddToLibraryParams {
  final LibraryItemEntity item;

  AddToLibraryParams({required this.item});
}
