import 'package:aniya/core/extractor/base/base_extractor.dart';
import 'package:aniya/core/extractor/base/extractor_info.dart';
import 'package:aniya/core/extractor/models/extractor_request.dart';
import 'package:aniya/core/extractor/models/raw_stream.dart';
import 'package:aniya/core/extractor/utils/subtitle_utils.dart';
import 'package:aniya/core/utils/logger.dart';
import 'package:dio/dio.dart';

/// Ported from ref/umbrella/.../JWPlayer.ts
class JWPlayerExtractor extends BaseExtractor {
  JWPlayerExtractor({Dio? dio})
    : _dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));

  static final ExtractorInfo info = ExtractorInfo(
    id: 'jw-player',
    patterns: [RegExp(r's3taku\.')],
    category: ExtractorCategory.video,
    extractors: [JWPlayerExtractor()],
  );

  final Dio _dio;

  @override
  String get name => 'JWPlayer';

  @override
  Future<List<RawStream>> extract(ExtractorRequest request) async {
    try {
      var success = false;
      var maxRetries = 10;
      dynamic responseData;

      while (!success && maxRetries > 0) {
        final playerResponse = await _dio.getUri(
          request.url,
          options: Options(
            headers: {
              'Referer': request.url.toString(),
              'Content-Type': 'application/x-www-form-urlencoded',
            },
          ),
        );

        final videoIdRegex = RegExp(r'\|ajaxUrl\|(.*?)\|video_id');
        final videoIdMatch = videoIdRegex.firstMatch(
          playerResponse.data as String,
        );
        if (videoIdMatch == null) {
          Logger.warning('JWPlayer: Could not find video ID');
          maxRetries--;
          continue;
        }

        final videoIdParts = (videoIdMatch.group(1) ?? '').split('|');
        videoIdParts.sort((a, b) => b.compareTo(a)); // reverse
        final videoId = videoIdParts.join('+') + '=';

        final playerNonceRegex = RegExp(r'\|autoPlay\|(.*?)\|playerNonce');
        final playerNonceMatch = playerNonceRegex.firstMatch(
          playerResponse.data as String,
        );
        if (playerNonceMatch == null) {
          Logger.warning('JWPlayer: Could not find player nonce');
          maxRetries--;
          continue;
        }

        final playerNonce = playerNonceMatch.group(1) ?? '';

        final ajaxUrl =
            '${request.url.scheme}://${request.url.host}/wp-admin/admin-ajax.php';

        final postData = {
          'action': 'get_player_data',
          'video_id': videoId,
          'player_nonce': playerNonce,
        };

        final response = await _dio.post(
          ajaxUrl,
          data: postData,
          options: Options(
            headers: {
              'Referer': request.url.toString(),
              'Content-Type': 'application/x-www-form-urlencoded',
            },
          ),
        );

        responseData = response.data;
        success = responseData is Map && responseData['success'] == true;
        maxRetries--;
      }

      if (responseData == null || responseData is! Map) {
        Logger.warning('JWPlayer: Failed to get player data');
        return const [];
      }

      if (responseData['success'] != true) {
        Logger.warning('JWPlayer: Player data success is false');
        return const [];
      }

      final List<RawStream> sources = [];

      // Process subtitles
      final subtitlesList = responseData['subtitles'] as List<dynamic>? ?? [];
      final subtitles = subtitlesList.map((subtitle) {
        final sub = subtitle as Map<String, dynamic>;
        return SubtitleTrack(
          url: Uri.parse(sub['url'] as String? ?? ''),
          language: sub['lang'] as String?,
          name: sub['lang'] as String?,
          mimeType: detectSubtitleMimeType(sub['url'] as String? ?? ''),
        );
      }).toList();

      // Process sources
      final sourcesList = responseData['sources'] as List<dynamic>? ?? [];
      for (final source in sourcesList) {
        final sourceMap = source as Map<String, dynamic>;
        final file = sourceMap['file'] as String? ?? '';
        final type = sourceMap['type'] as String? ?? '';

        if (file.isNotEmpty) {
          sources.add(
            RawStream(
              url: Uri.parse(file),
              isM3u8: type == 'hls',
              sourceLabel: name,
              subtitles: subtitles,
              headers: {
                'Referer': request.url.toString().split('watch?')[0],
                'User-Agent': 'Umbrella/1.0',
              },
            ),
          );
        }
      }

      return sources;
    } catch (error, stackTrace) {
      Logger.error(
        'JWPlayer extractor failed',
        tag: 'JWPlayerExtractor',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }
}
