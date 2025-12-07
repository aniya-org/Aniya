import 'package:aniya/core/extractor/base/base_extractor.dart';
import 'package:aniya/core/extractor/base/extractor_info.dart';
import 'package:aniya/core/extractor/models/extractor_request.dart';
import 'package:aniya/core/extractor/models/raw_stream.dart';
import 'package:aniya/core/extractor/utils/js_unpacker.dart';
import 'package:aniya/core/utils/logger.dart';
import 'package:dio/dio.dart';

/// Ported from ref/umbrella/.../StreamHub.ts
/// Original code by 2004durgesh: https://github.com/2004durgesh
/// Credit: https://github.com/2004durgesh/react-native-consumet/blob/main/src/extractors/streamhub.ts
class StreamHubExtractor extends BaseExtractor {
  StreamHubExtractor({Dio? dio})
    : _dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));

  static final ExtractorInfo info = ExtractorInfo(
    id: 'streamhub',
    patterns: [RegExp(r'streamhub\.')],
    category: ExtractorCategory.video,
    extractors: [StreamHubExtractor()],
  );

  final Dio _dio;

  @override
  String get name => 'StreamHub';

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
        Logger.warning('StreamHub: Could not find packed JavaScript code');
        return const [];
      }

      final packedCode = (evalMatch.group(2) ?? '')
          .replaceAll('eval', '')
          .replaceAll(RegExp(r'^\(|\)$'), '');

      final unpackedData = safeUnpack(packedCode);

      final linksMatch = RegExp(
        r'sources:\[\{src:"(.*?)"',
      ).firstMatch(unpackedData);

      if (linksMatch == null || linksMatch.group(1) == null) {
        Logger.warning(
          'StreamHub: Could not extract video source from unpacked data',
        );
        return const [];
      }

      final m3u8Link = linksMatch.group(1) ?? '';

      // Fetch M3U8 content
      final m3u8Response = await _dio.get(
        m3u8Link,
        options: Options(headers: {'Referer': m3u8Link}),
      );

      final m3u8Content = m3u8Response.data as String;
      final List<RawStream> streams = [];

      // Add main source
      streams.add(
        RawStream(
          url: Uri.parse(m3u8Link),
          isM3u8: m3u8Link.contains('.m3u8'),
          sourceLabel: name,
        ),
      );

      // Parse M3U8 for quality variants
      if (m3u8Content.contains('EXTM3U')) {
        final videoList = m3u8Content.split('#EXT-X-STREAM-INF:');

        for (final video in videoList) {
          if (!video.contains('m3u8')) continue;

          final urlMatch = RegExp(r'\n([^\n]+\.m3u8[^\n]*)').firstMatch(video);
          if (urlMatch == null) continue;

          final url = urlMatch.group(1) ?? '';
          final qualityMatch = RegExp(
            r'RESOLUTION=\d+x(\d+)',
          ).firstMatch(video);
          final quality = qualityMatch?.group(1) ?? 'Auto';

          streams.add(
            RawStream(
              url: Uri.parse(url),
              isM3u8: true,
              quality: '${quality}p',
              sourceLabel: name,
            ),
          );
        }
      }

      return streams;
    } catch (error, stackTrace) {
      Logger.error(
        'StreamHub extractor failed',
        tag: 'StreamHubExtractor',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }
}
