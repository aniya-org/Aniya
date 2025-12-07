import 'package:aniya/core/extractor/base/base_extractor.dart';
import 'package:aniya/core/extractor/base/extractor_info.dart';
import 'package:aniya/core/extractor/models/extractor_request.dart';
import 'package:aniya/core/extractor/models/raw_stream.dart';
import 'package:aniya/core/utils/logger.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html;

/// Ported from ref/umbrella/.../Uperbox.ts
/// Original code by yogesh-hacker: https://github.com/yogesh-hacker
/// Credit: https://github.com/yogesh-hacker/MediaVanced/blob/main/sites/uperbox.py
class UperboxExtractor extends BaseExtractor {
  UperboxExtractor({Dio? dio})
    : _dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));

  static final ExtractorInfo info = ExtractorInfo(
    id: 'uperbox',
    patterns: [RegExp(r'uperbox\.')],
    category: ExtractorCategory.video,
    extractors: [UperboxExtractor()],
  );

  final Dio _dio;

  @override
  String get name => 'Uperbox';

  @override
  Future<List<RawStream>> extract(ExtractorRequest request) async {
    try {
      final defaultDomain = '${request.url.scheme}://${request.url.host}';

      // Fetch main page
      final pageResponse = await _dio.getUri(
        request.url,
        options: Options(
          headers: {
            'Referer': defaultDomain,
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36',
          },
        ),
      );

      final document = html.parse(pageResponse.data as String);

      // Find main container
      final mainContainer = document.querySelector('.main-container');
      if (mainContainer == null) {
        Logger.warning('Uperbox: Main container not found');
        return const [];
      }

      // Find next page link
      final nextAnchor = mainContainer.querySelector('a.btn');
      if (nextAnchor == null) {
        Logger.warning('Uperbox: Next page link not found');
        return const [];
      }

      final nextHref = nextAnchor.attributes['href'];
      if (nextHref == null || nextHref.isEmpty) {
        Logger.warning('Uperbox: Next href not found');
        return const [];
      }

      // Resolve next URL
      final nextUrl = Uri.parse(
        request.url.toString(),
      ).resolve(nextHref).toString();

      // Fetch next page
      final nextResponse = await _dio.getUri(
        Uri.parse(nextUrl),
        options: Options(
          headers: {
            'Referer': request.url.toString(),
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36',
          },
        ),
      );

      final nextDocument = html.parse(nextResponse.data as String);

      // Find download link
      dynamic downloadLink;
      for (final el in nextDocument.querySelectorAll('a')) {
        final text = el.text.toLowerCase();
        if (text.contains('start download')) {
          downloadLink = el;
          break;
        }
      }

      if (downloadLink == null) {
        Logger.warning('Uperbox: Download link not found');
        return const [];
      }

      final downloadHref = downloadLink.attributes['href'];
      if (downloadHref == null || downloadHref.isEmpty) {
        Logger.warning('Uperbox: Download href not found');
        return const [];
      }

      // Resolve video URL
      final videoUrl = Uri.parse(
        defaultDomain,
      ).resolve(downloadHref).toString();

      return [
        RawStream(
          url: Uri.parse(videoUrl),
          isM3u8: videoUrl.contains('.m3u8'),
          sourceLabel: name,
        ),
      ];
    } catch (error, stackTrace) {
      Logger.error(
        'Uperbox extractor failed',
        tag: 'UperboxExtractor',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }
}
