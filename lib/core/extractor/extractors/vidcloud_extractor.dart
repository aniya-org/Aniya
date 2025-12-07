import 'package:aniya/core/extractor/base/base_extractor.dart';
import 'package:aniya/core/extractor/base/extractor_info.dart';
import 'package:aniya/core/extractor/models/extractor_request.dart';
import 'package:aniya/core/extractor/models/raw_stream.dart';
import 'package:aniya/core/utils/logger.dart';
import 'package:dio/dio.dart';

/// Ported from ref/umbrella/.../VidCloud.ts (original credit:
/// https://github.com/2004durgesh/react-native-consumet/blob/main/src/extractors/vidcloud.ts).
class VidCloudExtractor extends BaseExtractor {
  VidCloudExtractor({Dio? dio})
    : _dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));

  static final ExtractorInfo info = ExtractorInfo(
    id: 'vidcloud',
    patterns: [
      RegExp(r'vidcloud\.'),
      RegExp(r'vidsrc\.stream'),
      RegExp(r'cloudvidz\.'),
      RegExp(r'cdnstreame\.'),
    ],
    category: ExtractorCategory.video,
    extractors: [VidCloudExtractor()],
  );

  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36';

  final Dio _dio;

  @override
  String get name => 'VidCloud';

  @override
  Future<List<RawStream>> extract(ExtractorRequest request) async {
    final results = <RawStream>[];
    final referer = request.url.toString();
    final headers = {
      'X-Requested-With': 'XMLHttpRequest',
      'Referer': referer,
      'User-Agent': _userAgent,
    };

    try {
      final response = await _dio.getUri(
        request.url,
        options: Options(headers: headers),
      );
      final body = response.data as String;
      final sourceMatches = RegExp(r'file:\s*"([^"]+)"').allMatches(body);
      for (final match in sourceMatches) {
        final url = match.group(1);
        if (url == null) {
          continue;
        }
        results.add(
          RawStream(
            url: Uri.parse(url),
            isM3u8: url.contains('.m3u8'),
            sourceLabel: name,
            headers: headers,
          ),
        );
      }

      // Expand m3u8 playlists into explicit variants when possible.
      final additional = await Future.wait(
        results
            .where((stream) => stream.isM3u8)
            .map((stream) => _expandM3u8(stream, headers)),
      );
      for (final list in additional) {
        results.addAll(list);
      }

      return results;
    } catch (error, stackTrace) {
      Logger.error(
        'VidCloud extractor failed',
        tag: 'VidCloudExtractor',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }

  Future<List<RawStream>> _expandM3u8(
    RawStream stream,
    Map<String, String> headers,
  ) async {
    try {
      final response = await _dio.get(
        stream.url.toString(),
        options: Options(headers: headers),
      );
      final playlist = response.data as String;
      final resolutionRegex = RegExp(r'RESOLUTION=\d+x(\d+)');
      final resolutions = resolutionRegex.allMatches(playlist).toList();
      final urlLines = playlist
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty && !line.startsWith('#'))
          .where((line) => line.contains('m3u8'))
          .toList();

      final variants = <RawStream>[];
      final baseUri = stream.url;
      final baseSegments = List<String>.from(baseUri.pathSegments);
      if (baseSegments.isNotEmpty) {
        baseSegments.removeLast();
      }
      final basePath = baseUri.replace(pathSegments: baseSegments);

      for (var i = 0; i < urlLines.length; i++) {
        final urlLine = urlLines[i];
        final resolved = Uri.parse(urlLine).isAbsolute
            ? Uri.parse(urlLine)
            : basePath.resolve(urlLine);
        final quality = i < resolutions.length ? resolutions[i].group(1) : null;
        variants.add(
          RawStream(
            url: resolved,
            isM3u8: true,
            quality: quality != null ? '${quality}p' : 'auto',
            sourceLabel: name,
            headers: headers,
          ),
        );
      }

      return variants;
    } catch (_) {
      return const [];
    }
  }
}
