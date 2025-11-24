import 'package:dartz/dartz.dart';
import '../repositories/library_repository.dart';
import '../../error/failures.dart';

/// Use case for saving manga reading position
///
/// This use case saves the current reading position (page number) for a manga chapter
/// so that users can resume reading from where they left off
class SaveReadingPositionUseCase {
  final LibraryRepository repository;

  SaveReadingPositionUseCase(this.repository);

  /// Execute the use case to save reading position
  ///
  /// [params] - The parameters containing item ID, chapter ID, and page number
  ///
  /// Returns Either a Failure or Unit on success
  Future<Either<Failure, Unit>> call(SaveReadingPositionParams params) {
    return repository.saveReadingPosition(
      params.itemId,
      params.chapterId,
      params.page,
    );
  }
}

/// Parameters for saving reading position
class SaveReadingPositionParams {
  final String itemId;
  final String chapterId;
  final int page; // Current page number

  SaveReadingPositionParams({
    required this.itemId,
    required this.chapterId,
    required this.page,
  });
}
