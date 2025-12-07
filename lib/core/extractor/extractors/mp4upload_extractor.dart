import 'package:aniya/core/extractor/base/base_extractor.dart';
import 'package:aniya/core/extractor/base/extractor_info.dart';
import 'package:aniya/core/extractor/models/extractor_request.dart';
import 'package:aniya/core/extractor/models/raw_stream.dart';
import 'package:aniya/core/utils/logger.dart';
import 'package:dio/dio.dart';

/// Ported from ref/umbrella/.../Mp4Upload.ts
/// Original code by 2004durgesh: https://github.com/2004durgesh
/// Credit: https://github.com/2004durgesh/react-native-consumet/blob/main/src/extractors/mp4upload.ts
class Mp4UploadExtractor extends BaseExtractor {
  Mp4UploadExtractor({Dio? dio})
    : _dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));

  static final ExtractorInfo info = ExtractorInfo(
    id: 'mp4upload',
    patterns: [RegExp(r'mp4upload\.')],
    category: ExtractorCategory.video,
    extractors: [Mp4UploadExtractor()],
  );

  final Dio _dio;

  @override
  String get name => 'Mp4Upload';

  @override
  Future<List<RawStream>> extract(ExtractorRequest request) async {
    try {
      final response = await _dio.getUri(request.url);
      final responseData = response.data as String;

      // Extract player.src() call with regex
      final playerSrcMatch = RegExp(
        r'(?<=player\.src\()\s*{\s*type:\s*"[^"]+",\s*src:\s*"([^"]+)"\s*}\s*(?=\);)',
        dotAll: true,
      ).firstMatch(responseData);

      if (playerSrcMatch == null || playerSrcMatch.group(1) == null) {
        Logger.warning('Mp4Upload: Stream URL not found');
        return const [];
      }

      final streamUrl = playerSrcMatch.group(1) ?? '';

      return [
        RawStream(
          url: Uri.parse(streamUrl),
          isM3u8: streamUrl.contains('.m3u8'),
          sourceLabel: name,
        ),
      ];
    } catch (error, stackTrace) {
      Logger.error(
        'Mp4Upload extractor failed',
        tag: 'Mp4UploadExtractor',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }
}
