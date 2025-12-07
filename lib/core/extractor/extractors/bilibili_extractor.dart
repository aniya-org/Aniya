import 'package:aniya/core/extractor/base/base_extractor.dart';
import 'package:aniya/core/extractor/base/extractor_info.dart';
import 'package:aniya/core/extractor/models/extractor_request.dart';
import 'package:aniya/core/extractor/models/raw_stream.dart';
import 'package:aniya/core/utils/logger.dart';

/// Ported from ref/umbrella/.../Bilibili.ts
/// Original code by 2004durgesh: https://github.com/2004durgesh
/// Credit: https://github.com/2004durgesh/react-native-consumet
class BilibiliExtractor extends BaseExtractor {
  BilibiliExtractor();

  static final ExtractorInfo info = ExtractorInfo(
    id: 'bilibili',
    patterns: [RegExp(r'bilibili\.'), RegExp(r'bilibili\.com')],
    category: ExtractorCategory.video,
    extractors: [BilibiliExtractor()],
  );

  @override
  String get name => 'Bilibili';

  @override
  Future<List<RawStream>> extract(ExtractorRequest request) async {
    try {
      // Extract episode ID from URL
      String? episodeId;

      final urlStr = request.url.toString();
      final episodeMatch = RegExp(r'episode_id=(\d+)').firstMatch(urlStr);
      if (episodeMatch != null && episodeMatch.group(1) != null) {
        episodeId = episodeMatch.group(1);
      }

      if (episodeId == null) {
        final epMatch = RegExp(r'ep(\d+)').firstMatch(urlStr);
        if (epMatch != null && epMatch.group(1) != null) {
          episodeId = epMatch.group(1);
        }
      }

      if (episodeId == null) {
        final parts = urlStr.split('/');
        episodeId = parts.isNotEmpty ? parts.last : null;
      }

      if (episodeId == null || episodeId.isEmpty) {
        Logger.warning('Bilibili: No episode ID found');
        return const [];
      }

      // Use Consumet API for playback URL
      // Use consumet API for Bilibili extraction
      final apiUrl =
          'https://api.consumet.org/utils/bilibili/playurl?episode_id=$episodeId';

      return [
        RawStream(url: Uri.parse(apiUrl), isM3u8: false, sourceLabel: name),
      ];
    } catch (error, stackTrace) {
      Logger.error(
        'Bilibili extractor failed',
        tag: 'BilibiliExtractor',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }
}
