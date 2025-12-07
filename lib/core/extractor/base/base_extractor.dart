import 'package:aniya/core/extractor/models/extractor_request.dart';
import 'package:aniya/core/extractor/models/raw_stream.dart';

/// Base contract for every extractor implementation.
/// Mirrors the TypeScript interface in
/// ref/umbrella/src/data/services/extractor/domain/entities/Extractor.ts.
abstract class BaseExtractor {
  String get name;

  /// Runs the extractor against the provided payload and returns playable
  /// streams (or an empty list when nothing could be resolved).
  Future<List<RawStream>> extract(ExtractorRequest request);
}
