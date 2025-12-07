import 'package:aniya/core/extractor/base/base_extractor.dart';
import 'package:aniya/core/extractor/base/extractor_info.dart';
import 'package:aniya/core/extractor/models/extractor_request.dart';
import 'package:aniya/core/extractor/models/raw_stream.dart';
import 'package:aniya/core/utils/logger.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html;

/// Ported from ref/umbrella/.../SmashyStream.ts
/// Original code by 2004durgesh: https://github.com/2004durgesh
/// Credit: https://github.com/2004durgesh/react-native-consumet
/// Note: Simplified implementation - full multi-source extraction deferred
class SmashyStreamExtractor extends BaseExtractor {
  SmashyStreamExtractor({Dio? dio})
    : _dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));

  static final ExtractorInfo info = ExtractorInfo(
    id: 'smashystream',
    patterns: [RegExp(r'smashystream\.'), RegExp(r'embed\.smashystream\.com')],
    category: ExtractorCategory.video,
    extractors: [SmashyStreamExtractor()],
  );

  final Dio _dio;

  @override
  String get name => 'SmashyStream';

  @override
  Future<List<RawStream>> extract(ExtractorRequest request) async {
    try {
      final response = await _dio.getUri(
        request.url,
        options: Options(headers: {'Referer': request.url.toString()}),
      );

      final document = html.parse(response.data as String);

      // Extract source URLs from dropdown menu
      final sourceElements = document.querySelectorAll(
        '.dropdown-menu a[data-id]',
      );
      if (sourceElements.isEmpty) {
        Logger.warning('SmashyStream: No sources found');
        return const [];
      }

      final streams = <RawStream>[];

      // Try to extract from first available source
      for (final element in sourceElements) {
        final sourceId = element.attributes['data-id'];
        if (sourceId == null || sourceId == '_default') continue;

        // Determine source type and create appropriate URL
        String sourceType = 'unknown';
        if (sourceId.contains('/ffix')) {
          sourceType = 'FFix';
        } else if (sourceId.contains('/watchx')) {
          sourceType = 'WatchX';
        } else if (sourceId.contains('/nflim')) {
          sourceType = 'NFlim';
        } else if (sourceId.contains('/fx')) {
          sourceType = 'FX';
        } else if (sourceId.contains('/cf')) {
          sourceType = 'CF';
        } else if (sourceId.contains('eemovie')) {
          sourceType = 'EEMovie';
        }

        streams.add(
          RawStream(
            url: Uri.parse(sourceId),
            isM3u8: false,
            quality: sourceType,
            sourceLabel: '$name ($sourceType)',
          ),
        );
      }

      if (streams.isEmpty) {
        Logger.warning('SmashyStream: No valid sources extracted');
        return const [];
      }

      return streams;
    } catch (error, stackTrace) {
      Logger.error(
        'SmashyStream extractor failed',
        tag: 'SmashyStreamExtractor',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }
}
