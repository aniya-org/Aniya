import 'dart:convert';

import 'package:aniya/core/extractor/base/base_extractor.dart';
import 'package:aniya/core/extractor/base/extractor_info.dart';
import 'package:aniya/core/extractor/models/extractor_request.dart';
import 'package:aniya/core/extractor/models/raw_stream.dart';
import 'package:aniya/core/extractor/utils/subtitle_utils.dart';
import 'package:aniya/core/utils/logger.dart';
import 'package:dio/dio.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:html/parser.dart' as html;

/// Ported from ref/umbrella/.../AsianLoad.ts
/// Original code by 2004durgesh: https://github.com/2004durgesh
/// Credit: https://github.com/2004durgesh/react-native-consumet/blob/main/src/extractors/asianload.ts
class AsianLoadExtractor extends BaseExtractor {
  AsianLoadExtractor({Dio? dio})
    : _dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));

  static final ExtractorInfo info = ExtractorInfo(
    id: 'asianload',
    patterns: [RegExp(r'asianload.*?\.')],
    category: ExtractorCategory.video,
    extractors: [AsianLoadExtractor()],
  );

  final Dio _dio;

  // Fixed AES-256-CBC key and IV
  static final encrypt.Key _key = encrypt.Key.fromUtf8(
    '93422192433952489752342908585752',
  );
  static final encrypt.IV _iv = encrypt.IV.fromUtf8('9262859232435825');

  @override
  String get name => 'AsianLoad';

  @override
  Future<List<RawStream>> extract(ExtractorRequest request) async {
    try {
      final response = await _dio.getUri(request.url);
      final document = html.parse(response.data as String);

      // Extract video ID from URL
      final videoId = _extractVideoId(request.url.toString());
      if (videoId.isEmpty) {
        Logger.warning('AsianLoad: Could not extract video ID');
        return const [];
      }

      // Generate encrypted AJAX params
      final encryptedParams = await _generateEncryptedAjaxParams(
        document,
        videoId,
      );

      // Make AJAX request
      final ajaxUrl =
          '${request.url.scheme}://${request.url.host}/encrypt-ajax.php?$encryptedParams';
      final ajaxResponse = await _dio.get(
        ajaxUrl,
        options: Options(headers: {'X-Requested-With': 'XMLHttpRequest'}),
      );

      // Decrypt response data
      final decryptedData = await _decryptAjaxData(
        ajaxResponse.data['data'] as String,
      );

      if (decryptedData == null || decryptedData['source'] == null) {
        Logger.warning('AsianLoad: No source found');
        return const [];
      }

      final List<RawStream> streams = [];

      // Process main sources
      final sources = decryptedData['source'] as List<dynamic>? ?? [];
      for (final source in sources) {
        final sourceMap = source as Map<String, dynamic>;
        final file = sourceMap['file'] as String? ?? '';
        if (file.isNotEmpty) {
          streams.add(
            RawStream(
              url: Uri.parse(file),
              isM3u8: file.contains('.m3u8'),
              sourceLabel: name,
            ),
          );
        }
      }

      // Process backup sources
      final backupSources = decryptedData['source_bk'] as List<dynamic>? ?? [];
      for (final source in backupSources) {
        final sourceMap = source as Map<String, dynamic>;
        final file = sourceMap['file'] as String? ?? '';
        if (file.isNotEmpty) {
          streams.add(
            RawStream(
              url: Uri.parse(file),
              isM3u8: file.contains('.m3u8'),
              sourceLabel: '$name (Backup)',
            ),
          );
        }
      }

      // Process subtitles
      final tracks = decryptedData['track'] as Map<String, dynamic>? ?? {};
      final tracksList = tracks['tracks'] as List<dynamic>? ?? [];
      final subtitles = tracksList
          .map((track) {
            final trackMap = track as Map<String, dynamic>;
            final file = trackMap['file'] as String? ?? '';
            final kind = trackMap['kind'] as String? ?? '';
            if (file.isEmpty) return null;

            return SubtitleTrack(
              url: Uri.parse(file),
              language: kind == 'thumbnails' ? 'Default (maybe)' : kind,
              name: kind == 'thumbnails' ? 'Default (maybe)' : kind,
              mimeType: detectSubtitleMimeType(file),
            );
          })
          .whereType<SubtitleTrack>()
          .toList();

      // Add subtitles to streams
      if (subtitles.isNotEmpty) {
        for (int i = 0; i < streams.length; i++) {
          streams[i] = streams[i].copyWith(subtitles: subtitles);
        }
      }

      return streams;
    } catch (error, stackTrace) {
      Logger.error(
        'AsianLoad extractor failed',
        tag: 'AsianLoadExtractor',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }

  String _extractVideoId(String url) {
    final match = RegExp(r'[?&]id=([^&]+)').firstMatch(url);
    return match?.group(1) ?? '';
  }

  Future<String> _generateEncryptedAjaxParams(
    dynamic document,
    String videoId,
  ) async {
    // Encrypt the video ID
    final encrypter = encrypt.Encrypter(encrypt.AES(_key));
    final encryptedId = encrypter.encrypt(videoId, iv: _iv).base64;

    // Extract crypto script data
    final scriptElements = document.querySelectorAll(
      'script[data-name="crypto"]',
    );
    if (scriptElements.isEmpty) {
      throw Exception('Crypto script not found');
    }

    final scriptValue = scriptElements.first.attributes['data-value'] ?? '';
    if (scriptValue.isEmpty) {
      throw Exception('Crypto data not found');
    }

    // Decrypt the token
    final decrypter = encrypt.Encrypter(encrypt.AES(_key));
    final decryptedToken = decrypter.decrypt64(scriptValue, iv: _iv);

    return 'id=$encryptedId&alias=$decryptedToken';
  }

  Future<Map<String, dynamic>?> _decryptAjaxData(String encryptedData) async {
    try {
      final decrypter = encrypt.Encrypter(encrypt.AES(_key));
      final decrypted = decrypter.decrypt64(encryptedData, iv: _iv);
      return jsonDecode(decrypted) as Map<String, dynamic>;
    } catch (error) {
      Logger.error(
        'Failed to decrypt AJAX data',
        tag: 'AsianLoadExtractor',
        error: error,
      );
      return null;
    }
  }
}
