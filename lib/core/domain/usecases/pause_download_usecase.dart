import 'package:dartz/dartz.dart';
import '../entities/download_entity.dart';
import '../repositories/download_repository.dart';
import '../../error/failures.dart';

/// Use case for pausing a download
class PauseDownloadUseCase {
  final DownloadRepository _repository;

  PauseDownloadUseCase(this._repository);

  /// Execute the use case
  ///
  /// [id] - The download ID
  /// Returns the updated download entity
  Future<Either<Failure, DownloadEntity>> call(String id) async {
    return await _repository.pauseDownload(id);
  }
}
