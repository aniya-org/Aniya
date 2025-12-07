import 'package:aniya/core/extractor/base/base_extractor.dart';
import 'package:aniya/core/extractor/base/extractor_info.dart';
import 'package:aniya/core/extractor/models/extractor_request.dart';
import 'package:aniya/core/extractor/models/raw_stream.dart';
import 'package:aniya/core/utils/logger.dart';
import 'package:dio/dio.dart';

/// Ported from ref/umbrella/.../VidHideExtractor.ts
class VidHideExtractor extends BaseExtractor {
  VidHideExtractor({Dio? dio})
    : _dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));

  static final ExtractorInfo info = ExtractorInfo(
    id: 'vid-hide',
    patterns: [RegExp(r'[a-z]lions\.'), RegExp(r'smoothpre\.')],
    category: ExtractorCategory.video,
    extractors: [VidHideExtractor()],
  );

  final Dio _dio;
  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36';

  @override
  String get name => 'VidHide';

  @override
  Future<List<RawStream>> extract(ExtractorRequest request) async {
    try {
      final response = await _dio.getUri(
        request.url,
        options: Options(
          headers: {
            'User-Agent': _userAgent,
            'Referer': request.url.toString(),
          },
        ),
      );

      final responseText = response.data as String;

      if (responseText.isEmpty) {
        return const [];
      }

      // Extract script content
      final scriptMatch = RegExp(
        r'eval([\s\S]*?)<\/script>',
      ).firstMatch(responseText);
      if (scriptMatch == null || scriptMatch.group(1) == null) {
        Logger.warning('VidHide: Could not find script');
        return const [];
      }

      final script = scriptMatch.group(1) ?? '';

      // Extract URL scheme
      final urlSchemeMatch = RegExp(r'http.').firstMatch(script);
      if (urlSchemeMatch == null) {
        Logger.warning('VidHide: Could not find URL scheme');
        return const [];
      }

      var urlScheme = urlSchemeMatch.group(0) ?? 'https';
      if (urlScheme.endsWith('|')) {
        urlScheme = urlScheme.substring(0, urlScheme.length - 1);
      }

      // Extract s and f values
      final sAndFMatch = RegExp(
        r'data\|.*?([0-9]+)\|([0-9]+)',
      ).firstMatch(script);
      if (sAndFMatch == null) {
        Logger.warning('VidHide: Could not find s and f values');
        return const [];
      }

      final s = sAndFMatch.group(1) ?? '';
      final f = sAndFMatch.group(2) ?? '';

      // Extract srv
      final srvMatch = RegExp(r'file\|+[0-9]*\|(.*?)\|').firstMatch(script);
      if (srvMatch == null) {
        Logger.warning('VidHide: Could not find srv');
        return const [];
      }

      final srv = srvMatch.group(1) ?? '';

      // Extract i
      final iMatch = RegExp(r'i=([0-9\.]*)&').firstMatch(script);
      if (iMatch == null) {
        Logger.warning('VidHide: Could not find i value');
        return const [];
      }

      final i = iMatch.group(1) ?? '';

      // Extract asn
      final asnMatch = RegExp(r'text\|+([0-9]*)\|').firstMatch(script);
      if (asnMatch == null) {
        Logger.warning('VidHide: Could not find asn');
        return const [];
      }

      final asn = asnMatch.group(1) ?? '';

      // Extract domain end
      final domainEndMatch = RegExp(
        r'[0-9]+\|[0-9]+\|[0-9]+\|[a-z]+\|(.*?)\|',
      ).firstMatch(script);
      if (domainEndMatch == null) {
        Logger.warning('VidHide: Could not find domain end');
        return const [];
      }

      final domainEnd = domainEndMatch.group(1) ?? '';

      // Extract info chunk
      final infoChunkStart = script.split('|width|');
      if (infoChunkStart.length < 2) {
        Logger.warning('VidHide: Could not find info chunk start');
        return const [];
      }

      final infoChunkEnd = infoChunkStart[1].split('|sources|')[0];
      final infoChunkSplit = infoChunkEnd.split('|');
      infoChunkSplit.sort((a, b) => b.compareTo(a)); // reverse

      final infoChunkOffset =
          infoChunkSplit.length > 2 && infoChunkSplit[2] == 'hls2' ? 0 : 1;

      // Build origin URL
      final origin =
          '$urlScheme://${infoChunkSplit[0]}.${infoChunkSplit[1]}${infoChunkOffset == 0 ? '' : '-${infoChunkSplit[2]}'}.${domainEnd}/${infoChunkSplit[infoChunkOffset + 2]}';

      var urlset = '/';
      if (origin.contains('urlset')) {
        urlset = ',l,n,h,.urlset/';
      }

      // Extract t and e
      final tAndEMatch = RegExp(
        r'srv\|([0-9]+)\|([\s\S]*?)\|m3u8',
      ).firstMatch(script);
      if (tAndEMatch == null) {
        Logger.warning('VidHide: Could not find t and e values');
        return const [];
      }

      final tList = (tAndEMatch.group(2) ?? '').split('|');
      tList.sort((a, b) => b.compareTo(a)); // reverse
      final t = tList.join('-');
      final e = tAndEMatch.group(1) ?? '';

      // Build video URL
      final spIndex = infoChunkSplit.indexOf('sp');
      final sp = spIndex >= 0 && spIndex + 1 < infoChunkSplit.length
          ? infoChunkSplit[spIndex + 1]
          : '';

      final videoUrl =
          '$origin/${infoChunkSplit[infoChunkOffset + 3]}/${infoChunkSplit[infoChunkOffset + 4]}/${infoChunkSplit[infoChunkOffset + 5]}${urlset}master.m3u8?t=$t&s=$s&e=$e&f=$f&srv=$srv&i=$i&sp=$sp&p1=$srv&p2=$srv&asn=$asn';

      return [
        RawStream(url: Uri.parse(videoUrl), isM3u8: true, sourceLabel: name),
      ];
    } catch (error, stackTrace) {
      Logger.error(
        'VidHide extractor failed',
        tag: 'VidHideExtractor',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }
}
