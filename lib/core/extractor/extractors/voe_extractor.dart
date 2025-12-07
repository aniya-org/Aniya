import 'dart:convert';

import 'package:aniya/core/extractor/base/base_extractor.dart';
import 'package:aniya/core/extractor/base/extractor_info.dart';
import 'package:aniya/core/extractor/models/extractor_request.dart';
import 'package:aniya/core/extractor/models/raw_stream.dart';
import 'package:aniya/core/extractor/utils/subtitle_utils.dart';
import 'package:aniya/core/utils/logger.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html;

/// Ported from ref/umbrella/.../Voe.ts
/// Original code by 2004durgesh: https://github.com/2004durgesh
/// Credit: https://github.com/2004durgesh/react-native-consumet/blob/main/src/extractors/voe.ts
/// Updated/adapted from: https://github.com/yogesh-hacker/MediaVanced/blob/main/sites/voe.py
class VoeExtractor extends BaseExtractor {
  VoeExtractor({Dio? dio})
    : _dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));

  static final ExtractorInfo info = ExtractorInfo(
    id: 'voe',
    patterns: [
      RegExp(r'voe\.'),
      RegExp(r'voe\.sx'),
      RegExp(r'kellywhatcould\.com'),
      RegExp(r'jilliandescribecompany\.com'),
    ],
    category: ExtractorCategory.video,
    extractors: [VoeExtractor()],
  );

  final Dio _dio;

  @override
  String get name => 'Voe';

  @override
  Future<List<RawStream>> extract(ExtractorRequest request) async {
    try {
      final response = await _dio.getUri(request.url);
      final document = html.parse(response.data as String);

      // Extract redirect URL from script
      String pageUrl = '';
      final scripts = document.querySelectorAll('script');
      for (final script in scripts) {
        final scriptContent = script.text;
        final match = RegExp(
          r"window\.location\.href\s*=\s*'(https:\/\/[^']+)';",
        ).firstMatch(scriptContent);
        if (match != null) {
          pageUrl = match.group(1) ?? '';
          break;
        }
      }

      if (pageUrl.isEmpty) {
        Logger.warning('Voe: Could not find redirect URL');
        return const [];
      }

      // Fetch the actual video page
      final pageResponse = await _dio.get(pageUrl);
      final pageDocument = html.parse(pageResponse.data as String);
      final bodyHtml = pageDocument.body?.innerHtml ?? '';

      // Extract HLS URL (base64 encoded)
      final urlMatch = RegExp(
        r"'hls'\s*:\s*'([^']+)'",
        dotAll: true,
      ).firstMatch(bodyHtml);
      if (urlMatch == null || urlMatch.group(1) == null) {
        Logger.warning('Voe: Could not find HLS URL');
        return const [];
      }

      final encodedUrl = urlMatch.group(1) ?? '';
      final decodedUrl = utf8.decode(base64.decode(encodedUrl));

      // Extract subtitles
      final List<SubtitleTrack> subtitles = [];
      final subtitleRegex = RegExp(
        r'<track\s+kind="subtitles"\s+label="([^"]+)"\s+srclang="([^"]+)"\s+src="([^"]+)"',
      );

      for (final match in subtitleRegex.allMatches(bodyHtml)) {
        final label = match.group(1) ?? '';
        final src = match.group(3) ?? '';

        if (src.isNotEmpty) {
          final resolvedUrl = _resolveUrl(src, request.url.toString());
          subtitles.add(
            SubtitleTrack(
              url: Uri.parse(resolvedUrl),
              language: label,
              name: label,
              mimeType: detectSubtitleMimeType(resolvedUrl),
            ),
          );
        }
      }

      // Extract thumbnail preview
      String? thumbnailSrc;
      for (final script in pageDocument.querySelectorAll('script')) {
        final scriptContent = script.text;
        final thumbnailMatch = RegExp(
          r'previewThumbnails:\s*{[^}]*src:\s*\["([^"]+)"\]',
        ).firstMatch(scriptContent);

        if (thumbnailMatch != null && thumbnailMatch.group(1) != null) {
          thumbnailSrc = thumbnailMatch.group(1);
          break;
        }
      }

      if (thumbnailSrc != null && thumbnailSrc.isNotEmpty) {
        final origin = '${request.url.scheme}://${request.url.host}';
        subtitles.add(
          SubtitleTrack(
            url: Uri.parse('$origin$thumbnailSrc'),
            language: 'thumbnails',
            name: 'thumbnails',
            mimeType: detectSubtitleMimeType('$origin$thumbnailSrc'),
          ),
        );
      }

      return [
        RawStream(
          url: Uri.parse(decodedUrl),
          isM3u8: decodedUrl.contains('.m3u8'),
          sourceLabel: name,
          subtitles: subtitles,
        ),
      ];
    } catch (error, stackTrace) {
      Logger.error(
        'Voe extractor failed',
        tag: 'VoeExtractor',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }

  String _resolveUrl(String url, String baseUrl) {
    if (url.startsWith('http')) {
      return url;
    }
    final uri = Uri.parse(baseUrl);
    final origin = '${uri.scheme}://${uri.host}';
    return url.startsWith('/') ? '$origin$url' : '$origin/$url';
  }
}
