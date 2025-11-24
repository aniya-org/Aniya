import 'package:dartz/dartz.dart';
import '../repositories/library_repository.dart';
import '../../error/failures.dart';

/// Use case for retrieving saved manga reading position
///
/// This use case retrieves the saved reading position (page number) for a manga chapter
/// allowing users to resume reading from where they left off
class GetReadingPositionUseCase {
  final LibraryRepository repository;

  GetReadingPositionUseCase(this.repository);

  /// Execute the use case to get reading position
  ///
  /// [params] - The parameters containing item ID and chapter ID
  ///
  /// Returns Either a Failure or the page number
  Future<Either<Failure, int>> call(GetReadingPositionParams params) {
    return repository.getReadingPosition(params.itemId, params.chapterId);
  }
}

/// Parameters for getting reading position
class GetReadingPositionParams {
  final String itemId;
  final String chapterId;

  GetReadingPositionParams({required this.itemId, required this.chapterId});
}
