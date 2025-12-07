import 'package:aniya/core/extractor/base/base_extractor.dart';
import 'package:aniya/core/extractor/base/extractor_info.dart';
import 'package:aniya/core/extractor/models/extractor_request.dart';
import 'package:aniya/core/extractor/models/raw_stream.dart';
import 'package:aniya/core/extractor/utils/js_unpacker.dart';
import 'package:aniya/core/utils/logger.dart';
import 'package:dio/dio.dart';

/// Ported from ref/umbrella/.../Kwik.ts
/// Original code by 2004durgesh: https://github.com/2004durgesh
/// Credit: https://github.com/2004durgesh/react-native-consumet/blob/main/src/extractors/kwik.ts
class KwikExtractor extends BaseExtractor {
  KwikExtractor({Dio? dio})
    : _dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));

  static final ExtractorInfo info = ExtractorInfo(
    id: 'kwik',
    patterns: [RegExp(r'kwik\.')],
    category: ExtractorCategory.video,
    extractors: [KwikExtractor()],
  );

  final Dio _dio;
  static const String _host = 'https://animepahe.ru/';

  @override
  String get name => 'Kwik';

  @override
  Future<List<RawStream>> extract(ExtractorRequest request) async {
    try {
      final response = await _dio.getUri(
        request.url,
        options: Options(headers: {'Referer': _host}),
      );

      final responseData = response.data as String;

      // Extract packed JavaScript safely without eval()
      final evalMatch = RegExp(
        r'(eval)(\(f.*?)(\n<\/script>)',
        dotAll: true,
      ).firstMatch(responseData);

      if (evalMatch == null || evalMatch.group(2) == null) {
        Logger.warning('Kwik: Could not find packed JavaScript code');
        return const [];
      }

      final packedCode = (evalMatch.group(2) ?? '')
          .replaceAll('eval', '')
          .replaceAll(RegExp(r'^\(|\)$'), '');

      final unpackedData = safeUnpack(packedCode);

      final sourceMatch = RegExp(r'https.*?m3u8').firstMatch(unpackedData);
      if (sourceMatch == null) {
        Logger.warning(
          'Kwik: Could not extract video source from unpacked data',
        );
        return const [];
      }

      final source = sourceMatch.group(0) ?? '';

      return [
        RawStream(
          url: Uri.parse(source),
          isM3u8: source.contains('.m3u8'),
          sourceLabel: name,
        ),
      ];
    } catch (error, stackTrace) {
      Logger.error(
        'Kwik extractor failed',
        tag: 'KwikExtractor',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }
}
