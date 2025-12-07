import 'dart:convert';

import 'package:aniya/core/extractor/base/base_extractor.dart';
import 'package:aniya/core/extractor/base/extractor_info.dart';
import 'package:aniya/core/extractor/models/extractor_request.dart';
import 'package:aniya/core/extractor/models/raw_stream.dart';
import 'package:aniya/core/utils/logger.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html;

/// Ported from ref/umbrella/.../Saicord.ts
/// Original code by yogesh-hacker: https://github.com/yogesh-hacker
/// Credit: https://github.com/yogesh-hacker/MediaVanced/blob/main/sites/saicord.py
class SaicordExtractor extends BaseExtractor {
  SaicordExtractor({Dio? dio})
    : _dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));

  static final ExtractorInfo info = ExtractorInfo(
    id: 'saicord',
    patterns: [RegExp(r'saicord\.')],
    category: ExtractorCategory.video,
    extractors: [SaicordExtractor()],
  );

  final Dio _dio;

  @override
  String get name => 'Saicord';

  @override
  Future<List<RawStream>> extract(ExtractorRequest request) async {
    try {
      final response = await _dio.getUri(
        request.url,
        options: Options(
          headers: {
            'Referer': 'https://saicord.com/',
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
          },
        ),
      );

      final document = html.parse(response.data as String);

      // Find player-iframe div and its scripts
      final iframeDiv = document.querySelector('div.player-iframe');
      if (iframeDiv == null) {
        Logger.warning('Saicord: player-iframe div not found');
        return const [];
      }

      final scripts = iframeDiv.querySelectorAll('script');
      if (scripts.length < 2) {
        Logger.warning('Saicord: Not enough scripts found');
        return const [];
      }

      final scriptContent = scripts[1].text;

      // Extract base64 encoded data from atob() call
      final atobMatch = RegExp(r'atob\("([^"]+)"\)').firstMatch(scriptContent);

      if (atobMatch == null || atobMatch.group(1) == null) {
        Logger.warning('Saicord: No encrypted data found');
        return const [];
      }

      final encoded = atobMatch.group(1) ?? '';

      // Decode base64
      String decoded;
      try {
        decoded = utf8.decode(base64.decode(encoded));
      } catch (e) {
        Logger.warning('Saicord: Base64 decode failed');
        return const [];
      }

      // Extract video URL from decoded data
      final fileMatch =
          RegExp(r'file:"([^"]+)"').firstMatch(decoded) ??
          RegExp(r"file:'([^']+)'").firstMatch(decoded);

      if (fileMatch == null || fileMatch.group(1) == null) {
        Logger.warning('Saicord: No video URL found in decoded data');
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
        'Saicord extractor failed',
        tag: 'SaicordExtractor',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }
}
