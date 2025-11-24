import 'package:dartz/dartz.dart';
import '../repositories/library_repository.dart';
import '../../error/failures.dart';

/// Use case for saving video playback position
///
/// This use case saves the current playback position for a video episode
/// so that users can resume watching from where they left off
class SavePlaybackPositionUseCase {
  final LibraryRepository repository;

  SavePlaybackPositionUseCase(this.repository);

  /// Execute the use case to save playback position
  ///
  /// [params] - The parameters containing item ID, episode ID, and position
  ///
  /// Returns Either a Failure or Unit on success
  Future<Either<Failure, Unit>> call(SavePlaybackPositionParams params) {
    return repository.savePlaybackPosition(
      params.itemId,
      params.episodeId,
      params.position,
    );
  }
}

/// Parameters for saving playback position
class SavePlaybackPositionParams {
  final String itemId;
  final String episodeId;
  final int position; // Position in milliseconds

  SavePlaybackPositionParams({
    required this.itemId,
    required this.episodeId,
    required this.position,
  });
}
