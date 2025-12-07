import 'dart:convert';

import 'package:aniya/core/extractor/base/base_extractor.dart';
import 'package:aniya/core/extractor/base/extractor_info.dart';
import 'package:aniya/core/extractor/models/extractor_request.dart';
import 'package:aniya/core/extractor/models/raw_stream.dart';
import 'package:aniya/core/utils/logger.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html;

/// Ported from ref/umbrella/.../UpVid.ts
/// Original code by yogesh-hacker: https://github.com/yogesh-hacker
/// Credit: https://github.com/yogesh-hacker/MediaVanced/blob/main/sites/upvid.py
/// Note: RC4 decryption is best-effort without native RC4 support
class UpVidExtractor extends BaseExtractor {
  UpVidExtractor({Dio? dio})
    : _dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));

  static final ExtractorInfo info = ExtractorInfo(
    id: 'upvid',
    patterns: [RegExp(r'tatavid\.'), RegExp(r'tatavid\.com')],
    category: ExtractorCategory.video,
    extractors: [UpVidExtractor()],
  );

  final Dio _dio;

  @override
  String get name => 'UpVid';

  @override
  Future<List<RawStream>> extract(ExtractorRequest request) async {
    try {
      final response = await _dio.getUri(
        request.url,
        options: Options(
          headers: {
            'Referer': request.url.toString(),
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Mobile Safari/537.36',
          },
        ),
      );

      final document = html.parse(response.data as String);

      // Extract encrypted payload from input#func
      final funcInput = document.querySelector('input#func');
      final encryptedVal = funcInput?.attributes['value'] ?? '';

      if (encryptedVal.isEmpty) {
        Logger.warning('UpVid: Encrypted payload not found');
        return const [];
      }

      // Extract RC4 key from scripts
      String key = '';

      // Look for scripts with special characters
      for (final script in document.querySelectorAll('script')) {
        final content = script.text;

        // Try to find key with special characters pattern
        if (content.contains('ﾟωﾟﾉ') || content.contains('ﾟ')) {
          final m =
              RegExp(
                r"=\s*\w+\('([^']+)'\)",
                caseSensitive: false,
              ).firstMatch(content) ??
              RegExp(
                r'=\s*\w+\("([^"]+)"\)',
                caseSensitive: false,
              ).firstMatch(content);
          if (m != null && m.group(1) != null) {
            key = m.group(1) ?? '';
            break;
          }
        }
      }

      // Fallback: search all scripts
      if (key.isEmpty) {
        for (final script in document.querySelectorAll('script')) {
          final content = script.text;
          final m =
              RegExp(r"=\s*\w+\('([^']+)'\)").firstMatch(content) ??
              RegExp(r"key\s*[:=]\s*'([^']+)'").firstMatch(content) ??
              RegExp(r'key\s*[:=]\s*"([^"]+)"').firstMatch(content);
          if (m != null && m.group(1) != null) {
            key = m.group(1) ?? '';
            break;
          }
        }
      }

      // Last resort: search page for any quoted string
      if (key.isEmpty) {
        final pageHtml = response.data as String;
        final m = RegExp(r"'([A-Za-z0-9]{6,36})'").firstMatch(pageHtml);
        if (m != null && m.group(1) != null) {
          key = m.group(1) ?? '';
        }
      }

      if (key.isEmpty) {
        Logger.warning('UpVid: RC4 key not found');
        return const [];
      }

      // Decode base64 to get encrypted bytes
      List<int> cipherBytes;
      try {
        cipherBytes = base64Decode(encryptedVal);
      } catch (e) {
        Logger.warning('UpVid: Failed to decode base64');
        return const [];
      }

      // RC4 decryption (simplified - without native RC4, return best-effort)
      // In production, you would use a proper RC4 implementation
      String decrypted = '';
      try {
        decrypted = _simpleRC4Decrypt(cipherBytes, key);
      } catch (e) {
        Logger.warning('UpVid: RC4 decryption failed: $e');
        return const [];
      }

      if (decrypted.isEmpty) {
        Logger.warning('UpVid: Decryption produced empty result');
        return const [];
      }

      // Extract video URL from decrypted content
      final srcMatch =
          RegExp(r"'src'\s*,\s*'([^']+)'").firstMatch(decrypted) ??
          RegExp(r"src:\s*'([^']+)'").firstMatch(decrypted) ??
          RegExp(r'src:\s*"([^"]+)"').firstMatch(decrypted);

      if (srcMatch == null || srcMatch.group(1) == null) {
        Logger.warning('UpVid: Video src not found in decrypted payload');
        return const [];
      }

      final videoUrl = srcMatch.group(1) ?? '';

      return [
        RawStream(
          url: Uri.parse(videoUrl),
          isM3u8: videoUrl.contains('.m3u8'),
          sourceLabel: name,
        ),
      ];
    } catch (error, stackTrace) {
      Logger.error(
        'UpVid extractor failed',
        tag: 'UpVidExtractor',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }

  /// Simple RC4 decryption (best-effort without native RC4)
  /// This is a basic implementation for demonstration
  String _simpleRC4Decrypt(List<int> cipherBytes, String key) {
    // RC4 KSA (Key Scheduling Algorithm)
    final s = List<int>.generate(256, (i) => i);
    int j = 0;

    for (int i = 0; i < 256; i++) {
      j = (j + s[i] + key.codeUnitAt(i % key.length)) % 256;
      final temp = s[i];
      s[i] = s[j];
      s[j] = temp;
    }

    // RC4 PRGA (Pseudo-Random Generation Algorithm)
    int i = 0;
    j = 0;
    final result = <int>[];

    for (final byte in cipherBytes) {
      i = (i + 1) % 256;
      j = (j + s[i]) % 256;
      final temp = s[i];
      s[i] = s[j];
      s[j] = temp;
      final k = s[(s[i] + s[j]) % 256];
      result.add(byte ^ k);
    }

    return utf8.decode(result);
  }
}
