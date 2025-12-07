import 'dart:convert';

import 'package:aniya/core/extractor/base/base_extractor.dart';
import 'package:aniya/core/extractor/base/extractor_info.dart';
import 'package:aniya/core/extractor/models/extractor_request.dart';
import 'package:aniya/core/extractor/models/raw_stream.dart';
import 'package:aniya/core/utils/logger.dart';
import 'package:dio/dio.dart';

/// Ported from ref/umbrella/.../StreamSb.ts (and the original
/// react-native-consumet implementation).
class StreamSbExtractor extends BaseExtractor {
  StreamSbExtractor({Dio? dio})
    : _dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 20)));

  static final ExtractorInfo info = ExtractorInfo(
    id: 'streamsb',
    patterns: [
      RegExp(r'streamsb\.'),
      RegExp(r'watchsb\.'),
      RegExp(r'streamsss\.'),
    ],
    category: ExtractorCategory.video,
    extractors: [StreamSbExtractor()],
  );

  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36';

  final Dio _dio;
  final String _host = 'https://streamsss.net/sources50';

  @override
  String get name => 'StreamSB';

  @override
  Future<List<RawStream>> extract(ExtractorRequest request) async {
    try {
      final id = _extractId(request.url.toString());
      if (id == null) {
        Logger.warning('StreamSB: unable to parse id from ${request.url}');
        return const [];
      }

      final headers = {
        'watchsb': 'sbstream',
        'User-Agent': _userAgent,
        'Referer': request.url.toString(),
      };

      final payloadHex = _buildPayload(id);
      final sourceResponse = await _dio.get(
        '$_host/$payloadHex',
        options: Options(headers: headers),
      );

      final streamData = sourceResponse.data['stream_data'];
      if (streamData == null) {
        Logger.warning('StreamSB: no stream_data for ${request.url}');
        return const [];
      }

      final fileUrl = streamData['file'] as String;
      final playlistHeaders = {
        'User-Agent': _userAgent,
        'Referer': request.url.toString().split('/e/').first,
      };
      final playlistResponse = await _dio.get(
        fileUrl,
        options: Options(headers: playlistHeaders),
      );

      final playlist = playlistResponse.data as String;
      final videoList = playlist.split('#EXT-X-STREAM-INF:');
      final streams = <RawStream>[];

      for (final video in videoList) {
        if (!video.contains('m3u8')) continue;
        final lines = video.split('\n');
        if (lines.length < 2) continue;
        final url = lines[1].trim();
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
        streams.add(
          RawStream(
            url: Uri.parse(url),
            isM3u8: true,
            quality: quality != null ? '${quality}p' : 'auto',
            sourceLabel: name,
            headers: playlistHeaders,
          ),
        );
      }

      streams.add(
        RawStream(
          url: Uri.parse(fileUrl),
          isM3u8: fileUrl.contains('.m3u8'),
          sourceLabel: name,
          headers: playlistHeaders,
        ),
      );

      return streams;
    } catch (error, stackTrace) {
      Logger.error(
        'StreamSB extractor failed',
        tag: 'StreamSbExtractor',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }

  String? _extractId(String url) {
    final parts = url.split('/e/');
    if (parts.length < 2) {
      return null;
    }
    final idPart = parts.last.split('.html').first;
    return idPart;
  }

  String _buildPayload(String id) {
    final bytes = utf8.encode(id);
    final buffer = StringBuffer();
    for (final byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    final hex = buffer.toString();
    return '566d337678566f743674494a7c7c${hex}7c7c346b6767586d6934774855537c7c73747265616d7362/6565417268755339773461447c7c346133383438333436313335376136323337373433383634376337633465366534393338373136643732373736343735373237613763376334363733353737303533366236333463353333363534366137633763373337343732363536313664373336327c7c6b586c3163614468645a47617c7c73747265616d7362';
  }
}
