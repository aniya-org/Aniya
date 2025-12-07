import 'dart:convert';

import 'package:aniya/core/extractor/base/base_extractor.dart';
import 'package:aniya/core/extractor/base/extractor_info.dart';
import 'package:aniya/core/extractor/models/extractor_request.dart';
import 'package:aniya/core/extractor/models/raw_stream.dart';
import 'package:aniya/core/utils/logger.dart';
import 'package:dio/dio.dart';

/// Ported from ref/umbrella/.../MegaUp.ts
/// Original code by 2004durgesh: https://github.com/2004durgesh
/// Credit: https://github.com/2004durgesh/react-native-consumet/blob/main/src/extractors/megaup.ts
/// Extractor for https://animekai.to
/// Keys required for decryption are loaded dynamically from
/// https://raw.githubusercontent.com/amarullz/kaicodex/main/generated/keys.json
class MegaUpExtractor extends BaseExtractor {
  MegaUpExtractor({Dio? dio})
    : _dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));

  static final ExtractorInfo info = ExtractorInfo(
    id: 'megaup',
    patterns: [RegExp(r'megaup\.'), RegExp(r'animekai\.')],
    category: ExtractorCategory.video,
    extractors: [MegaUpExtractor()],
  );

  final Dio _dio;
  late List<String> _homeKeys = [];
  late List<String> _megaKeys = [];
  Future<void>? _kaiKeysReady;

  static const String _keysUrl =
      'https://raw.githubusercontent.com/amarullz/kaicodex/main/generated/keys.json';

  @override
  String get name => 'MegaUp';

  Future<void> _loadKAIKEYS() async {
    try {
      final response = await _dio.get(_keysUrl);
      final keys = response.data as Map<String, dynamic>;

      _homeKeys = [];
      _megaKeys = [];

      final kaiList = keys['kai'] as List<dynamic>? ?? [];
      for (final key in kaiList) {
        _homeKeys.add(utf8.decode(base64.decode(key as String)));
      }

      final megaList = keys['mega'] as List<dynamic>? ?? [];
      for (final key in megaList) {
        _megaKeys.add(utf8.decode(base64.decode(key as String)));
      }
    } catch (error) {
      Logger.error(
        'MegaUp: Failed to load keys',
        tag: 'MegaUpExtractor',
        error: error,
      );
      rethrow;
    }
  }

  String _decodeIframeData(String n) {
    final decoded = utf8.decode(
      base64.decode(n.replaceAll('_', '/').replaceAll('-', '+')),
    );
    final l = decoded.length;
    final List<int> o = [];

    for (int i = 0; i < l; i++) {
      final c = decoded.codeUnitAt(i);
      if (c < _megaKeys.length) {
        final k = _megaKeys[c];
        o.add(k.codeUnitAt(i % k.length));
      }
    }

    return Uri.decodeComponent(String.fromCharCodes(o));
  }

  @override
  Future<List<RawStream>> extract(ExtractorRequest request) async {
    try {
      // Lazy load keys only when extractor is actually used
      _kaiKeysReady ??= _loadKAIKEYS();
      await _kaiKeysReady;

      final url = request.url.toString().replaceAll(
        RegExp(r'/(e|e2)/'),
        '/media/',
      );
      final response = await _dio.get(url);

      final decrypted =
          jsonDecode(
                _decodeIframeData(
                  response.data['result'] as String,
                ).replaceAll('\\', ''),
              )
              as Map<String, dynamic>;

      final sources = decrypted['sources'] as List<dynamic>? ?? [];
      final List<RawStream> result = [];

      for (final source in sources) {
        final sourceMap = source as Map<String, dynamic>;
        final file = sourceMap['file'] as String? ?? '';

        if (file.isNotEmpty) {
          result.add(
            RawStream(
              url: Uri.parse(file),
              isM3u8: file.contains('.m3u8') || file.endsWith('m3u8'),
              sourceLabel: name,
            ),
          );
        }
      }

      return result;
    } catch (error, stackTrace) {
      Logger.error(
        'MegaUp extractor failed',
        tag: 'MegaUpExtractor',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }
}
