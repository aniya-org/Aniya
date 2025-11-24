import 'package:dartz/dartz.dart';
import '../repositories/library_repository.dart';
import '../../error/failures.dart';

/// Use case for getting saved video playback position
///
/// This use case retrieves the saved playback position for a video episode
/// so that users can resume watching from where they left off
class GetPlaybackPositionUseCase {
  final LibraryRepository repository;

  GetPlaybackPositionUseCase(this.repository);

  /// Execute the use case to get playback position
  ///
  /// [params] - The parameters containing item ID and episode ID
  ///
  /// Returns Either a Failure or the position in milliseconds
  Future<Either<Failure, int>> call(GetPlaybackPositionParams params) {
    return repository.getPlaybackPosition(params.itemId, params.episodeId);
  }
}

/// Parameters for getting playback position
class GetPlaybackPositionParams {
  final String itemId;
  final String episodeId;

  GetPlaybackPositionParams({required this.itemId, required this.episodeId});
}
