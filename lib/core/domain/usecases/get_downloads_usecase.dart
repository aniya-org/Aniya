import 'package:dartz/dartz.dart';
import '../entities/download_entity.dart';
import '../repositories/download_repository.dart';
import '../../error/failures.dart';

/// Use case for getting downloads
class GetDownloadsUseCase {
  final DownloadRepository _repository;

  GetDownloadsUseCase(this._repository);

  /// Get all downloads
  Future<Either<Failure, List<DownloadEntity>>> call() async {
    return await _repository.getAllDownloads();
  }

  /// Get downloads by status
  Future<Either<Failure, List<DownloadEntity>>> byStatus(
    DownloadStatus status,
  ) async {
    return await _repository.getDownloadsByStatus(status);
  }

  /// Get download by ID
  Future<Either<Failure, DownloadEntity>> byId(String id) async {
    return await _repository.getDownloadById(id);
  }
}
