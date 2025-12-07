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

/// Ported from ref/umbrella/.../GogoCdn.ts and
/// https://raw.githubusercontent.com/2004durgesh/react-native-consumet/main/src/extractors/gogocdn.ts.
/// AES helper logic informed by https://stackoverflow.com/questions/64933327/flutter-dart-aes-256-cbc-decrypting-from-encryption-in-php.
class GogoCdnExtractor extends BaseExtractor {
  GogoCdnExtractor({Dio? dio})
    : _dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));

  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36';

  static final ExtractorInfo info = ExtractorInfo(
    id: 'gogocdn',
    patterns: [
      RegExp(r'goload\.'),
      RegExp(r'gogohd\.'),
      RegExp(r'gogocdn\.'),
      RegExp(r'gogoanime\.'),
    ],
    category: ExtractorCategory.video,
    extractors: [GogoCdnExtractor()],
  );

  final Dio _dio;
  final encrypt.Key _key = encrypt.Key.fromUtf8(
    '37911490979715163134003223491201',
  );
  final encrypt.Key _secondKey = encrypt.Key.fromUtf8(
    '54674138327930866480207815084989',
  );
  final encrypt.IV _iv = encrypt.IV.fromUtf8('3134003223491201');

  @override
  String get name => 'GogoCDN';

  @override
  Future<List<RawStream>> extract(ExtractorRequest request) async {
    try {
      final videoUrl = request.url;
      final videoId = videoUrl.queryParameters['id'];
      if (videoId == null) {
        Logger.warning(
          'GogoCDN: missing id parameter in ${videoUrl.toString()}',
        );
        return const [];
      }

      final htmlResponse = await _dio.getUri(
        videoUrl,
        options: Options(headers: _headers(referer: request.referer)),
      );
      final document = html.parse(htmlResponse.data as String);
      final tokenScript = document
          .querySelector("script[data-name='episode']")
          ?.attributes['data-value'];
      if (tokenScript == null) {
        Logger.warning(
          'GogoCDN: episode token not found for ${videoUrl.toString()}',
        );
        return const [];
      }

      final encryptedParams = await _generateEncryptedParams(
        tokenScript,
        videoId,
      );
      final ajaxUri = Uri(
        scheme: videoUrl.scheme,
        host: videoUrl.host,
        path: '/encrypt-ajax.php',
        query: encryptedParams,
      );

      final encryptedData = await _dio.getUri(
        ajaxUri,
        options: Options(
          headers: {
            'X-Requested-With': 'XMLHttpRequest',
            ..._headers(referer: videoUrl.toString()),
          },
        ),
      );
      final payload = encryptedData.data;
      final encryptedPayload = payload is Map
          ? payload['data'] as String?
          : null;
      if (encryptedPayload == null) {
        Logger.warning(
          'GogoCDN: unexpected ajax payload for ${videoUrl.toString()}',
        );
        return const [];
      }

      final decrypted = await _decryptAjaxData(encryptedPayload);
      final sources = List<Map<String, dynamic>>.from(
        decrypted['source'] ?? const [],
      );
      final backupSources = List<Map<String, dynamic>>.from(
        decrypted['source_bk'] ?? const [],
      );
      if (sources.isEmpty && backupSources.isEmpty) {
        Logger.warning(
          'GogoCDN: no sources returned for ${videoUrl.toString()}',
        );
        return const [];
      }

      final tracks = List<Map<String, dynamic>>.from(
        decrypted['track']?['tracks'] ?? const [],
      );
      final subtitles = tracks
          .map(
            (track) => SubtitleTrack(
              url: Uri.parse(track['file'] as String),
              name: track['kind'] as String?,
              language: track['kind'] as String?,
              mimeType: detectSubtitleMimeType(track['file'] as String),
            ),
          )
          .toList();

      final results = <RawStream>[];
      for (final source in sources) {
        results.addAll(
          await _buildStreamsFromSource(source, referer: videoUrl.toString()),
        );
      }
      for (final source in backupSources) {
        results.addAll(
          await _buildStreamsFromSource(
            source,
            referer: videoUrl.toString(),
            qualityFallback: 'backup',
          ),
        );
      }

      if (results.isNotEmpty && subtitles.isNotEmpty) {
        results[0] = results[0].copyWith(subtitles: subtitles);
      }

      return results;
    } catch (error, stackTrace) {
      Logger.error(
        'GogoCDN extractor failed',
        tag: 'GogoCdnExtractor',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }

  Future<List<RawStream>> _buildStreamsFromSource(
    Map<String, dynamic> source, {
    required String referer,
    String? qualityFallback,
  }) async {
    final url = source['file'] as String?;
    if (url == null) {
      return const [];
    }

    final headerMap = {'Referer': referer, 'User-Agent': _userAgent};

    if (url.contains('.m3u8')) {
      final variants = await _expandM3u8Variants(url, headerMap);
      if (variants.isNotEmpty) {
        return variants;
      }
    }

    final quality = (source['label'] as String?)?.split(' ').first;
    return [
      _rawStream(
        url,
        headers: headerMap,
        quality: quality ?? qualityFallback ?? 'auto',
      ),
    ];
  }

  RawStream _rawStream(
    String url, {
    Map<String, String>? headers,
    String? quality,
  }) {
    final uri = Uri.parse(url);
    return RawStream(
      url: uri,
      isM3u8: url.contains('.m3u8'),
      quality: quality,
      sourceLabel: name,
      headers: headers,
    );
  }

  Future<List<RawStream>> _expandM3u8Variants(
    String playlistUrl,
    Map<String, String> headers,
  ) async {
    try {
      final response = await _dio.get(
        playlistUrl,
        options: Options(headers: headers),
      );
      final playlist = response.data as String;
      final regex = RegExp(
        r'#EXT-X-STREAM-INF:[^\n]*RESOLUTION=\d+x(\d+)[^\n]*\n([^\n]+)',
      );
      final matches = regex.allMatches(playlist);
      final baseUri = Uri.parse(playlistUrl);
      final baseSegments = List<String>.from(baseUri.pathSegments);
      if (baseSegments.isNotEmpty) {
        baseSegments.removeLast();
      }
      final basePath = baseUri.replace(pathSegments: baseSegments);

      final variants = <RawStream>[];
      for (final match in matches) {
        final quality = match.group(1);
        final relative = match.group(2);
        if (relative == null) continue;
        final variantUri = Uri.parse(relative).isAbsolute
            ? Uri.parse(relative)
            : basePath.resolve(relative);
        variants.add(
          _rawStream(
            variantUri.toString(),
            headers: headers,
            quality: quality != null ? '${quality}p' : 'auto',
          ),
        );
      }

      // Fallback to original playlist if no variants parsed.
      if (variants.isEmpty) {
        variants.add(
          _rawStream(playlistUrl, headers: headers, quality: 'auto'),
        );
      }
      return variants;
    } catch (error) {
      Logger.warning('GogoCDN: failed to expand m3u8 variants - $error');
      return [];
    }
  }

  Future<String> _generateEncryptedParams(String tokenScript, String id) async {
    final keyCipher = encrypt.Encrypter(
      encrypt.AES(_key, mode: encrypt.AESMode.cbc, padding: 'PKCS7'),
    );
    final encryptedId = keyCipher.encrypt(id, iv: _iv).base64;
    final decryptedToken = keyCipher.decrypt64(tokenScript, iv: _iv);

    return 'id=${Uri.encodeQueryComponent(encryptedId)}&alias=$id&$decryptedToken';
  }

  Future<Map<String, dynamic>> _decryptAjaxData(String encryptedData) async {
    final encrypter = encrypt.Encrypter(
      encrypt.AES(_secondKey, mode: encrypt.AESMode.cbc, padding: 'PKCS7'),
    );
    final decrypted = encrypter.decrypt64(encryptedData, iv: _iv);
    return jsonDecode(decrypted) as Map<String, dynamic>;
  }

  Map<String, String> _headers({String? referer}) => {
    if (referer != null) 'Referer': referer,
    'User-Agent': _userAgent,
  };
}
