import 'package:dartz/dartz.dart';
import '../entities/download_entity.dart';
import '../repositories/download_repository.dart';
import '../../error/failures.dart';

/// Use case for adding a download to the queue
class AddDownloadUseCase {
  final DownloadRepository _repository;

  AddDownloadUseCase(this._repository);

  /// Execute the use case
  ///
  /// [download] - The download entity to add
  /// Returns the added download entity
  Future<Either<Failure, DownloadEntity>> call(DownloadEntity download) async {
    return await _repository.addDownload(download);
  }
}
