import 'package:dartz/dartz.dart';
import '../entities/library_item_entity.dart';
import '../repositories/library_repository.dart';
import '../../error/failures.dart';

/// Use case for fetching library items with optional status filter
///
/// This use case retrieves the user's library items, optionally filtered
/// by library status (watching, completed, on hold, dropped, plan to watch)
class GetLibraryItemsUseCase {
  final LibraryRepository repository;

  GetLibraryItemsUseCase(this.repository);

  /// Execute the use case to get library items
  ///
  /// [params] - The parameters containing optional status filter
  ///
  /// Returns Either a Failure or a list of LibraryItemEntity
  Future<Either<Failure, List<LibraryItemEntity>>> call(
    GetLibraryItemsParams params,
  ) {
    return repository.getLibraryItems(params.status);
  }
}

/// Parameters for fetching library items
class GetLibraryItemsParams {
  final LibraryStatus? status;

  GetLibraryItemsParams({this.status});
}
