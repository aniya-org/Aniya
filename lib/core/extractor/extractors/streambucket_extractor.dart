import 'package:aniya/core/extractor/base/base_extractor.dart';
import 'package:aniya/core/extractor/base/extractor_info.dart';
import 'package:aniya/core/extractor/models/extractor_request.dart';
import 'package:aniya/core/extractor/models/raw_stream.dart';
import 'package:aniya/core/extractor/utils/js_unpacker.dart';
import 'package:aniya/core/utils/logger.dart';
import 'package:dio/dio.dart';

/// Ported from ref/umbrella/.../StreamBucket.ts
/// Original code by yogesh-hacker: https://github.com/yogesh-hacker
/// Credit: https://github.com/yogesh-hacker/MediaVanced/blob/main/sites/streambucket.py
class StreamBucketExtractor extends BaseExtractor {
  StreamBucketExtractor({Dio? dio})
    : _dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));

  static final ExtractorInfo info = ExtractorInfo(
    id: 'streambucket',
    patterns: [RegExp(r'streambucket\.')],
    category: ExtractorCategory.video,
    extractors: [StreamBucketExtractor()],
  );

  final Dio _dio;

  @override
  String get name => 'StreamBucket';

  @override
  Future<List<RawStream>> extract(ExtractorRequest request) async {
    try {
      final response = await _dio.getUri(
        request.url,
        options: Options(headers: {'Referer': request.url.toString()}),
      );

      final body = response.data as String;

      // Find packed hunter-like data
      final pattern = RegExp(
        r'\(\s*function\s*\([^\)]*\)\s*\{.*?\}\s*\(\s*(.*?)\s*\)\s*\)',
        dotAll: true,
      );
      final m = pattern.firstMatch(body);

      if (m == null) {
        Logger.warning('StreamBucket: Encoded pack not found');
        return const [];
      }

      var pack = m.group(1) ?? '';

      // Remove split calls
      pack = pack.replaceAll(RegExp(r"\.split\('\|'\)"), '');

      // Unpack the code
      final unpacked = safeUnpack(pack);
      final decoded = unpacked.replaceAll('\\', '');

      // Extract file URL
      final fileMatch =
          RegExp(r'file:"(https?:\/\/[^"]+)"').firstMatch(decoded) ??
          RegExp(r"file:'(https?:\/\/[^']+)'").firstMatch(decoded);

      if (fileMatch == null || fileMatch.group(1) == null) {
        Logger.warning('StreamBucket: Video URL not found');
        return const [];
      }

      final videoUrl = fileMatch.group(1) ?? '';

      return [
        RawStream(
          url: Uri.parse(videoUrl),
          isM3u8: videoUrl.contains('.m3u8'),
          sourceLabel: name,
        ),
      ];
    } catch (error, stackTrace) {
      Logger.error(
        'StreamBucket extractor failed',
        tag: 'StreamBucketExtractor',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }
}
