import 'dart:convert';

import 'package:aniya/core/extractor/base/base_extractor.dart';
import 'package:aniya/core/extractor/base/extractor_info.dart';
import 'package:aniya/core/extractor/models/extractor_request.dart';
import 'package:aniya/core/extractor/models/raw_stream.dart';
import 'package:aniya/core/utils/logger.dart';
import 'package:dio/dio.dart';

/// Ported from ref/umbrella/.../StreamingCommunityz.ts
/// Original code by yogesh-hacker: https://github.com/yogesh-hacker
/// Credit: https://github.com/yogesh-hacker/MediaVanced/blob/main/sites/streamingcommunityz.py
class StreamingCommunityzExtractor extends BaseExtractor {
  StreamingCommunityzExtractor({Dio? dio})
    : _dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));

  static final ExtractorInfo info = ExtractorInfo(
    id: 'streamingcommunityz',
    patterns: [RegExp(r'streamingcommunityz\.'), RegExp(r'vixcloud\.')],
    category: ExtractorCategory.video,
    extractors: [StreamingCommunityzExtractor()],
  );

  final Dio _dio;

  @override
  String get name => 'StreamingCommunityz';

  @override
  Future<List<RawStream>> extract(ExtractorRequest request) async {
    try {
      final defaultDomain = '${request.url.scheme}://${request.url.host}/';

      // Replace /watch/ with /iframe/ if needed
      final iframeUrl = request.url.toString().contains('/watch/')
          ? request.url.toString().replaceAll('/watch/', '/iframe/')
          : request.url.toString();

      final response = await _dio.getUri(
        Uri.parse(iframeUrl),
        options: Options(
          headers: {
            'Accept':
                'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
            'Referer': defaultDomain,
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Mobile Safari/537.36',
          },
        ),
      );

      final body = response.data as String;

      // Extract masterPlaylist JSON
      final match = RegExp(
        r'window\.masterPlaylist\s*=\s*({[\s\S]*?})\s*\n',
      ).firstMatch(body);

      if (match == null || match.group(1) == null) {
        Logger.warning('StreamingCommunityz: masterPlaylist not found');
        return const [];
      }

      final jsonStr = match.group(1) ?? '';

      // Try to parse JSON, with fallback for trailing commas
      Map<String, dynamic> playlistObj;
      try {
        playlistObj = jsonDecode(jsonStr) as Map<String, dynamic>;
      } catch (e) {
        try {
          final safe = jsonStr
              .replaceAll(RegExp(r',(\s*[}\]])'), r'$1')
              .replaceAll(RegExp(r'\bundefined\b'), 'null');
          playlistObj = jsonDecode(safe) as Map<String, dynamic>;
        } catch (e2) {
          Logger.warning('StreamingCommunityz: Failed to parse masterPlaylist');
          return const [];
        }
      }

      final masterUrl = playlistObj['url'] as String? ?? '';
      if (masterUrl.isEmpty) {
        Logger.warning('StreamingCommunityz: No master URL found');
        return const [];
      }

      final params = playlistObj['params'] as Map<String, dynamic>? ?? {};

      // Parse existing query params
      final uri = Uri.parse(masterUrl);
      final merged = <String, String>{};

      // Add existing params
      for (final entry in uri.queryParameters.entries) {
        merged[entry.key] = entry.value;
      }

      // Add/override with playlist params
      for (final entry in params.entries) {
        final value = entry.value;
        if (value is List) {
          merged[entry.key] = value.isNotEmpty ? value[0].toString() : '';
        } else {
          merged[entry.key] = value.toString();
        }
      }

      // Enforce h=1
      merged['h'] = '1';

      // Build final URL
      final queryString = Uri(queryParameters: merged).query;
      final finalUrl = '${uri.scheme}://${uri.host}${uri.path}?$queryString';

      return [
        RawStream(
          url: Uri.parse(finalUrl),
          isM3u8: finalUrl.contains('.m3u8'),
          sourceLabel: name,
        ),
      ];
    } catch (error, stackTrace) {
      Logger.error(
        'StreamingCommunityz extractor failed',
        tag: 'StreamingCommunityzExtractor',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }
}
