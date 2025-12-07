import 'dart:convert';

import 'package:aniya/core/extractor/base/base_extractor.dart';
import 'package:aniya/core/extractor/base/extractor_info.dart';
import 'package:aniya/core/extractor/models/extractor_request.dart';
import 'package:aniya/core/extractor/models/raw_stream.dart';
import 'package:aniya/core/utils/logger.dart';
import 'package:dio/dio.dart';

/// Ported from ref/umbrella/.../MultiQuality.ts
/// Original code by yogesh-hacker: https://github.com/yogesh-hacker
/// Credit: https://github.com/yogesh-hacker/MediaVanced/blob/main/sites/multiquality.py
class MultiQualityExtractor extends BaseExtractor {
  MultiQualityExtractor({Dio? dio})
    : _dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));

  static final ExtractorInfo info = ExtractorInfo(
    id: 'multiquality',
    patterns: [RegExp(r'multiquality\.')],
    category: ExtractorCategory.video,
    extractors: [MultiQualityExtractor()],
  );

  final Dio _dio;

  @override
  String get name => 'MultiQuality';

  @override
  Future<List<RawStream>> extract(ExtractorRequest request) async {
    try {
      final response = await _dio.getUri(
        request.url,
        options: Options(
          headers: {
            'Referer': 'https://swift.multiquality.click',
            'Connection': 'keep-alive',
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36',
          },
        ),
      );

      final body = response.data as String;

      // Extract juicycodes(...) argument
      final match = RegExp(
        r'_juicycodes\(\s*([^\)]+)',
        caseSensitive: false,
      ).firstMatch(body);

      String codeRaw = '';
      if (match != null && match.group(1) != null) {
        codeRaw = (match.group(1) ?? '').trim();
        // Remove surrounding quotes
        if ((codeRaw.startsWith("'") && codeRaw.endsWith("'")) ||
            (codeRaw.startsWith('"') && codeRaw.endsWith('"'))) {
          codeRaw = codeRaw.substring(1, codeRaw.length - 1);
        }
      } else {
        // Fallback: find encoded payload
        final altRegex = RegExp(r'''(["'])([A-Za-z0-9_\-]{40,}={0,3})\1''');
        final alt = altRegex.firstMatch(body);
        codeRaw = alt?.group(2) ?? '';
      }

      if (codeRaw.isEmpty) {
        Logger.warning('MultiQuality: Packed code not found');
        return const [];
      }

      // Last 3 chars are salt, rest is encoded
      final encodedJs = codeRaw.substring(0, codeRaw.length - 3);

      // Add base64 padding
      String padded = encodedJs;
      final paddingLen = (padded.length + 3) % 4;
      if (paddingLen != 0) {
        padded += '=' * (4 - paddingLen);
      }

      // Replace URL-safe base64 characters
      padded = padded.replaceAll('_', '+').replaceAll('-', '/');

      // Base64 decode
      String b64Decoded;
      try {
        b64Decoded = utf8.decode(base64.decode(padded));
      } catch (e) {
        Logger.warning('MultiQuality: Base64 decode failed');
        return const [];
      }

      // Apply ROT13
      final rotDecoded = _rot13(b64Decoded);

      // Sanitize escaped slashes
      final decrypted = rotDecoded.replaceAll('\\/', '/');

      // Extract M3U8 URL
      final fileMatch = RegExp(
        r'"file":"(https?:\/\/[^"]+\.m3u8)"',
      ).firstMatch(decrypted);

      if (fileMatch == null || fileMatch.group(1) == null) {
        Logger.warning('MultiQuality: Video URL not found after decoding');
        return const [];
      }

      final videoUrl = fileMatch.group(1) ?? '';

      return [
        RawStream(url: Uri.parse(videoUrl), isM3u8: true, sourceLabel: name),
      ];
    } catch (error, stackTrace) {
      Logger.error(
        'MultiQuality extractor failed',
        tag: 'MultiQualityExtractor',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }

  /// ROT13 cipher implementation
  String _rot13(String input) {
    final buffer = StringBuffer();
    for (final char in input.codeUnits) {
      if (char >= 65 && char <= 90) {
        // A-Z
        buffer.writeCharCode(((char - 65 + 13) % 26) + 65);
      } else if (char >= 97 && char <= 122) {
        // a-z
        buffer.writeCharCode(((char - 97 + 13) % 26) + 97);
      } else {
        buffer.writeCharCode(char);
      }
    }
    return buffer.toString();
  }
}
