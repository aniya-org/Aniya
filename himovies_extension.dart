import 'dart:convert';

String _asString(dynamic value) {
  final s = value?.toString();
  if (s == null || s == 'null') return '';
  if (s.length >= 3) {
    if (s.startsWith(r'$"') && s.endsWith('"')) {
      return s.substring(2, s.length - 1);
    }
    if (s.startsWith(r"$'") && s.endsWith("'")) {
      return s.substring(2, s.length - 1);
    }
  }
  return s;
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  return int.tryParse(_asString(value)) ?? fallback;
}

bool asBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  final s = _asString(value).toLowerCase().trim();
  if (s == 'true' || s == '1' || s == 'yes') return true;
  if (s == 'false' || s == '0' || s == 'no') return false;
  return fallback;
}

List<dynamic> _asList(dynamic value) {
  if (value is List) return value;
  if (value is Iterable) return value.toList();
  return const <dynamic>[];
}

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

Map<String, String> asStringKeyedStringMap(dynamic value) {
  final raw = _asStringKeyedMap(value);
  final out = <String, String>{};
  for (final entry in raw.entries) {
    out[entry.key] = _asString(entry.value);
  }
  return out;
}

Future<String> _httpGetText(
  Function httpGet,
  String url, {
  Map<String, String>? headers,
}) async {
  final res = headers == null ? httpGet(url) : httpGet(url, headers);
  final body = res is Future ? await res : res;
  return body.toString();
}

String extractFirstHtmlTitle(String htmlOrSoup) {
  final match = RegExp(
    r'<title[^>]*>([^<]+)</title>',
    caseSensitive: false,
  ).firstMatch(htmlOrSoup);
  return match?.group(1)?.trim() ?? '';
}

Map<String, dynamic> _media({
  required String title,
  required String url,
  String? cover,
  String? description,
  String? author,
  String? artist,
  List<String>? genre,
  List<Map<String, dynamic>>? episodes,
}) {
  return {
    'title': title,
    'url': url,
    'cover': cover ?? '',
    'description': description ?? '',
    'author': author,
    'artist': artist,
    'genre': genre ?? <String>[],
    'episodes': episodes ?? <Map<String, dynamic>>[],
  };
}

Map<String, dynamic> _episode({
  required String url,
  required String name,
  required String episodeNumber,
  String? dateUpload,
  String? thumbnail,
  String? description,
  String? scanlator,
  bool? filler,
}) {
  return {
    'url': url,
    'name': name,
    'dateUpload': dateUpload,
    'thumbnail': thumbnail,
    'description': description,
    'scanlator': scanlator,
    'filler': filler,
    'episodeNumber': episodeNumber,
  };
}

Map<String, dynamic> _track({required String file, String? label}) {
  return {'file': file, 'label': label};
}

Map<String, dynamic> _video({
  String? title,
  required String url,
  required String quality,
  Map<String, String>? headers,
  List<Map<String, dynamic>>? subtitles,
  List<Map<String, dynamic>>? audios,
}) {
  return {
    'title': (title ?? quality).trim(),
    'url': url,
    'quality': quality,
    'headers': headers ?? <String, String>{},
    'subtitles': subtitles ?? <Map<String, dynamic>>[],
    'audios': audios ?? <Map<String, dynamic>>[],
  };
}

Map<String, dynamic> _pageUrl({
  required String url,
  Map<String, String>? headers,
}) {
  return {'url': url, 'headers': headers ?? <String, String>{}};
}

Map<String, dynamic> _pages(
  List<Map<String, dynamic>> items, {
  bool hasNextPage = false,
}) {
  return {'list': items, 'hasNextPage': hasNextPage};
}

