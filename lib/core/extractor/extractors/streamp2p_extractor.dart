import 'dart:convert';

import 'package:aniya/core/extractor/base/base_extractor.dart';
import 'package:aniya/core/extractor/base/extractor_info.dart';
import 'package:aniya/core/extractor/models/extractor_request.dart';
import 'package:aniya/core/extractor/models/raw_stream.dart';
import 'package:aniya/core/utils/logger.dart';
import 'package:dio/dio.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

/// Ported from ref/umbrella/.../StreamP2P.ts
/// Original code by yogesh-hacker: https://github.com/yogesh-hacker
/// Credit: https://github.com/yogesh-hacker/MediaVanced/blob/main/sites/streamp2p.py
class StreamP2PExtractor extends BaseExtractor {
  StreamP2PExtractor({Dio? dio})
    : _dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));

  static final ExtractorInfo info = ExtractorInfo(
    id: 'streamp2p',
    patterns: [RegExp(r'streamp2p\.')],
    category: ExtractorCategory.video,
    extractors: [StreamP2PExtractor()],
  );

  final Dio _dio;

  @override
  String get name => 'StreamP2P';

  @override
  Future<List<RawStream>> extract(ExtractorRequest request) async {
    try {
      final domain = '${request.url.scheme}://${request.url.host}';

      // Extract video ID from URL fragment
      final videoId = request.url.fragment;
      if (videoId.isEmpty) {
        Logger.warning('StreamP2P: No video id found in URL');
        return const [];
      }

      // Make API request
      final apiUrl = '$domain/api/v1/video?id=${Uri.encodeComponent(videoId)}';

      final response = await _dio.get(
        apiUrl,
        options: Options(
          headers: {
            'Referer': '$domain/',
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Mobile Safari/537.36',
          },
          responseType: ResponseType.plain,
        ),
      );

      final encryptedHex = response.data as String?;
      if (encryptedHex == null || encryptedHex.isEmpty) {
        Logger.warning('StreamP2P: No encrypted data returned');
        return const [];
      }

      // Decrypt using AES-CBC
      const password = 'kiemtienmua911ca';
      const ivStr = '1234567890oiuytr';

      try {
        final key = encrypt.Key.fromUtf8(password);
        final iv = encrypt.IV.fromUtf8(ivStr);

        // Convert hex to bytes
        final cipherBytes = _hexToBytes(encryptedHex.trim());

        final encrypter = encrypt.Encrypter(
          encrypt.AES(key, mode: encrypt.AESMode.cbc),
        );

        final decrypted = encrypter.decrypt(
          encrypt.Encrypted.fromBase64(base64Encode(cipherBytes)),
          iv: iv,
        );

        if (decrypted.isEmpty) {
          Logger.warning('StreamP2P: Failed to decrypt response');
          return const [];
        }

        // Parse JSON
        final json = jsonDecode(decrypted) as Map<String, dynamic>;
        final videoUrl =
            json['source'] as String? ?? json['file'] as String? ?? '';

        if (videoUrl.isEmpty) {
          Logger.warning('StreamP2P: No video URL found in decrypted data');
          return const [];
        }

        return [
          RawStream(
            url: Uri.parse(videoUrl),
            isM3u8: videoUrl.contains('.m3u8'),
            sourceLabel: name,
          ),
        ];
      } catch (e) {
        Logger.warning('StreamP2P: Decryption failed: $e');
        return const [];
      }
    } catch (error, stackTrace) {
      Logger.error(
        'StreamP2P extractor failed',
        tag: 'StreamP2PExtractor',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }

  /// Convert hex string to bytes
  List<int> _hexToBytes(String hex) {
    final bytes = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }
}
