import 'dart:convert';

import 'package:aniya/core/extractor/base/base_extractor.dart';
import 'package:aniya/core/extractor/base/extractor_info.dart';
import 'package:aniya/core/extractor/models/extractor_request.dart';
import 'package:aniya/core/extractor/models/raw_stream.dart';
import 'package:aniya/core/utils/logger.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html;

/// Ported from ref/umbrella/.../Photojin.ts
/// Original code by yogesh-hacker: https://github.com/yogesh-hacker
/// Credit: https://github.com/yogesh-hacker/MediaVanced/blob/main/sites/photojin.py
class PhotojinExtractor extends BaseExtractor {
  PhotojinExtractor({Dio? dio})
    : _dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));

  static final ExtractorInfo info = ExtractorInfo(
    id: 'photojin',
    patterns: [RegExp(r'photojin\.')],
    category: ExtractorCategory.video,
    extractors: [PhotojinExtractor()],
  );

  final Dio _dio;

  @override
  String get name => 'Photojin';

  @override
  Future<List<RawStream>> extract(ExtractorRequest request) async {
    try {
      // Fetch page with redirects
      final sessionResponse = await _dio.getUri(
        request.url,
        options: Options(followRedirects: true),
      );

      final defaultDomain = '${request.url.scheme}://${request.url.host}';

      final document = html.parse(sessionResponse.data as String);

      // Extract data fields
      final dataField = document.getElementById('generate_url');
      if (dataField == null) {
        Logger.warning('Photojin: generate_url element not found');
        return const [];
      }

      final uid = dataField.attributes['data-uid'];
      final token = dataField.attributes['data-token'];

      if (uid == null || uid.isEmpty || token == null || token.isEmpty) {
        Logger.warning('Photojin: Required fields (uid/token) not found');
        return const [];
      }

      // Build payload
      final payload = {
        'type': 'DOWNLOAD_GENERATE',
        'payload': {'uid': uid, 'access_token': token},
      };

      // Make POST request
      final postRes = await _dio.post(
        '$defaultDomain/action',
        data: jsonEncode(payload),
        options: Options(
          headers: {
            'Referer': defaultDomain,
            'X-Requested-With': 'xmlhttprequest',
            'Content-Type': 'application/json',
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36',
          },
        ),
      );

      final responseData = postRes.data as Map<String, dynamic>?;
      if (responseData == null) {
        Logger.warning('Photojin: No response data');
        return const [];
      }

      final videoUrl = responseData['download_url'] as String? ?? '';

      if (videoUrl.isEmpty) {
        Logger.warning('Photojin: download_url not found');
        return const [];
      }

      return [
        RawStream(
          url: Uri.parse(videoUrl),
          isM3u8: videoUrl.contains('.m3u8'),
          sourceLabel: name,
        ),
      ];
    } catch (error, stackTrace) {
      Logger.error(
        'Photojin extractor failed',
        tag: 'PhotojinExtractor',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }
}
