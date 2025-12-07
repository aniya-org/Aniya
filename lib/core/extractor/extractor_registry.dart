import 'package:aniya/core/extractor/base/extractor_info.dart';
import 'package:aniya/core/extractor/models/extractor_request.dart';
import 'package:aniya/core/extractor/extractors/extractor_catalog.dart';

/// Holds the registered extractor infos and exposes lookup helpers.
class ExtractorRegistry {
  ExtractorRegistry({
    List<ExtractorInfo>? videoExtractors,
    List<ExtractorInfo>? audioExtractors,
  }) : _videoExtractors = videoExtractors ?? buildDefaultVideoExtractors(),
       _audioExtractors = audioExtractors ?? const [];

  final List<ExtractorInfo> _videoExtractors;
  final List<ExtractorInfo> _audioExtractors;

  List<ExtractorInfo> byCategory(ExtractorCategory category) {
    return switch (category) {
      ExtractorCategory.video => _videoExtractors,
      ExtractorCategory.audio => _audioExtractors,
    };
  }

  List<ExtractorInfo> match(ExtractorRequest request) {
    final candidates = byCategory(request.category)
        .where(
          (info) =>
              info.mediaType == null || info.mediaType == request.mediaType,
        )
        .toList(growable: false);
    return candidates
        .where(
          (info) => info.patterns.any(
            (pattern) => pattern.hasMatch(request.url.toString()),
          ),
        )
        .toList(growable: false);
  }
}
