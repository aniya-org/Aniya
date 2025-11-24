import 'package:dartz/dartz.dart';
import '../entities/library_item_entity.dart';
import '../repositories/library_repository.dart';
import '../../error/failures.dart';

/// Use case for updating library item status
///
/// This use case updates an existing library item's information,
/// such as status changes (e.g., from watching to completed).
/// When a library item is updated, it triggers a sync with
/// connected tracking services.
class UpdateLibraryItemUseCase {
  final LibraryRepository repository;

  UpdateLibraryItemUseCase(this.repository);

  /// Execute the use case to update a library item
  ///
  /// [params] - The parameters containing the updated library item
  ///
  /// Returns Either a Failure or Unit on success
  Future<Either<Failure, Unit>> call(UpdateLibraryItemParams params) {
    return repository.updateLibraryItem(params.item);
  }
}

/// Parameters for updating a library item
class UpdateLibraryItemParams {
  final LibraryItemEntity item;

  UpdateLibraryItemParams({required this.item});
}
