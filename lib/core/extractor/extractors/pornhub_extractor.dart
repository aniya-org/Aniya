import 'dart:convert';

import 'package:aniya/core/extractor/base/base_extractor.dart';
import 'package:aniya/core/extractor/base/extractor_info.dart';
import 'package:aniya/core/extractor/models/extractor_request.dart';
import 'package:aniya/core/extractor/models/raw_stream.dart';
import 'package:aniya/core/utils/logger.dart';
import 'package:dio/dio.dart';

/// Ported from ref/umbrella/.../Pornhub.ts
/// Original code by yogesh-hacker: https://github.com/yogesh-hacker
/// Credit: https://github.com/yogesh-hacker/MediaVanced/blob/main/sites/pornhub.py
/// Note: 18+ content extractor
class PornhubExtractor extends BaseExtractor {
  PornhubExtractor({Dio? dio})
    : _dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));

  static final ExtractorInfo info = ExtractorInfo(
    id: 'pornhub',
    patterns: [RegExp(r'pornhub\.'), RegExp(r'pornhub\.com')],
    category: ExtractorCategory.video,
    extractors: [PornhubExtractor()],
  );

  final Dio _dio;

  @override
  String get name => 'Pornhub';

  @override
  Future<List<RawStream>> extract(ExtractorRequest request) async {
    try {
      final response = await _dio.getUri(
        request.url,
        options: Options(
          headers: {
            'Referer': 'https://www.pornhub.org/',
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Mobile Safari/537.36',
          },
        ),
      );

      final body = response.data as String;

      // Extract flashvars JSON
      final match = RegExp(
        r'var\s+flashvars_\d+\s*=\s*({[\s\S]*?});',
      ).firstMatch(body);

      if (match == null || match.group(1) == null) {
        Logger.warning('Pornhub: flashvars not found');
        return const [];
      }

      final jsonStr = match.group(1) ?? '';

      Map<String, dynamic> parsed;
      try {
        parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
      } catch (e) {
        Logger.warning('Pornhub: Failed to parse flashvars JSON');
        return const [];
      }

      final List<RawStream> streams = [];
      final mediaDefinitions =
          parsed['mediaDefinitions'] as List<dynamic>? ?? [];

      for (final def in mediaDefinitions) {
        final defMap = def as Map<String, dynamic>?;
        if (defMap == null) continue;

        final format = defMap['format'] as String? ?? '';
        final videoUrl = defMap['videoUrl'] as String? ?? '';
        final height = defMap['height'] as int? ?? 0;

        if (format == 'hls' && videoUrl.isNotEmpty) {
          streams.add(
            RawStream(
              url: Uri.parse(videoUrl),
              isM3u8: true,
              quality: height > 0 ? '${height}p' : null,
              sourceLabel: name,
            ),
          );
        }
      }

      if (streams.isEmpty) {
        Logger.warning('Pornhub: No HLS streams found');
        return const [];
      }

      return streams;
    } catch (error, stackTrace) {
      Logger.error(
        'Pornhub extractor failed',
        tag: 'PornhubExtractor',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }
}
