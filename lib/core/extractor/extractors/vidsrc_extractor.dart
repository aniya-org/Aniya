import 'package:aniya/core/extractor/base/base_extractor.dart';
import 'package:aniya/core/extractor/base/extractor_info.dart';
import 'package:aniya/core/extractor/models/extractor_request.dart';
import 'package:aniya/core/extractor/models/raw_stream.dart';
import 'package:aniya/core/utils/logger.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html;

/// Ported from ref/umbrella/.../VidSrc.ts
/// Original code by yogesh-hacker: https://github.com/yogesh-hacker
/// Credit: https://github.com/yogesh-hacker/MediaVanced/blob/main/sites/vidsrc.py
class VidSrcExtractor extends BaseExtractor {
  VidSrcExtractor({Dio? dio})
    : _dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));

  static final ExtractorInfo info = ExtractorInfo(
    id: 'vidsrc',
    patterns: [RegExp(r'vidsrc\.'), RegExp(r'vidsrc\.to')],
    category: ExtractorCategory.video,
    extractors: [VidSrcExtractor()],
  );

  final Dio _dio;

  @override
  String get name => 'VidSrc';

  @override
  Future<List<RawStream>> extract(ExtractorRequest request) async {
    try {
      final defaultDomain = '${request.url.scheme}://${request.url.host}/';

      // Fetch main page
      final pageResponse = await _dio.getUri(
        request.url,
        options: Options(
          headers: {
            'Referer': defaultDomain,
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Mobile Safari/537.36',
          },
        ),
      );

      final document = html.parse(pageResponse.data as String);

      // Try to find player iframe
      var iframeElement = document.querySelector('#player_iframe');
      var iframeSrc = iframeElement?.attributes['src'];

      // Fallback: try .xyz domain
      if (iframeSrc == null || iframeSrc.isEmpty) {
        final altUrl = request.url.toString().replaceAll('.to', '.xyz');
        try {
          final altResponse = await _dio.getUri(
            Uri.parse(altUrl),
            options: Options(headers: {'Referer': defaultDomain}),
          );
          final altDocument = html.parse(altResponse.data as String);
          iframeElement = altDocument.querySelector('#player_iframe');
          iframeSrc = iframeElement?.attributes['src'];
        } catch (e) {
          Logger.warning('VidSrc: Fallback .xyz domain failed');
        }
      }

      if (iframeSrc == null || iframeSrc.isEmpty) {
        Logger.warning('VidSrc: Player iframe not found');
        return const [];
      }

      // Ensure absolute URL
      final fullIframeSrc = iframeSrc.startsWith('http')
          ? iframeSrc
          : 'https:$iframeSrc';

      // Fetch iframe page
      final iframeResponse = await _dio.getUri(
        Uri.parse(fullIframeSrc),
        options: Options(
          headers: {
            'Referer': defaultDomain,
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Mobile Safari/537.36',
          },
        ),
      );

      final iframeHtml = iframeResponse.data as String;

      // Find prorcp iframe src
      final prorcpMatch = RegExp(r"src:\s*'(.*?)'").firstMatch(iframeHtml);
      if (prorcpMatch == null || prorcpMatch.group(1) == null) {
        Logger.warning('VidSrc: Prorcp iframe not found');
        return const [];
      }

      final prorcpPath = prorcpMatch.group(1) ?? '';

      // Resolve relative URL
      final iframeUri = Uri.parse(fullIframeSrc);
      final iframeBase = '${iframeUri.scheme}://${iframeUri.host}/';
      final finalIframeSrc = prorcpPath.startsWith('http')
          ? prorcpPath
          : Uri.parse(iframeBase).resolve(prorcpPath).toString();

      // Fetch final iframe
      final finalResponse = await _dio.getUri(
        Uri.parse(finalIframeSrc),
        options: Options(
          headers: {
            'Referer': fullIframeSrc,
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Mobile Safari/537.36',
          },
        ),
      );

      final finalHtml = finalResponse.data as String;

      // Extract file URL
      final fileMatch = RegExp(
        r'''file:\s*['"]([^'"]+)['"]''',
      ).firstMatch(finalHtml);

      if (fileMatch == null || fileMatch.group(1) == null) {
        Logger.warning('VidSrc: Video URL not found');
        return const [];
      }

      final videoUrl = fileMatch.group(1) ?? '';

      return [
        RawStream(
          url: Uri.parse(videoUrl),
          isM3u8: videoUrl.contains('.m3u8'),
          sourceLabel: name,
        ),
      ];
    } catch (error, stackTrace) {
      Logger.error(
        'VidSrc extractor failed',
        tag: 'VidSrcExtractor',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }
}
