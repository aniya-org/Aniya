import 'package:dartz/dartz.dart';
import '../../../core/error/failures.dart';
import '../services/data_export_import_service.dart';

/// Use case for exporting settings to JSON
class ExportSettingsUseCase {
  final DataExportImportService exportImportService;

  ExportSettingsUseCase({required this.exportImportService});

  /// Execute the export settings use case
  /// [settings] - The settings map to export
  /// Returns the exported JSON string or a failure
  Future<Either<Failure, String>> call(Map<String, dynamic> settings) async {
    try {
      return await exportImportService.exportSettings(settings);
    } catch (e) {
      return Left(StorageFailure('Failed to export settings: ${e.toString()}'));
    }
  }
}
