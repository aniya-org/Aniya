import 'dart:convert';

import 'package:aniya/core/extractor/base/base_extractor.dart';
import 'package:aniya/core/extractor/base/extractor_info.dart';
import 'package:aniya/core/extractor/models/extractor_request.dart';
import 'package:aniya/core/extractor/models/raw_stream.dart';
import 'package:aniya/core/utils/logger.dart';
import 'package:dio/dio.dart';

/// Ported from ref/umbrella/.../NoodleMagazine.ts
/// Original code by yogesh-hacker: https://github.com/yogesh-hacker
/// Credit: https://github.com/yogesh-hacker/MediaVanced/blob/main/sites/noodlemagazine.py
class NoodleMagazineExtractor extends BaseExtractor {
  NoodleMagazineExtractor({Dio? dio})
    : _dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));

  static final ExtractorInfo info = ExtractorInfo(
    id: 'noodlemagazine',
    patterns: [RegExp(r'noodlemagazine\.'), RegExp(r'noodlemagazine\.com')],
    category: ExtractorCategory.video,
    extractors: [NoodleMagazineExtractor()],
  );

  final Dio _dio;

  @override
  String get name => 'NoodleMagazine';

  @override
  Future<List<RawStream>> extract(ExtractorRequest request) async {
    try {
      final response = await _dio.getUri(
        request.url,
        options: Options(
          headers: {
            'Referer': request.url.toString(),
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 11; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
          },
        ),
      );

      final body = response.data as String;

      // Extract window.playlist = {...};
      final match = RegExp(
        r'window\.playlist\s*=\s*({[\s\S]*?});',
      ).firstMatch(body);

      if (match == null || match.group(1) == null) {
        Logger.warning('NoodleMagazine: playlist not found');
        return const [];
      }

      final jsonText = match.group(1) ?? '';

      Map<String, dynamic> parsed;
      try {
        parsed = jsonDecode(jsonText) as Map<String, dynamic>;
      } catch (e) {
        Logger.warning('NoodleMagazine: Failed to parse playlist JSON');
        return const [];
      }

      final List<RawStream> streams = [];
      final qualities = parsed['sources'] as List<dynamic>? ?? [];

      for (final q in qualities) {
        final qMap = q as Map<String, dynamic>?;
        if (qMap == null) continue;

        final file = qMap['file'] as String? ?? '';
        if (file.isEmpty) continue;

        final label = qMap['label'] as String? ?? '';
        final displayName = label.isNotEmpty ? '$name $label' : name;

        streams.add(
          RawStream(
            url: Uri.parse(file),
            isM3u8: file.contains('.m3u8'),
            quality: label.isNotEmpty ? label : null,
            sourceLabel: displayName,
          ),
        );
      }

      if (streams.isEmpty) {
        Logger.warning('NoodleMagazine: No sources found');
        return const [];
      }

      return streams;
    } catch (error, stackTrace) {
      Logger.error(
        'NoodleMagazine extractor failed',
        tag: 'NoodleMagazineExtractor',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }
}
