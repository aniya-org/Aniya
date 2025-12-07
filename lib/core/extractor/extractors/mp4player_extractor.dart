import 'package:aniya/core/extractor/base/base_extractor.dart';
import 'package:aniya/core/extractor/base/extractor_info.dart';
import 'package:aniya/core/extractor/models/extractor_request.dart';
import 'package:aniya/core/extractor/models/raw_stream.dart';
import 'package:aniya/core/utils/logger.dart';
import 'package:dio/dio.dart';

/// Ported from ref/umbrella/.../Mp4Player.ts
/// Original code by 2004durgesh: https://github.com/2004durgesh
/// Credit: https://github.com/2004durgesh/react-native-consumet/blob/main/src/extractors/mp4player.ts
class Mp4PlayerExtractor extends BaseExtractor {
  Mp4PlayerExtractor({Dio? dio})
    : _dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));

  static final ExtractorInfo info = ExtractorInfo(
    id: 'mp4player',
    patterns: [RegExp(r'mp4player\.site')],
    category: ExtractorCategory.video,
    extractors: [Mp4PlayerExtractor()],
  );

  final Dio _dio;

  @override
  String get name => 'Mp4Player';

  @override
  Future<List<RawStream>> extract(ExtractorRequest request) async {
    try {
      final response = await _dio.getUri(request.url);
      final responseData = response.data as String;

      // Extract sniff() call data
      final sniffMatch = RegExp(
        r'(?<=sniff\()(.*)(?=\))',
        dotAll: true,
      ).firstMatch(responseData);

      if (sniffMatch == null || sniffMatch.group(1) == null) {
        Logger.warning('Mp4Player: Could not find sniff data');
        return const [];
      }

      final matchData = (sniffMatch.group(1) ?? '')
          .replaceAll('"', '')
          .split(',');

      if (matchData.length < 8) {
        Logger.warning('Mp4Player: Invalid sniff data format');
        return const [];
      }

      // Build M3U8 master URL
      final m3u8Link =
          'https://${request.url.host}/m3u8/${matchData[1]}/${matchData[2]}/master.txt?s=1&cache=${matchData[7]}';

      // Fetch M3U8 content
      final m3u8Response = await _dio.get(
        m3u8Link,
        options: Options(
          headers: {'accept': '*/*', 'referer': request.url.toString()},
        ),
      );

      final m3u8Content = m3u8Response.data as String;
      final List<RawStream> streams = [];

      if (m3u8Content.contains('EXTM3U')) {
        final videoList = m3u8Content.split('#EXT-X-STREAM-INF:');

        for (final video in videoList) {
          if (!video.contains('BANDWIDTH')) continue;

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

      return streams.isEmpty
          ? [
              RawStream(
                url: Uri.parse(m3u8Link),
                isM3u8: true,
                sourceLabel: name,
              ),
            ]
          : streams;
    } catch (error, stackTrace) {
      Logger.error(
        'Mp4Player extractor failed',
        tag: 'Mp4PlayerExtractor',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }
}
