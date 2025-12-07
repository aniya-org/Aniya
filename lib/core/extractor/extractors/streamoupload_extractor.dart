import 'package:aniya/core/extractor/base/base_extractor.dart';
import 'package:aniya/core/extractor/base/extractor_info.dart';
import 'package:aniya/core/extractor/models/extractor_request.dart';
import 'package:aniya/core/extractor/models/raw_stream.dart';
import 'package:aniya/core/extractor/utils/js_unpacker.dart';
import 'package:aniya/core/utils/logger.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html;

/// Ported from ref/umbrella/.../StreamOUpload.ts
/// Original code by yogesh-hacker: https://github.com/yogesh-hacker
/// Credit: https://github.com/yogesh-hacker/MediaVanced/blob/main/sites/streamoupload.py
class StreamOUploadExtractor extends BaseExtractor {
  StreamOUploadExtractor({Dio? dio})
    : _dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));

  static final ExtractorInfo info = ExtractorInfo(
    id: 'streamoupload',
    patterns: [RegExp(r'streamoupload\.')],
    category: ExtractorCategory.video,
    extractors: [StreamOUploadExtractor()],
  );

  final Dio _dio;

  @override
  String get name => 'StreamOUpload';

  @override
  Future<List<RawStream>> extract(ExtractorRequest request) async {
    try {
      final response = await _dio.getUri(
        request.url,
        options: Options(
          headers: {
            'Referer': request.url.toString(),
            'User-Agent':
                'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          },
        ),
      );

      final document = html.parse(response.data as String);

      // Find script with packed JavaScript
      String? jsCode;
      for (final script in document.querySelectorAll('script')) {
        final content = script.text;
        if (content.contains('eval(function(p,a,c,k,e,d)')) {
          jsCode = content;
          break;
        }
      }

      if (jsCode == null) {
        Logger.warning('StreamOUpload: Packed JavaScript not found');
        return const [];
      }

      // Extract packed payload
      final encodedMatch = RegExp(
        r'eval\(function\([^\)]*\)\{[^\}]*\}\(([\s\S]*?)\)\)',
      ).firstMatch(jsCode);

      if (encodedMatch == null || encodedMatch.group(1) == null) {
        Logger.warning('StreamOUpload: Packed payload not found');
        return const [];
      }

      var payload = encodedMatch.group(1) ?? '';

      // Clean obvious wrappers
      payload = payload.replaceAll(RegExp(r"\.split\('\|'\)"), '');

      // Unpack
      final unpacked = safeUnpack(payload);
      final decoded = unpacked.replaceAll('\\', '');

      // Extract file URL
      final fileMatch =
          RegExp(r'file:"([^"]+)"').firstMatch(decoded) ??
          RegExp(r"file:'([^']+)'").firstMatch(decoded);

      if (fileMatch == null || fileMatch.group(1) == null) {
        Logger.warning('StreamOUpload: Video URL not found');
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
        'StreamOUpload extractor failed',
        tag: 'StreamOUploadExtractor',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }
}
