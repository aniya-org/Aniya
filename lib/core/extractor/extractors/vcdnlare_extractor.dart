import 'package:aniya/core/extractor/base/base_extractor.dart';
import 'package:aniya/core/extractor/base/extractor_info.dart';
import 'package:aniya/core/extractor/models/extractor_request.dart';
import 'package:aniya/core/extractor/models/raw_stream.dart';
import 'package:aniya/core/utils/logger.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html;

/// Ported from ref/umbrella/.../Vcdnlare.ts
/// Original code by yogesh-hacker: https://github.com/yogesh-hacker
/// Credit: https://github.com/yogesh-hacker/MediaVanced/blob/main/sites/vcdnlare.py
class VcdnlareExtractor extends BaseExtractor {
  VcdnlareExtractor({Dio? dio})
    : _dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));

  static final ExtractorInfo info = ExtractorInfo(
    id: 'vcdnlare',
    patterns: [RegExp(r'vcdnlare\.')],
    category: ExtractorCategory.video,
    extractors: [VcdnlareExtractor()],
  );

  final Dio _dio;

  @override
  String get name => 'Vcdnlare';

  @override
  Future<List<RawStream>> extract(ExtractorRequest request) async {
    try {
      final response = await _dio.getUri(
        request.url,
        options: Options(
          headers: {
            'Referer': request.url.toString(),
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36',
          },
        ),
      );

      final document = html.parse(response.data as String);

      // Try to find source element
      var sourceElement = document.querySelector('source');
      sourceElement ??= document.querySelector('video source');

      if (sourceElement == null) {
        Logger.warning('Vcdnlare: No source element found');
        return const [];
      }

      final src = sourceElement.attributes['src'];

      if (src == null || src.isEmpty) {
        Logger.warning('Vcdnlare: No src attribute found');
        return const [];
      }

      return [
        RawStream(
          url: Uri.parse(src),
          isM3u8: src.contains('.m3u8'),
          sourceLabel: name,
        ),
      ];
    } catch (error, stackTrace) {
      Logger.error(
        'Vcdnlare extractor failed',
        tag: 'VcdnlareExtractor',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }
}
