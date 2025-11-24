import 'package:dartz/dartz.dart';
import '../repositories/library_repository.dart';
import '../../error/failures.dart';

/// Use case for updating episode/chapter progress
///
/// This use case tracks the user's progress through a media item
/// by updating the current episode and chapter numbers
class UpdateProgressUseCase {
  final LibraryRepository repository;

  UpdateProgressUseCase(this.repository);

  /// Execute the use case to update progress
  ///
  /// [params] - The parameters containing item ID and progress information
  ///
  /// Returns Either a Failure or Unit on success
  Future<Either<Failure, Unit>> call(UpdateProgressParams params) {
    return repository.updateProgress(
      params.itemId,
      params.episode,
      params.chapter,
    );
  }
}

/// Parameters for updating progress
class UpdateProgressParams {
  final String itemId;
  final int episode;
  final int chapter;

  UpdateProgressParams({
    required this.itemId,
    required this.episode,
    required this.chapter,
  });
}
