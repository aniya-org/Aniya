import 'package:aniya/core/extractor/base/base_extractor.dart';
import 'package:aniya/core/extractor/base/extractor_info.dart';
import 'package:aniya/core/extractor/models/extractor_request.dart';
import 'package:aniya/core/extractor/models/raw_stream.dart';
import 'package:aniya/core/utils/logger.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html;

/// Ported from ref/umbrella/.../Send.ts
/// Original code by yogesh-hacker: https://github.com/yogesh-hacker
/// Credit: https://github.com/yogesh-hacker/MediaVanced/blob/main/sites/send.py
class SendExtractor extends BaseExtractor {
  SendExtractor({Dio? dio})
    : _dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));

  static final ExtractorInfo info = ExtractorInfo(
    id: 'send',
    patterns: [RegExp(r'send\.cm'), RegExp(r'send\.now')],
    category: ExtractorCategory.video,
    extractors: [SendExtractor()],
  );

  final Dio _dio;

  @override
  String get name => 'Send';

  @override
  Future<List<RawStream>> extract(ExtractorRequest request) async {
    try {
      final defaultDomain = '${request.url.scheme}://${request.url.host}/';

      // Fetch page and extract form
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
      final form = document.querySelector('form[name="F1"]');

      if (form == null) {
        Logger.warning('Send: Form F1 not found');
        return const [];
      }

      // Extract form fields
      final payload = <String, String>{};
      for (final input in form.querySelectorAll('input[name]')) {
        final name = input.attributes['name'];
        final value = input.attributes['value'] ?? '';
        if (name != null) {
          payload[name] = value;
        }
      }

      // Build URL-encoded payload
      final params = Uri(queryParameters: payload).query;

      // Submit form with no redirects to capture Location header
      try {
        await _dio.post(
          defaultDomain,
          data: params,
          options: Options(
            headers: {
              'Referer': defaultDomain,
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36',
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            followRedirects: false,
            validateStatus: (status) => status != null && status < 500,
          ),
        );
      } catch (e) {
        // Capture redirect location from error
        if (e is DioException && e.response != null) {
          final location =
              e.response?.headers.value('location') ??
              e.response?.headers.value('Location');

          if (location != null && location.isNotEmpty) {
            return [
              RawStream(
                url: Uri.parse(location),
                isM3u8: location.contains('.m3u8'),
                sourceLabel: name,
              ),
            ];
          }
        }
        Logger.warning('Send: Redirect location not found');
        return const [];
      }

      Logger.warning('Send: No redirect captured');
      return const [];
    } catch (error, stackTrace) {
      Logger.error(
        'Send extractor failed',
        tag: 'SendExtractor',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }
}
