import 'package:aniya/core/extractor/base/base_extractor.dart';
import 'package:aniya/core/extractor/base/extractor_info.dart';
import 'package:aniya/core/extractor/models/extractor_request.dart';
import 'package:aniya/core/extractor/models/raw_stream.dart';
import 'package:aniya/core/utils/logger.dart';
import 'package:dio/dio.dart';

/// Ported from ref/umbrella/.../VizCloud.ts
/// Original code by 2004durgesh: https://github.com/2004durgesh
/// Credit: https://github.com/2004durgesh/react-native-consumet
/// Note: Simplified implementation - complex encryption deferred
class VizCloudExtractor extends BaseExtractor {
  VizCloudExtractor({Dio? dio})
    : _dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));

  static final ExtractorInfo info = ExtractorInfo(
    id: 'vizcloud',
    patterns: [RegExp(r'vidstream\.pro'), RegExp(r'vizcloud\.')],
    category: ExtractorCategory.video,
    extractors: [VizCloudExtractor()],
  );

  final Dio _dio;

  @override
  String get name => 'VizCloud';

  @override
  Future<List<RawStream>> extract(ExtractorRequest request) async {
    try {
      final response = await _dio.getUri(request.url);

      final body = response.data as String;

      // Try to find direct video sources in the response
      final fileMatches = RegExp(r'file:\s*"([^"]+)"').allMatches(body);

      if (fileMatches.isEmpty) {
        Logger.warning('VizCloud: No video sources found');
        return const [];
      }

      final streams = <RawStream>[];

      for (final match in fileMatches) {
        final url = match.group(1);
        if (url != null && url.isNotEmpty) {
          streams.add(
            RawStream(
              url: Uri.parse(url),
              isM3u8: url.contains('.m3u8'),
              sourceLabel: name,
            ),
          );
        }
      }

      if (streams.isEmpty) {
        Logger.warning('VizCloud: No valid video URLs extracted');
        return const [];
      }

      return streams;
    } catch (error, stackTrace) {
      Logger.error(
        'VizCloud extractor failed',
        tag: 'VizCloudExtractor',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }
}
