import 'package:aniya/core/domain/entities/media_entity.dart';
import 'package:aniya/core/extractor/base/base_extractor.dart';
import 'package:aniya/core/extractor/models/extractor_request.dart';

/// Metadata describing which URLs a group of extractors can handle, lifted from
/// ref/umbrella/src/data/services/extractor/domain/entities/ExtractorInfo.ts.
class ExtractorInfo {
  final String id;
  final List<RegExp> patterns;
  final ExtractorCategory category;
  final MediaType? mediaType;
  final List<BaseExtractor> extractors;

  const ExtractorInfo({
    required this.id,
    required this.patterns,
    required this.category,
    this.mediaType,
    required this.extractors,
  });
}
