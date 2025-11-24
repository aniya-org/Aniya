import 'package:dartz/dartz.dart';
import '../entities/video_source_entity.dart';
import '../repositories/video_repository.dart';
import '../../error/failures.dart';

/// Use case for extracting playable video URL from a video source
///
/// This use case extracts the actual playable video URL from a video source,
/// handling any necessary decryption or URL resolution
class ExtractVideoUrlUseCase {
  final VideoRepository repository;

  ExtractVideoUrlUseCase(this.repository);

  /// Execute the use case to extract video URL
  ///
  /// [params] - The parameters containing the video source
  ///
  /// Returns Either a Failure or the extracted video URL string
  Future<Either<Failure, String>> call(ExtractVideoUrlParams params) {
    return repository.extractVideoUrl(params.source);
  }
}

/// Parameters for extracting video URL
class ExtractVideoUrlParams {
  final VideoSource source;

  ExtractVideoUrlParams({required this.source});
}
