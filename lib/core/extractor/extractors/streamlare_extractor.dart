import 'package:aniya/core/extractor/base/base_extractor.dart';
import 'package:aniya/core/extractor/base/extractor_info.dart';
import 'package:aniya/core/extractor/models/extractor_request.dart';
import 'package:aniya/core/extractor/models/raw_stream.dart';
import 'package:aniya/core/extractor/utils/js_unpacker.dart';
import 'package:aniya/core/utils/logger.dart';
import 'package:dio/dio.dart';

/// Ported from ref/umbrella/.../StreamLare.ts
/// Original code by 2004durgesh: https://github.com/2004durgesh
/// Credit: https://github.com/2004durgesh/react-native-consumet/blob/main/src/extractors/streamlare.ts
class StreamLareExtractor extends BaseExtractor {
  StreamLareExtractor({Dio? dio})
    : _dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));

  static final ExtractorInfo info = ExtractorInfo(
    id: 'streamlare',
    patterns: [RegExp(r'streamlare\.')],
    category: ExtractorCategory.video,
    extractors: [StreamLareExtractor()],
  );

  final Dio _dio;

  @override
  String get name => 'StreamLare';

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
        Logger.warning('StreamLare: Could not find packed JavaScript code');
        return const [];
      }

      final packedCode = (evalMatch.group(2) ?? '')
          .replaceAll('eval', '')
          .replaceAll(RegExp(r'^\(|\)$'), '');

      final unpackedData = safeUnpack(packedCode);

      // Extract all sources from unpacked data
      final linksMatches = RegExp(
        r'sources:\[\{src:"(.*?)"',
      ).allMatches(unpackedData);

      if (linksMatches.isEmpty) {
        Logger.warning(
          'StreamLare: Could not extract video sources from unpacked data',
        );
        return const [];
      }

      final List<RawStream> streams = [];

      for (final linkMatch in linksMatches) {
        final linkUrl = linkMatch.group(1);
        if (linkUrl != null && linkUrl.isNotEmpty) {
          streams.add(
            RawStream(
              url: Uri.parse(linkUrl),
              isM3u8: linkUrl.contains('.m3u8'),
              sourceLabel: name,
            ),
          );
        }
      }

      return streams;
    } catch (error, stackTrace) {
      Logger.error(
        'StreamLare extractor failed',
        tag: 'StreamLareExtractor',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }
}
