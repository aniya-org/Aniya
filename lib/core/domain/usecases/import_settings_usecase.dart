import 'package:dartz/dartz.dart';
import '../../../core/error/failures.dart';
import '../services/data_export_import_service.dart';

/// Use case for importing settings from JSON
class ImportSettingsUseCase {
  final DataExportImportService exportImportService;

  ImportSettingsUseCase({required this.exportImportService});

  /// Execute the import settings use case
  /// [jsonData] - The JSON string containing settings data
  /// Returns the imported settings map or a failure
  Future<Either<Failure, Map<String, dynamic>>> call(String jsonData) async {
    try {
      return await exportImportService.importSettings(jsonData);
    } catch (e) {
      return Left(
        ValidationFailure('Failed to import settings: ${e.toString()}'),
      );
    }
  }
}
