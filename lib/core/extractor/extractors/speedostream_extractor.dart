import 'package:aniya/core/extractor/base/base_extractor.dart';
import 'package:aniya/core/extractor/base/extractor_info.dart';
import 'package:aniya/core/extractor/models/extractor_request.dart';
import 'package:aniya/core/extractor/models/raw_stream.dart';
import 'package:aniya/core/utils/logger.dart';
import 'package:dio/dio.dart';

/// Ported from ref/umbrella/.../SpeedoStream.ts
/// Original code by yogesh-hacker: https://github.com/yogesh-hacker
/// Credit: https://github.com/yogesh-hacker/MediaVanced/blob/main/sites/speedostream.py
class SpeedoStreamExtractor extends BaseExtractor {
  SpeedoStreamExtractor({Dio? dio})
    : _dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));

  static final ExtractorInfo info = ExtractorInfo(
    id: 'speedostream',
    patterns: [
      RegExp(r'speedostream\.'),
      RegExp(r'spedostream\.'),
      RegExp(r'speedostream\.pm'),
    ],
    category: ExtractorCategory.video,
    extractors: [SpeedoStreamExtractor()],
  );

  final Dio _dio;

  @override
  String get name => 'SpeedoStream';

  @override
  Future<List<RawStream>> extract(ExtractorRequest request) async {
    try {
      final defaultDomain = '${request.url.scheme}://${request.url.host}/';

      final response = await _dio.getUri(
        request.url,
        options: Options(headers: {'Referer': defaultDomain}),
      );

      final body = response.data as String;
      final match = RegExp(r'file:"([^"]+)"').firstMatch(body);

      if (match == null || match.group(1) == null) {
        Logger.warning('SpeedoStream: Video URL not found');
        return const [];
      }

      final videoUrl = match.group(1) ?? '';

      return [
        RawStream(
          url: Uri.parse(videoUrl),
          isM3u8: videoUrl.contains('.m3u8'),
          sourceLabel: name,
        ),
      ];
    } catch (error, stackTrace) {
      Logger.error(
        'SpeedoStream extractor failed',
        tag: 'SpeedoStreamExtractor',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }
}
