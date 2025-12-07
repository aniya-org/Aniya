import 'package:aniya/core/extractor/base/base_extractor.dart';
import 'package:aniya/core/extractor/base/extractor_info.dart';
import 'package:aniya/core/extractor/models/extractor_request.dart';
import 'package:aniya/core/extractor/models/raw_stream.dart';
import 'package:aniya/core/extractor/utils/js_unpacker.dart';
import 'package:aniya/core/utils/logger.dart';
import 'package:dio/dio.dart';

/// Ported from ref/umbrella/.../MixDrop.ts
/// Original code by 2004durgesh: https://github.com/2004durgesh
/// Credit: https://github.com/2004durgesh/react-native-consumet/blob/main/src/extractors/mixdrop.ts
/// Updated/adapted from: https://github.com/yogesh-hacker/MediaVanced/blob/main/sites/mixdrop.py
class MixDropExtractor extends BaseExtractor {
  MixDropExtractor({Dio? dio})
    : _dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));

  static final ExtractorInfo info = ExtractorInfo(
    id: 'mixdrop',
    patterns: [
      RegExp(r'mixdrop\.'),
      RegExp(r'mixdrop\.sb'),
      RegExp(r'mixdrop\.to'),
    ],
    category: ExtractorCategory.video,
    extractors: [MixDropExtractor()],
  );

  final Dio _dio;

  @override
  String get name => 'MixDrop';

  @override
  Future<List<RawStream>> extract(ExtractorRequest request) async {
    try {
      final response = await _dio.getUri(request.url);
      final responseData = response.data as String;

      // Extract packed JavaScript safely without eval()
      final evalMatch = RegExp(
        r'(eval)(\(f.*?)(\n<\/script>)',
        dotAll: true,
      ).firstMatch(responseData);

      if (evalMatch == null || evalMatch.group(2) == null) {
        Logger.warning('MixDrop: Could not find packed JavaScript code');
        return const [];
      }

      final packedCode = (evalMatch.group(2) ?? '')
          .replaceAll('eval', '')
          .replaceAll(RegExp(r'^\(|\)$'), '');

      final formatted = safeUnpack(packedCode);

      final matches = RegExp(
        r'poster="([^"]+)"|wurl="([^"]+)"',
      ).allMatches(formatted).toList();

      if (matches.length < 2) {
        Logger.warning(
          'MixDrop: Could not extract video source from unpacked data',
        );
        return const [];
      }

      // Extract source URL
      String? source;

      for (final match in matches) {
        final value = match.group(0) ?? '';
        if (value.contains('wurl=')) {
          source = value.split('="')[1].replaceAll('"', '');
        }
      }

      if (source == null || source.isEmpty) {
        Logger.warning('MixDrop: Could not extract source URL');
        return const [];
      }

      // Ensure URL is absolute
      if (!source.startsWith('http')) {
        source = 'https:$source';
      }

      return [
        RawStream(
          url: Uri.parse(source),
          isM3u8: source.contains('.m3u8'),
          sourceLabel: name,
        ),
      ];
    } catch (error, stackTrace) {
      Logger.error(
        'MixDrop extractor failed',
        tag: 'MixDropExtractor',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }
}
