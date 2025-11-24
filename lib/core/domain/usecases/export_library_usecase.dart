import 'package:dartz/dartz.dart';
import '../../../core/error/failures.dart';
import '../entities/library_item_entity.dart';
import '../repositories/library_repository.dart';
import '../services/data_export_import_service.dart';

/// Use case for exporting library to JSON
class ExportLibraryUseCase {
  final LibraryRepository libraryRepository;
  final DataExportImportService exportImportService;

  ExportLibraryUseCase({
    required this.libraryRepository,
    required this.exportImportService,
  });

  /// Execute the export library use case
  /// Returns the exported JSON string or a failure
  Future<Either<Failure, String>> call() async {
    try {
      // Get all library items
      final result = await libraryRepository.getLibraryItems(null);

      return result.fold(
        (failure) => Left(failure),
        (items) => exportImportService.exportLibrary(items),
      );
    } catch (e) {
      return Left(StorageFailure('Failed to export library: ${e.toString()}'));
    }
  }
}
