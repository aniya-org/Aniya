import 'package:dartz/dartz.dart';
import '../repositories/download_repository.dart';
import '../../error/failures.dart';

/// Use case for deleting a download
/// Removes the download from the queue and optionally deletes the local file
class DeleteDownloadUseCase {
  final DownloadRepository _repository;

  DeleteDownloadUseCase(this._repository);

  /// Execute the use case
  ///
  /// [id] - The download ID
  /// [deleteFile] - Whether to delete the local file (default: true)
  /// Returns void on success
  Future<Either<Failure, void>> call(
    String id, {
    bool deleteFile = true,
  }) async {
    return await _repository.deleteDownload(id, deleteFile: deleteFile);
  }
}
