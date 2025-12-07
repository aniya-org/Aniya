import 'package:aniya/core/extractor/base/base_extractor.dart';
import 'package:aniya/core/extractor/base/extractor_info.dart';
import 'package:aniya/core/extractor/models/extractor_request.dart';
import 'package:aniya/core/extractor/models/raw_stream.dart';
import 'package:aniya/core/utils/logger.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html;

/// Ported from ref/umbrella/.../StreamTape.ts (originally adapted from
/// https://github.com/2004durgesh/react-native-consumet and MediaVanced).
class StreamTapeExtractor extends BaseExtractor {
  StreamTapeExtractor({Dio? dio})
    : _dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));

  static final ExtractorInfo info = ExtractorInfo(
    id: 'streamtape',
    patterns: [RegExp(r'streamtape\.'), RegExp(r'shavetape\.cash')],
    category: ExtractorCategory.video,
    extractors: [StreamTapeExtractor()],
  );

  final Dio _dio;

  @override
  String get name => 'StreamTape';

  @override
  Future<List<RawStream>> extract(ExtractorRequest request) async {
    try {
      final response = await _dio.getUri(request.url);
      final document = html.parse(response.data as String);
      final htmlString = document.outerHtml;
      final match = RegExp(
        r"robotlink'\)\.innerHTML = (.*?)'",
      ).firstMatch(htmlString);
      if (match == null) {
        Logger.warning(
          'StreamTape: robotlink snippet not found for ${request.url}',
        );
        return const [];
      }

      final expression = match.group(1) ?? '';
      final parts = expression.split("+ ('");
      if (parts.isEmpty) {
        Logger.warning(
          'StreamTape: unexpected expression format for ${request.url}',
        );
        return const [];
      }
      var first = parts[0].replaceAll("'", '').trim();
      var second = parts.length > 1 ? parts[1] : '';
      if (second.isNotEmpty) {
        second = second.substring(
          3,
        ); // drop leading characters as in TS implementation
      }
      final url = 'https:$first$second';

      return [
        RawStream(
          url: Uri.parse(url),
          isM3u8: url.contains('.m3u8'),
          sourceLabel: name,
        ),
      ];
    } catch (error, stackTrace) {
      Logger.error(
        'StreamTape extractor failed',
        tag: 'StreamTapeExtractor',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }
}
