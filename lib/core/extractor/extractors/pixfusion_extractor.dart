import 'package:aniya/core/extractor/base/base_extractor.dart';
import 'package:aniya/core/extractor/base/extractor_info.dart';
import 'package:aniya/core/extractor/models/extractor_request.dart';
import 'package:aniya/core/extractor/models/raw_stream.dart';
import 'package:aniya/core/extractor/utils/js_unpacker.dart';
import 'package:aniya/core/utils/logger.dart';
import 'package:dio/dio.dart';

/// Ported from ref/umbrella/.../PixFusion.ts
/// Original code by yogesh-hacker: https://github.com/yogesh-hacker
/// Credit: https://github.com/yogesh-hacker/MediaVanced/blob/main/sites/pixfusion.py
class PixFusionExtractor extends BaseExtractor {
  PixFusionExtractor({Dio? dio})
    : _dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));

  static final ExtractorInfo info = ExtractorInfo(
    id: 'pixfusion',
    patterns: [RegExp(r'pixfusion\.')],
    category: ExtractorCategory.video,
    extractors: [PixFusionExtractor()],
  );

  final Dio _dio;

  @override
  String get name => 'PixFusion';

  @override
  Future<List<RawStream>> extract(ExtractorRequest request) async {
    try {
      final response = await _dio.getUri(
        request.url,
        options: Options(
          headers: {
            'Referer': request.url.toString(),
            'X-Requested-With': 'XMLHttpRequest',
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
          },
        ),
      );

      final body = response.data as String;
      final pattern = RegExp(
        r'eval\(function\((.*?)\)\{.*\}\((.*?)\)\)',
        dotAll: true,
      );
      final m = pattern.firstMatch(body);

      if (m == null) {
        Logger.warning('PixFusion: Packed data not found');
        return const [];
      }

      var dataString = (m.group(2) ?? '')
          .replaceAll(".split('|')", '')
          .replaceAll(RegExp(r'\\n'), '');

      // Unpack the code
      final unpacked = safeUnpack(dataString);
      final decoded = unpacked.replaceAll('\\', '');

      // Extract video ID
      final vidMatch = RegExp(r'FirePlayer\("(.*?)"').firstMatch(decoded);
      if (vidMatch == null || vidMatch.group(1) == null) {
        Logger.warning('PixFusion: video id not found');
        return const [];
      }

      final videoId = vidMatch.group(1) ?? '';
      final domain = '${request.url.scheme}://${request.url.host}';

      // Fetch video source via POST
      final getVideoUrl =
          '$domain/player/index.php?data=${Uri.encodeComponent(videoId)}&do=getVideo';

      final res = await _dio.post(
        getVideoUrl,
        options: Options(
          headers: {
            'Referer': request.url.toString(),
            'X-Requested-With': 'XMLHttpRequest',
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
          },
        ),
      );

      final videoUrl = res.data as String? ?? '';

      if (videoUrl.isEmpty) {
        Logger.warning('PixFusion: Video URL not found');
        return const [];
      }

      return [
        RawStream(
          url: Uri.parse(videoUrl),
          isM3u8: videoUrl.contains('.m3u8'),
          sourceLabel: name,
        ),
      ];
    } catch (error, stackTrace) {
      Logger.error(
        'PixFusion extractor failed',
        tag: 'PixFusionExtractor',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }
}
