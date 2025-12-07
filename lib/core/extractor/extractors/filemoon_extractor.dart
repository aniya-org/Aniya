import 'package:aniya/core/extractor/base/base_extractor.dart';
import 'package:aniya/core/extractor/base/extractor_info.dart';
import 'package:aniya/core/extractor/models/extractor_request.dart';
import 'package:aniya/core/extractor/models/raw_stream.dart';
import 'package:aniya/core/extractor/utils/js_unpacker.dart';
import 'package:aniya/core/utils/logger.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html;

/// Ported from ref/umbrella/.../Filemoon.ts
/// Original code by 2004durgesh: https://github.com/2004durgesh
/// Credit: https://github.com/2004durgesh/react-native-consumet/blob/main/src/extractors/filemoon.ts
class FilemoonExtractor extends BaseExtractor {
  FilemoonExtractor({Dio? dio})
    : _dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));

  static final ExtractorInfo info = ExtractorInfo(
    id: 'filemoon',
    patterns: [
      RegExp(r'filemoon\.'),
      RegExp(r'filemoon\.to'),
      RegExp(r'2glho\.org'),
    ],
    category: ExtractorCategory.video,
    extractors: [FilemoonExtractor()],
  );

  final Dio _dio;
  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  @override
  String get name => 'Filemoon';

  @override
  Future<List<RawStream>> extract(ExtractorRequest request) async {
    try {
      final uri = request.url;
      final options = Options(
        headers: {
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
          'Accept-Language': 'en-US,en;q=0.9',
          'Referer': uri.origin,
          'Origin': uri.toString(),
          'User-Agent': _userAgent,
        },
      );

      final response = await _dio.getUri(uri, options: options);
      final document = html.parse(response.data as String);

      final iframeElement = document.querySelector('iframe');
      final iframeSrc = iframeElement?.attributes['src'];

      if (iframeSrc == null || iframeSrc.isEmpty) {
        Logger.warning('Filemoon: Could not find iframe source');
        return const [];
      }

      final iframeResponse = await _dio.get(iframeSrc, options: options);

      final iframeData = iframeResponse.data as String;

      // Extract packed JavaScript safely without eval()
      final evalMatch = RegExp(
        r'(eval)(\(f.*?)(\n<\/script>)',
        dotAll: true,
      ).firstMatch(iframeData);

      if (evalMatch == null || evalMatch.group(2) == null) {
        Logger.warning('Filemoon: Could not find packed JavaScript code');
        return const [];
      }

      final packedCode = (evalMatch.group(2) ?? '')
          .replaceAll('eval', '')
          .replaceAll(RegExp(r'^\(|\)$'), '');

      final unpackedData = safeUnpack(packedCode);

      final linksMatch = RegExp(
        r'sources:\[\{file:"(.*?)"',
      ).firstMatch(unpackedData);

      if (linksMatch == null || linksMatch.group(1) == null) {
        Logger.warning(
          'Filemoon: Could not extract video source from unpacked data',
        );
        return const [];
      }

      final m3u8Link = linksMatch.group(1) ?? '';

      return [
        RawStream(url: Uri.parse(m3u8Link), isM3u8: true, sourceLabel: name),
      ];
    } catch (error, stackTrace) {
      Logger.error(
        'Filemoon extractor failed',
        tag: 'FilemoonExtractor',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }
}
