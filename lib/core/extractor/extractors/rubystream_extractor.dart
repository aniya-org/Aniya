import 'package:aniya/core/extractor/base/base_extractor.dart';
import 'package:aniya/core/extractor/base/extractor_info.dart';
import 'package:aniya/core/extractor/models/extractor_request.dart';
import 'package:aniya/core/extractor/models/raw_stream.dart';
import 'package:aniya/core/extractor/utils/js_unpacker.dart';
import 'package:aniya/core/utils/logger.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html;

/// Ported from ref/umbrella/.../Rubystream.ts
/// Original code by yogesh-hacker: https://github.com/yogesh-hacker
/// Credit: https://github.com/yogesh-hacker/MediaVanced/blob/main/sites/rubystream.py
class RubystreamExtractor extends BaseExtractor {
  RubystreamExtractor({Dio? dio})
    : _dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));

  static final ExtractorInfo info = ExtractorInfo(
    id: 'rubystream',
    patterns: [RegExp(r'rubystm\.'), RegExp(r'rubystream\.')],
    category: ExtractorCategory.video,
    extractors: [RubystreamExtractor()],
  );

  final Dio _dio;

  @override
  String get name => 'Rubystream';

  @override
  Future<List<RawStream>> extract(ExtractorRequest request) async {
    try {
      final defaultDomain = '${request.url.scheme}://${request.url.host}';

      final headers = {
        'Referer': defaultDomain,
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Mobile Safari/537.36',
      };

      // Fetch initial page
      final pageResponse = await _dio.getUri(
        request.url,
        options: Options(headers: headers),
      );

      final document = html.parse(pageResponse.data as String);

      // Extract form fields from form#F1
      final form = document.querySelector('form#F1');
      if (form == null) {
        Logger.warning('Rubystream: Form F1 not found');
        return const [];
      }

      final formData = <String, String>{};
      for (final input in form.querySelectorAll('input')) {
        final name = input.attributes['name'];
        final value = input.attributes['value'] ?? '';
        if (name != null) {
          formData[name] = value;
        }
      }

      // Add file_code and referer
      final fileCode = request.url.path.split('/').last;
      formData['file_code'] = fileCode;
      formData['referer'] = defaultDomain;

      // Build URL-encoded payload
      final params = Uri(queryParameters: formData).query;

      // Submit form
      final dlResponse = await _dio.post(
        '$defaultDomain/dl',
        data: params,
        options: Options(
          headers: {
            ...headers,
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        ),
      );

      final body = dlResponse.data as String;

      // Extract packed data
      final pattern = RegExp(
        r'eval\(function\((.*?)\)\{.*\}\((.*?\))\)\)',
        dotAll: true,
      );
      final match = pattern.firstMatch(body);

      if (match == null) {
        Logger.warning('Rubystream: Packed data not found');
        return const [];
      }

      var dataString = (match.group(2) ?? '').replaceAll(".split('|')", '');

      // Unpack
      final unpacked = safeUnpack(dataString);
      final decoded = unpacked.replaceAll(RegExp(r'\\'), '');

      // Extract file URL
      final fileMatch =
          RegExp(r'file:"(.*?)"').firstMatch(decoded) ??
          RegExp(r"file:'(.*?)'").firstMatch(decoded);

      if (fileMatch == null || fileMatch.group(1) == null) {
        Logger.warning('Rubystream: Video URL not found');
        return const [];
      }

      final videoSrc = fileMatch.group(1) ?? '';

      return [
        RawStream(
          url: Uri.parse(videoSrc),
          isM3u8: videoSrc.contains('.m3u8'),
          sourceLabel: name,
        ),
      ];
    } catch (error, stackTrace) {
      Logger.error(
        'Rubystream extractor failed',
        tag: 'RubystreamExtractor',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }
}
