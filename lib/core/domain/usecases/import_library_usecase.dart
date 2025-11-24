import 'package:dartz/dartz.dart';
import '../../../core/error/failures.dart';
import '../entities/library_item_entity.dart';
import '../repositories/library_repository.dart';
import '../services/data_export_import_service.dart';

/// Use case for importing library from JSON
class ImportLibraryUseCase {
  final LibraryRepository libraryRepository;
  final DataExportImportService exportImportService;

  ImportLibraryUseCase({
    required this.libraryRepository,
    required this.exportImportService,
  });

  /// Execute the import library use case
  /// [jsonData] - The JSON string containing library data
  /// Returns the imported library items or a failure
  Future<Either<Failure, List<LibraryItemEntity>>> call(String jsonData) async {
    try {
      // Parse the JSON data
      final parseResult = await exportImportService.importLibrary(jsonData);

      return parseResult.fold((failure) => Left(failure), (items) async {
        // Add all items to the library
        for (final item in items) {
          final addResult = await libraryRepository.addToLibrary(item);
          if (addResult.isLeft()) {
            // If any item fails to add, return the failure
            return addResult.fold(
              (failure) => Left(failure),
              (_) => Right(items),
            );
          }
        }
        return Right(items);
      });
    } catch (e) {
      return Left(StorageFailure('Failed to import library: ${e.toString()}'));
    }
  }
}
