const String sampleAniyaPlugin = r'''
import 'dart:convert';

Map<String, dynamic> _asStringKeyedMap(dynamic value) {
  if (value is Map) {
    final out = <String, dynamic>{};
    for (final entry in value.entries) {
      out[entry.key.toString()] = entry.value;
    }
    return out;
  }
  return <String, dynamic>{};
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

String _asString(dynamic value) => value?.toString() ?? '';

Map<String, dynamic> _media({
  required String title,
  required String url,
  String? cover,
  String? description,
}) {
  return {
    'title': title,
    'url': url,
    'cover': cover ?? '',
    'description': description ?? '',
    'genre': <String>[],
    'episodes': <Map<String, dynamic>>[],
  };
}

Map<String, dynamic> _episode({
  required String url,
  required String name,
  required String episodeNumber,
}) {
  return {
    'url': url,
    'name': name,
    'episodeNumber': episodeNumber,
  };
}

Map<String, dynamic> _video({
  String? title,
  required String url,
  required String quality,
}) {
  return {
    'title': title ?? quality,
    'url': url,
    'quality': quality,
    'headers': <String, String>{},
    'subtitles': <Map<String, dynamic>>[],
    'audios': <Map<String, dynamic>>[],
  };
}

Map<String, dynamic> _pageUrl({
  required String url,
}) {
  return {
    'url': url,
    'headers': <String, String>{},
  };
}

Map<String, dynamic> _pages(
  List<Map<String, dynamic>> items, {
  bool hasNextPage = false,
}) {
  return {
    'list': items,
    'hasNextPage': hasNextPage,
  };
}

dynamic search(
  dynamic query,
  dynamic page,
  dynamic filters,
  Function httpGet,
  Function soupParse,
  Function sha256Hex,
) async {
  final queryStr = _asString(query);
  final pageNum = _asInt(page, fallback: 1);

  final items = <Map<String, dynamic>>[
    _media(
      title: 'Search result for "$queryStr" (page $pageNum)',
      url: 'https://example.com/search/$pageNum?q=${Uri.encodeQueryComponent(queryStr)}',
      description: 'Returned by the sample search() method.',
    ),
  ];

  return json.encode(_pages(items, hasNextPage: false));
}

dynamic getPopular(
  dynamic page,
  Function httpGet,
  Function soupParse,
  Function sha256Hex,
) async {
  final pageNum = _asInt(page, fallback: 1);

  final items = <Map<String, dynamic>>[
    _media(
      title: 'Popular item #$pageNum',
      url: 'https://example.com/popular/$pageNum',
      description: 'Example popular media on page $pageNum.',
    ),
  ];

  return json.encode(_pages(items, hasNextPage: pageNum < 5));
}

dynamic getLatestUpdates(
  dynamic page,
  Function httpGet,
  Function soupParse,
  Function sha256Hex,
) async {
  final pageNum = _asInt(page, fallback: 1);

  final items = <Map<String, dynamic>>[
    _media(
      title: 'Latest update #$pageNum',
      url: 'https://example.com/latest/$pageNum',
      description: 'Example latest-updated media on page $pageNum.',
    ),
  ];

  return json.encode(_pages(items, hasNextPage: pageNum < 3));
}

dynamic getDetail(
  dynamic media,
  Function httpGet,
  Function soupParse,
  Function sha256Hex,
) async {
  final base = _asStringKeyedMap(media);
  base['description'] = base['description'] ?? 'Populated by getDetail().';

  final baseUrl = _asString(base['url']);
  base['episodes'] = <Map<String, dynamic>>[
    _episode(
      url: '$baseUrl/ep-1',
      name: 'Episode 1',
      episodeNumber: '1',
    ),
    _episode(
      url: '$baseUrl/ep-2',
      name: 'Episode 2',
      episodeNumber: '2',
    ),
  ];

  return json.encode(base);
}

dynamic getPageList(
  dynamic episode,
  Function httpGet,
  Function soupParse,
  Function sha256Hex,
) async {
  final ep = _asStringKeyedMap(episode);
  final epUrl = _asString(ep['url']);

  final pages = <Map<String, dynamic>>[
    _pageUrl(url: '$epUrl/page-1.jpg'),
    _pageUrl(url: '$epUrl/page-2.jpg'),
  ];

  return json.encode(pages);
}

dynamic getVideoList(
  dynamic episode,
  Function httpGet,
  Function soupParse,
  Function sha256Hex,
) async {
  final ep = _asStringKeyedMap(episode);
  final epUrl = _asString(ep['url']);

  final videos = <Map<String, dynamic>>[
    _video(
      title: 'Sample 1080p',
      url: '$epUrl/stream-1080p.m3u8',
      quality: '1080p',
    ),
    _video(
      title: 'Sample 720p',
      url: '$epUrl/stream-720p.m3u8',
      quality: '720p',
    ),
  ];

  return json.encode(videos);
}

dynamic getNovelContent(
  dynamic chapterTitle,
  dynamic chapterId,
  Function httpGet,
  Function soupParse,
  Function sha256Hex,
) async {
  final titleStr = _asString(chapterTitle);
  final idStr = _asString(chapterId);
  return 'Sample novel content for "$titleStr" (id=$idStr).';
}

dynamic getPreference(
  Function httpGet,
  Function soupParse,
  Function sha256Hex,
) {
  final prefs = <Map<String, dynamic>>[
    {
      'id': 1,
      'key': 'enable_experimental',
      'type': 'checkbox',
      'checkBoxPreference': {
        'title': 'Enable experimental mode',
        'summary': 'Turns on extra logging and debug behaviour.',
        'value': false,
      },
    },
  ];

  return json.encode(prefs);
}

dynamic setPreference(
  dynamic pref,
  dynamic value,
  Function httpGet,
  Function soupParse,
  Function sha256Hex,
) {
  return true;
}
''';