const String _baseUrl = 'https://himovies.sx';

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

  // if (queryStr == '__demo__') {
  //   try {
  //     final html = await _httpGetText(
  //       httpGet,
  //       'https://example.com/',
  //       headers: <String, String>{
  //         'User-Agent': 'AniyaEval/0.1',
  //         'Accept': 'text/html',
  //       },
  //     );

  //     final soup = soupParse(html);
  //     final titleEl = soup.find('title');
  //     final titleFromSoup = _asString(titleEl?.string).trim();
  //     final title =
  //         titleFromSoup.isNotEmpty ? titleFromSoup : _extractFirstHtmlTitle(html);
  //     final signature = sha256Hex('$title:$pageNum').toString();

  //     final items = <Map<String, dynamic>>[
  //       _media(
  //         title: title.isEmpty ? 'Example Domain' : title,
  //         url: 'https://example.com/#$signature',
  //         description: 'Demo result from httpGet + soupParse + sha256Hex.',
  //       ),
  //     ];

  //     return json.encode(_pages(items, hasNextPage: false));
  //   } catch (_) {}
  // }

  // final items = <Map<String, dynamic>>[
  //   _media(
  //     title: 'Search "$queryStr" (page $pageNum)',
  //     url: 'https://example.com/search/$pageNum?q=${Uri.encodeQueryComponent(queryStr)}',
  //     description: 'filters=$filterCount',
  //     author: 'Sample author',
  //     genre: <String>['Demo'],
  //   ),
  // ];

  final encodedQuery = Uri.encodeComponent(
    queryStr.trim().toLowerCase().replaceAll(' ', '-'),
  );
  final html = await _httpGetText(
    httpGet,
    '$_baseUrl/search/$encodedQuery?page=$pageNum',
    headers: <String, String>{
      'User-Agent': 'Mozilla/5.0',
      'Accept': 'text/html',
      'Referer': '$_baseUrl/',
    },
  );

  final soup = soupParse(html);
  final rawResults = soup.findAll('div', {'class_': 'flw-item'});

  final items = <Map<String, dynamic>>[];
  for (final item in _asList(rawResults)) {
    final a = item.find('a');
    var title = _asString(a?.attr('title')).trim();
    if (title.isEmpty) {
      title = _asString(a?.text).trim();
    }
    final href = _asString(a?.attr('href')).trim();
    final url = href.startsWith('http')
        ? href
        : href.isEmpty
        ? ''
        : href.startsWith('/')
        ? '$_baseUrl$href'
        : '$_baseUrl/$href';

    final img = item.find('img');
    var cover = _asString(img?.attr('data-src')).trim();
    if (cover.isEmpty) {
      cover = _asString(img?.attr('src')).trim();
    }

    final description = _asString(
      item.find('span', {'class_': 'fdi-item'})?.text,
    ).trim();
    items.add(
      _media(title: title, url: url, cover: cover, description: description),
    );
  }

  final hasNextPage =
      soup.find('a', {
        'attrs': {'title': 'Next'},
      }) !=
      null;

  return json.encode(_pages(items, hasNextPage: hasNextPage));
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
      genre: <String>['Popular'],
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
      genre: <String>['Latest'],
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
  final baseUrl = _asString(base['url']);

  base['description'] = _asString(base['description']).isEmpty
      ? 'Populated by getDetail().'
      : base['description'];
  base['author'] = base['author'] ?? 'Sample author';
  base['artist'] = base['artist'] ?? 'Sample artist';
  base['genre'] = base['genre'] ?? <String>['Demo', 'Detail'];

  base['episodes'] = <Map<String, dynamic>>[
    _episode(
      url: '$baseUrl/ep-1',
      name: 'Episode 1',
      episodeNumber: '1',
      dateUpload: '2025-01-01',
      thumbnail: '$baseUrl/thumb-1.jpg',
      description: 'First episode.',
      filler: false,
    ),
    _episode(
      url: '$baseUrl/ep-2',
      name: 'Episode 2',
      episodeNumber: '2',
      dateUpload: '2025-01-02',
      thumbnail: '$baseUrl/thumb-2.jpg',
      description: 'Second episode.',
      filler: false,
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

  final headers = <String, String>{'Referer': epUrl};

  final pages = <Map<String, dynamic>>[
    _pageUrl(url: '$epUrl/page-1.jpg', headers: headers),
    _pageUrl(url: '$epUrl/page-2.jpg', headers: headers),
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

  final headers = <String, String>{'Referer': epUrl};

  final videos = <Map<String, dynamic>>[
    _video(
      title: 'Sample 1080p',
      url: '$epUrl/stream-1080p.m3u8',
      quality: '1080p',
      headers: headers,
      subtitles: <Map<String, dynamic>>[
        _track(file: '$epUrl/sub-en.vtt', label: 'English'),
      ],
    ),
    _video(
      title: 'Sample 720p',
      url: '$epUrl/stream-720p.m3u8',
      quality: '720p',
      headers: headers,
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
        'summary': 'Toggles extra debug behaviour.',
        'value': false,
      },
    },
    {
      'id': 2,
      'key': 'use_mirror',
      'type': 'switch',
      'switchPreferenceCompat': {
        'title': 'Use mirror',
        'summary': 'Switch to an alternate base URL.',
        'value': true,
      },
    },
    {
      'id': 3,
      'key': 'quality',
      'type': 'list',
      'listPreference': {
        'title': 'Preferred quality',
        'summary': 'Pick your default stream quality.',
        'valueIndex': 0,
        'entries': ['1080p', '720p', '480p'],
        'entryValues': ['1080p', '720p', '480p'],
      },
    },
    {
      'id': 4,
      'key': 'languages',
      'type': 'multi_select',
      'multiSelectListPreference': {
        'title': 'Audio languages',
        'summary': 'Preferred audio languages.',
        'entries': ['English', 'Japanese'],
        'entryValues': ['en', 'ja'],
        'values': ['en'],
      },
    },
    {
      'id': 5,
      'key': 'base_url',
      'type': 'edit_text',
      'editTextPreference': {
        'title': 'Base URL',
        'summary': 'Override the site base URL.',
        'value': 'https://example.com',
        'dialogTitle': 'Base URL',
        'dialogMessage': 'Enter a new base URL.',
        'text': 'https://example.com',
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
  final prefMap = _asStringKeyedMap(pref);
  final key = _asString(prefMap['key']).trim();
  if (key.isEmpty) return false;

  if (key == 'enable_experimental') {
    return true;
  }

  if (key == 'use_mirror') {
    return true;
  }

  if (key == 'quality') {
    return _asString(value).isNotEmpty;
  }

  if (key == 'languages') {
    final s = _asString(value).trim();
    return s.isNotEmpty && s != '[]';
  }

  if (key == 'base_url') {
    final m = _asStringKeyedMap(value);
    if (m.isNotEmpty) {
      final newValue = _asString(m['value']).trim();
      return newValue.isNotEmpty;
    }
    return _asString(value).trim().isNotEmpty;
  }

  return true;
}
