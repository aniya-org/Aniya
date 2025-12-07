import 'package:aniya/core/extractor/base/base_extractor.dart';
import 'package:aniya/core/extractor/base/extractor_info.dart';
import 'package:aniya/core/extractor/models/extractor_request.dart';
import 'package:aniya/core/extractor/models/raw_stream.dart';
import 'package:aniya/core/utils/logger.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html;

/// Ported from ref/umbrella/.../Pornhat.ts
/// Original code by yogesh-hacker: https://github.com/yogesh-hacker
/// Credit: https://github.com/yogesh-hacker/MediaVanced/blob/main/sites/pornhat.py
/// Note: 18+ content extractor
class PornhatExtractor extends BaseExtractor {
  PornhatExtractor({Dio? dio})
    : _dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));

  static final ExtractorInfo info = ExtractorInfo(
    id: 'pornhat',
    patterns: [RegExp(r'pornhat\.'), RegExp(r'pornhat\.com')],
    category: ExtractorCategory.video,
    extractors: [PornhatExtractor()],
  );

  final Dio _dio;

  @override
  String get name => 'Pornhat';

  @override
  Future<List<RawStream>> extract(ExtractorRequest request) async {
    try {
      final response = await _dio.getUri(
        request.url,
        options: Options(
          headers: {
            'Referer': request.url.toString(),
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
          },
        ),
      );

      final document = html.parse(response.data as String);

      // Try to find 720p video element
      var el = document.querySelector('.video_720p[label="720p"]');
      var src = el?.attributes['src'];

      // Fallback: try without label attribute
      if (src == null || src.isEmpty) {
        el = document.querySelector('.video_720p');
        src = el?.attributes['src'];
      }

      // Fallback: try video source with label
      if (src == null || src.isEmpty) {
        el = document.querySelector('video source[label="720p"]');
        src = el?.attributes['src'];
      }

      if (src == null || src.isEmpty) {
        Logger.warning('Pornhat: Video source not found');
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
        'Pornhat extractor failed',
        tag: 'PornhatExtractor',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }
}
