import 'package:aniya/core/extractor/base/base_extractor.dart';
import 'package:aniya/core/extractor/base/extractor_info.dart';
import 'package:aniya/core/extractor/models/extractor_request.dart';
import 'package:aniya/core/extractor/models/raw_stream.dart';
import 'package:aniya/core/extractor/utils/subtitle_utils.dart';
import 'package:aniya/core/utils/logger.dart';
import 'package:dio/dio.dart';

/// Ported from ref/umbrella/.../StreamWish.ts (original credit to
/// https://github.com/2004durgesh/react-native-consumet and
/// https://github.com/Zenda-Cross/vega-app for the decoding logic).
class StreamWishExtractor extends BaseExtractor {
  StreamWishExtractor({Dio? dio})
    : _dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 20)));

  static final ExtractorInfo info = ExtractorInfo(
    id: 'streamwish',
    patterns: [RegExp(r'streamwish\.'), RegExp(r'dhcplay\.')],
    category: ExtractorCategory.video,
    extractors: [StreamWishExtractor()],
  );

  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36';

  final Dio _dio;

  @override
  String get name => 'StreamWish';

  @override
  Future<List<RawStream>> extract(ExtractorRequest request) async {
    final headers = {
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
      'Accept-Encoding': '*',
      'Accept-Language': 'en-US,en;q=0.9',
      'Cache-Control': 'max-age=0',
      'Priority': 'u=0, i',
      'Origin': request.url.origin,
      'Referer': request.url.origin,
      'Sec-Ch-Ua':
          '"Google Chrome";v="129", "Not=A?Brand";v="8", "Chromium";v="129"',
      'Sec-Ch-Ua-Mobile': '?0',
      'Sec-Ch-Ua-Platform': 'Windows',
      'Sec-Fetch-Dest': 'document',
      'Sec-Fetch-Mode': 'navigate',
      'Sec-Fetch-Site': 'none',
      'Sec-Fetch-User': '?1',
      'Upgrade-Insecure-Requests': '1',
      'User-Agent': _userAgent,
    };

    try {
      final response = await _dio.getUri(
        request.url,
        options: Options(headers: headers),
      );
      final body = response.data as String;

      final decoded = _decodePackedString(body);
      if (decoded == null) {
        Logger.warning(
          'StreamWish: unable to decode eval payload for ${request.url}',
        );
        return const [];
      }

      final linkMatch = RegExp(
        r'''https?:\/\/[^"']+?\.m3u8[^"']*''',
      ).firstMatch(decoded);
      if (linkMatch == null) {
        Logger.warning('StreamWish: m3u8 link not found for ${request.url}');
        return const [];
      }

      var link = linkMatch.group(0)!;
      if (link.contains('hls2"')) {
        link = link.replaceAll('hls2"', '').replaceAll('"', '');
      }
      final separator = link.contains('?') ? '&' : '?';
      final streamUrl = '$link${separator}i=0.4';

      final subtitleMatches = RegExp(
        r'''{file:"([^"]+)",(label:"([^"]+)",)?kind:"(thumbnails|captions)"''',
      ).allMatches(decoded);
      final subtitles = subtitleMatches.map((match) {
        final file = match.group(1) ?? '';
        final label = match.group(3) ?? '';
        final kind = match.group(4) ?? '';
        if (kind.contains('thumbnail')) {
          final url = 'https://streamwish.com$file';
          return SubtitleTrack(
            url: Uri.parse(url),
            name: kind,
            language: kind,
            mimeType: detectSubtitleMimeType(url),
          );
        }
        return SubtitleTrack(
          url: Uri.parse(file),
          name: label,
          language: label,
          mimeType: detectSubtitleMimeType(file),
        );
      }).toList();

      final results = <RawStream>[
        RawStream(
          url: Uri.parse(streamUrl),
          isM3u8: streamUrl.contains('.m3u8'),
          sourceLabel: name,
          headers: headers,
          subtitles: subtitles,
        ),
      ];

      // Expand additional qualities.
      try {
        final playlistResponse = await _dio.get(
          streamUrl,
          options: Options(headers: headers),
        );
        final playlist = playlistResponse.data as String;
        if (playlist.contains('EXTM3U')) {
          final parts = playlist.split('#EXT-X-STREAM-INF:');
          for (final part in parts) {
            if (!part.contains('m3u8')) continue;
            final lines = part.split('\n');
            if (lines.length < 2) continue;
            final resolutionLine = lines.firstWhere(
              (line) => line.contains('RESOLUTION='),
              orElse: () => '',
            );
            final quality = resolutionLine.isNotEmpty
                ? resolutionLine
                      .split('RESOLUTION=')[1]
                      .split(',')[0]
                      .split('x')
                      .last
                : null;
            final url = "${link.split('master.m3u8')[0]}${lines[1]}";
            results.add(
              RawStream(
                url: Uri.parse(url),
                isM3u8: true,
                quality: quality != null ? '${quality}p' : 'auto',
                sourceLabel: name,
                headers: headers,
              ),
            );
          }
        }
      } catch (_) {}

      return results;
    } catch (error, stackTrace) {
      Logger.error(
        'StreamWish extractor failed',
        tag: 'StreamWishExtractor',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }

  String? _decodePackedString(String body) {
    final regex = RegExp(
      r"eval\(function\((.*?)\)\{.*?return p\}.*?\('(.*?)'\.split",
    );
    final match = regex.firstMatch(body);
    if (match == null) {
      return null;
    }
    final encoded = match.group(0)!;
    final parts = encoded.split("',36,");
    if (parts.length < 2) {
      return null;
    }
    var p = parts.first;
    final right = parts[1].split('|');
    var c = right.length;
    while (c-- > 0) {
      final replacement = right[c];
      if (replacement.isEmpty) continue;
      final reg = RegExp(r'\b' + c.toRadixString(36) + r'\b');
      p = p.replaceAll(reg, replacement);
    }
    return p;
  }
}
