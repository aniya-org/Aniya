import 'dart:convert';

import 'package:aniya/core/extractor/base/base_extractor.dart';
import 'package:aniya/core/extractor/base/extractor_info.dart';
import 'package:aniya/core/extractor/models/extractor_request.dart';
import 'package:aniya/core/extractor/models/raw_stream.dart';
import 'package:aniya/core/utils/logger.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html;

/// Ported from ref/umbrella/.../Megacloud.ts
/// Original code by yogesh-hacker: https://github.com/yogesh-hacker
/// Credit: https://github.com/yogesh-hacker/MediaVanced/blob/main/sites/megacloud.py
class MegacloudExtractor extends BaseExtractor {
  MegacloudExtractor({Dio? dio})
    : _dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));

  static final ExtractorInfo info = ExtractorInfo(
    id: 'megacloud',
    patterns: [
      RegExp(r'megacloud\.'),
      RegExp(r'megacloud\.blog'),
      RegExp(r'videostr\.net'),
    ],
    category: ExtractorCategory.video,
    extractors: [MegacloudExtractor()],
  );

  final Dio _dio;
  final String _decodeEndpoint =
      'https://script.google.com/macros/s/AKfycbxHbYHbrGMXYD2-bC-C43D3njIbU-wGiYQuJL61H4vyy6YVXkybMNNEPJNPPuZrD1gRVA/exec';

  @override
  String get name => 'Megacloud';

  @override
  Future<List<RawStream>> extract(ExtractorRequest request) async {
    try {
      final options = Options(
        headers: {
          'Accept': '*/*',
          'X-Requested-With': 'XMLHttpRequest',
          'Referer': request.url.toString(),
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Mobile Safari/537.36',
        },
      );

      // Fetch page and parse file ID
      final pageResponse = await _dio.getUri(request.url, options: options);
      final document = html.parse(pageResponse.data as String);

      final playerDiv = document.getElementById('megacloud-player');
      if (playerDiv == null) {
        Logger.warning('Megacloud: Player div not found');
        return const [];
      }

      final fileId =
          playerDiv.attributes['data-id'] ??
          playerDiv.attributes['data-file'] ??
          '';

      if (fileId.isEmpty) {
        Logger.warning('Megacloud: File ID not found');
        return const [];
      }

      // Try to extract nonce from HTML
      final rawHtml = pageResponse.data as String;
      String? nonce;

      final match48 = RegExp(r'\b[a-zA-Z0-9]{48}\b').firstMatch(rawHtml);
      if (match48 != null) {
        nonce = match48.group(0);
      } else {
        final grp = RegExp(
          r'([a-zA-Z0-9]{16}).*?([a-zA-Z0-9]{16}).*?([a-zA-Z0-9]{16})',
          dotAll: true,
        ).firstMatch(rawHtml);
        if (grp != null && grp.groupCount >= 3) {
          nonce =
              (grp.group(1) ?? '') +
              (grp.group(2) ?? '') +
              (grp.group(3) ?? '');
        }
      }

      // Build request to get sources
      final domain = '${request.url.scheme}://${request.url.host}';
      final getSourcesUrl =
          '$domain/embed-2/v3/e-1/getSources?id=${Uri.encodeComponent(fileId)}${nonce != null ? '&_k=${Uri.encodeComponent(nonce)}' : ''}';

      final sourcesRes = await _dio.get(getSourcesUrl, options: options);
      final payload = sourcesRes.data as Map<String, dynamic>?;

      if (payload == null) {
        Logger.warning('Megacloud: No payload received');
        return const [];
      }

      String videoUrl = '';

      // Try to extract video URL from various payload formats
      if (payload['sources'] is String) {
        // Encrypted sources - try to use decode endpoint
        final encrypted = Uri.encodeComponent(payload['sources'] as String);
        final nonceParam = nonce != null ? Uri.encodeComponent(nonce) : '';
        final decodeUrl =
            '$_decodeEndpoint?encrypted_data=$encrypted&nonce=$nonceParam&secret=';

        try {
          final decoded = await _dio.get(decodeUrl, options: options);
          final decodedText = decoded.data as String? ?? '';
          final fileMatch = RegExp(r'"file":"(.*?)"').firstMatch(decodedText);
          if (fileMatch != null && fileMatch.group(1) != null) {
            videoUrl = fileMatch.group(1) ?? '';
          }
        } catch (e) {
          Logger.warning('Megacloud: Decode endpoint failed');
        }
      } else if (payload['sources'] is List) {
        final sources = payload['sources'] as List<dynamic>;
        if (sources.isNotEmpty && sources[0] is Map) {
          videoUrl =
              (sources[0] as Map<String, dynamic>)['file'] as String? ?? '';
        }
      } else if (payload['sources'] is Map) {
        final sourcesMap = payload['sources'] as Map<String, dynamic>;
        videoUrl = sourcesMap['file'] as String? ?? '';
      }

      // Fallback: search in raw JSON
      if (videoUrl.isEmpty) {
        final raw = jsonEncode(payload);
        final fallbackMatch = RegExp(r'"file":"(.*?)"').firstMatch(raw);
        if (fallbackMatch != null && fallbackMatch.group(1) != null) {
          videoUrl = fallbackMatch.group(1) ?? '';
        }
      }

      if (videoUrl.isEmpty) {
        Logger.warning('Megacloud: Could not extract video URL');
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
        'Megacloud extractor failed',
        tag: 'MegacloudExtractor',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }
}
