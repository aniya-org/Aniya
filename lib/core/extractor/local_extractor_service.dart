import 'package:aniya/core/extractor/base/base_extractor.dart';
import 'package:aniya/core/extractor/base/extractor_info.dart';
import 'package:aniya/core/extractor/extractor_registry.dart';
import 'package:aniya/core/extractor/models/extractor_request.dart';
import 'package:aniya/core/extractor/models/raw_stream.dart';
import 'package:aniya/core/utils/logger.dart';

/// Local replica of ref/umbrella/.../ExtractorService.ts that dispatches embed
/// URLs to the correct extractor implementations using regex matching.
class LocalExtractorService {
  LocalExtractorService({ExtractorRegistry? registry})
    : _registry = registry ?? ExtractorRegistry();

  final ExtractorRegistry _registry;

  List<ExtractorInfo> getExtractors(ExtractorCategory category) =>
      _registry.byCategory(category);

  Future<List<RawStream>> extract(ExtractorRequest request) async {
    final matched = _registry.match(request);
    if (matched.isEmpty) {
      Logger.warning(
        'No extractor matched ${request.url.host}',
        tag: 'LocalExtractorService',
      );
      return const [];
    }

    final results = <RawStream>[];
    for (final info in matched) {
      for (final extractor in info.extractors) {
        final streams = await _safeExecute(extractor, request);
        if (streams.isNotEmpty) {
          results.addAll(streams);
        }
      }
    }
    return results;
  }

  Future<List<RawStream>> _safeExecute(
    BaseExtractor extractor,
    ExtractorRequest request,
  ) async {
    try {
      Logger.debug(
        'Running extractor ${extractor.name} on ${request.url}',
        tag: 'LocalExtractorService',
      );
      final streams = await extractor.extract(request);
      Logger.debug(
        '${extractor.name} returned ${streams.length} streams for ${request.url}',
        tag: 'LocalExtractorService',
      );
      return streams;
    } catch (error, stackTrace) {
      Logger.error(
        'Extractor ${extractor.name} failed',
        tag: 'LocalExtractorService',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }
}
