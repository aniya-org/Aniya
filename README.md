# Aniya

A cross-platform Flutter application for discovering, reading manga, and streaming anime videos. Built with clean architecture, responsive design, and adaptive navigation for seamless experience on mobile, desktop, web, and more.

## ✨ Features

- **Cross-Platform Support**: Android, iOS, Web, Windows, macOS, Linux.
- **Responsive & Adaptive UI**: Handles different screen sizes and platforms with desktop window management and mobile features.
- **Manga Reader**: Intuitive reader with image caching and smooth navigation.
- **Video Player**: Integrated video playback for anime episodes.
- **Search & Library**: Powerful search, personal library management, and media details.
- **Authentication**: Secure user login and session management.
- **Modular Architecture**: Feature-based organization with dependency injection.
- **Clean Architecture**: Separation of concerns with domain, data, and presentation layers.
- **Advanced Navigation**: Shell-based navigation with custom page transitions.
- **Extensions & Plugin Bridge**: Built-in bridge for CloudStream, Aniyomi, Mangayomi, and LnReader plugins plus native Aniya eval extensions with safe plugin loading, extractor reuse, JSON URL sanitization, and script-based runtime.

## 🛠 Tech Stack

- **Framework**: Flutter (Dart)
- **Architecture**: Clean Architecture (domain / data / presentation)
- **DI**: GetIt
- **State Management**: GetX + Provider
- **Networking**: Dio + http + GraphQL (AniList)
- **Storage**: Hive + Isar + SharedPreferences
- **Extension Systems**: `dartotsu_extension_bridge` + in-app `dart_eval` runtime (Aniya eval extensions)

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel, version 3.24+ recommended)
- [Dart SDK](https://dart.dev/get-dart) (included with Flutter)
- IDE: VS Code or Android Studio with Flutter/Dart plugins

### Installation

1. Clone the repository:

   ```
   git clone <your-repo-url>
   cd Aniya
   ```

2. Install dependencies:

   ```
   flutter pub get
   ```

3. (Optional) Copy environment file:

   ```
   cp .env.example .env
   ```

   Edit `.env` with your API keys/services (e.g., for auth, tracking).

4. (Optional) Install extensions (CloudStream / LnReader / Aniya)

   - Download extension bundles via the in-app Extension screen.
   - CloudStream `.cs3/.zip` bundles are stored under `app_cloudstream_plugins/` and loaded via DexClassLoader—APK install is no longer required.
   - LnReader plugins are JavaScript blobs downloaded from JSON repos; no Android package manager access needed.
   - Aniya eval extensions are installed from script URLs or JSON manifests, typically via deep links (see “Deep Links” below).

### Running the App

- **Development**:

  ```
  flutter run
  ```

  Select device/platform.

- **Web**:

  ```
  flutter run -d chrome
  ```

- **Build for Release**:
  ```
  flutter build apk  # Android
  flutter build ios  # iOS (macOS required)
  flutter build web  # Web
  flutter build windows  # Windows
  ```

## 📁 Project Structure

```
lib/
├── core/              # Shared utilities, services, navigation, theme, DI
│   ├── constants/     # App constants
│   ├── data/          # Data sources, models, repositories
│   ├── di/            # Dependency injection (injection_container.dart)
│   ├── domain/        # Entities, repositories, usecases
│   ├── error/         # Exceptions, failures
│   ├── navigation/    # Adaptive nav, shell, transitions
│   ├── services/      # Platform managers (desktop, mobile, responsive)
│   └── utils/         # Helpers (image_cache_manager, etc.)
├── features/          # Modular features
│   ├── auth/
│   ├── home/
│   ├── library/
│   ├── manga_reader/
│   ├── search/
│   ├── settings/
│   └── video_player/
├── eval_extensions/    # Script-based Aniya eval extensions (dart_eval runtime)
└── main.dart          # App entrypoint
```

Key supporting modules:

- `deps/DartotsuExtensionBridge/` – Native/Dart bridge for CloudStream, LnReader, Aniyomi, Mangayomi plugins (included as a path dependency).

## 🧪 Testing

```
flutter test
```

## 🔗 Deep Links

Aniya supports installing extension repositories and Aniya eval extensions via deep links on mobile and desktop (as URI arguments).

### Repository links

These schemes create or update repository settings for the selected extension type:

- `aniyomi://add-repo?url={repo_url}`
- `tachiyomi://add-repo?url={repo_url}`
- `mangayomi://add-repo?url={anime_url}&manga_url={manga_url}&novel_url={novel_url}`
- `dar://add-repo?url={anime_url}&manga_url={manga_url}&novel_url={novel_url}`
- `cloudstreamrepo://{repo_url}`
- `https://cs.repo/?{repo_url}`

### Aniya eval extensions

Aniya eval extensions are plaintext Dart scripts executed in-app using `dart_eval`. Extensions expose a set of top-level functions (by name) that the host calls to search/browse, load details, and resolve pages/streams.

Aniya eval extensions can be installed from either a single source file URL or a JSON manifest that describes a group of plugins:

- `aniya://add-extension?url={https://example.com/plugin.dart}`  
  Installs a single Aniya extension from a plaintext Dart source code URL.
- `aniya://add-extension-manifest?url={https://example.com/manifest.json}`  
  Downloads a JSON manifest, resolves one or more plugin entries, fetches their source code, and installs each as an Aniya extension.

#### Host-provided helpers

The host can provide these helper functions as trailing arguments (you can accept only the ones you need):

- `httpGet(url, [headers])` → `Future<String>` response body
- `soupParse(html)` → `dynamic` (BeautifulSoup-like object; supports `find`, `findAll`, `text`, `toString`)
- `sha256Hex(input)` → `String`
- `soupFind(node, tag, [options])` → `dynamic` (element or `null`)
- `soupFindAll(node, tag, [options])` → `List<dynamic>`

Because `dart_eval` wraps values at runtime, prefer `dynamic` parameters and coerce types inside your plugin.

#### Supported functions

The host calls these functions by name. Implement every function your UI can reach (recommended: implement all):

- `search(query, page, filters, httpGet, soupParse, sha256Hex)` → `Pages`
- `getPopular(page, httpGet, soupParse, sha256Hex)` → `Pages`
- `getLatestUpdates(page, httpGet, soupParse, sha256Hex)` → `Pages`
- `getDetail(mediaJson, httpGet, soupParse, sha256Hex)` → `DMedia`
- `getPageList(episodeJson, httpGet, soupParse, sha256Hex)` → `List<PageUrl>`
- `getVideoList(episodeJson, httpGet, soupParse, sha256Hex)` → `List<Video>`
- `getNovelContent(chapterTitle, chapterId, httpGet, soupParse, sha256Hex)` → `String`
- `getPreference(httpGet, soupParse, sha256Hex)` → `List<SourcePreference>`
- `setPreference(prefJson, value, httpGet, soupParse, sha256Hex)` → `bool`

Return values can be either:

- JSON strings (recommended for compatibility), or
- direct `Map` / `List` objects.

#### Data shapes

The host decodes the following JSON shapes into its bridge models:

- `Pages`: `{ "list": [DMedia...], "hasNextPage": bool }`
- `DMedia`: `{ "title", "url", "cover", "description", "genre", "episodes" }`
- `DEpisode`: `{ "url", "name", "episodeNumber", ... }`
- `PageUrl`: `{ "url", "headers" }`
- `Video`: `{ "title", "url", "quality", "headers", "subtitles", "audios" }`
- `SourcePreference`: `{ "type", "key", "id", ...preferencePayload }`

#### Deep link metadata

For `aniya://add-extension`, you can optionally attach metadata as query parameters:

- `id`, `name`, `version`
- `lang` (or `language`)
- `type` (or `itemType`)

`type` values match the `ItemType` enum: `manga`, `anime`, `novel`, `movie`, `tvShow`, `cartoon`, `documentary`, `livestream`, `nsfw`.

Example:

- `aniya://add-extension?url={https://example.com/plugin.dart}&id=example&name=Example%20Source&version=0.1.0&lang=en&type=anime`

#### Example plugin source

The `url` should point to a plaintext file containing the plugin source code. Below is the same template that ships in `lib/eval_extensions/templates/sample_plugin.dart`.

```dart
import 'dart:convert';

String _asString(dynamic value) => value?.toString() ?? '';

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  return int.tryParse(_asString(value)) ?? fallback;
}

bool _asBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  final s = _asString(value).toLowerCase().trim();
  if (s == 'true' || s == '1' || s == 'yes') return true;
  if (s == 'false' || s == '0' || s == 'no') return false;
  return fallback;
}

List<dynamic> _asList(dynamic value) {
  if (value is List) return value;
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

Future<String> _httpGetText(
  Function httpGet,
  String url, {
  Map<String, String>? headers,
}) async {
  final res = headers == null ? httpGet(url) : httpGet(url, headers);
  final body = res is Future ? await res : res;
  return body.toString();
}

String _extractFirstHtmlTitle(String htmlOrSoup) {
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

Map<String, dynamic> _track({
  required String file,
  String? label,
}) {
  return {
    'file': file,
    'label': label,
  };
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
  return {
    'url': url,
    'headers': headers ?? <String, String>{},
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
  var filterCount = 0;
  for (final _ in _asList(filters)) {
    filterCount++;
  }

  if (queryStr == '__demo__') {
    try {
      final html = await _httpGetText(
        httpGet,
        'https://example.com/',
        headers: <String, String>{
          'User-Agent': 'AniyaEval/0.1',
          'Accept': 'text/html',
        },
      );

      final soup = soupParse(html);
      final titleEl = soup.find('title');
      final titleFromSoup = _asString(titleEl?.string).trim();
      final title =
          titleFromSoup.isNotEmpty ? titleFromSoup : _extractFirstHtmlTitle(html);
      final signature = sha256Hex('$title:$pageNum').toString();

      final items = <Map<String, dynamic>>[
        _media(
          title: title.isEmpty ? 'Example Domain' : title,
          url: 'https://example.com/#$signature',
          description: 'Demo result from httpGet + soupParse + sha256Hex.',
        ),
      ];

      return json.encode(_pages(items, hasNextPage: false));
    } catch (_) {}
  }

  final items = <Map<String, dynamic>>[
    _media(
      title: 'Search "$queryStr" (page $pageNum)',
      url: 'https://example.com/search/$pageNum?q=${Uri.encodeQueryComponent(queryStr)}',
      description: 'filters=$filterCount',
      author: 'Sample author',
      genre: <String>['Demo'],
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

  final headers = <String, String>{
    'Referer': epUrl,
  };

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

  final headers = <String, String>{
    'Referer': epUrl,
  };

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
  return true;
}
```

#### Example manifest

Manifests can be either:

- a JSON array of plugin objects, or
- a JSON object containing a `plugins` (or `extensions` / `items`) array.

Each plugin entry supports `id`, `name`, `url` (or `codeUrl` / `sourceUrl`), `version`, `lang` (or `language`), `type` (or `itemType`), and optionally inline `sourceCode` (or `code` / `source`).

```json
{
  "plugins": [
    {
      "id": "example_one",
      "name": "Example One",
      "version": "0.1.0",
      "lang": "en",
      "type": "anime",
      "url": "https://example.com/plugins/example_one.dart"
    },
    {
      "id": "example_inline",
      "name": "Example Inline",
      "version": "0.1.0",
      "language": "en",
      "itemType": "anime",
      "sourceCode": "import 'dart:convert';\n\nint _asInt(dynamic value, {int fallback = 0}) {\n  if (value is int) return value;\n  return int.tryParse(value?.toString() ?? '') ?? fallback;\n}\n\nString _asString(dynamic value) => value?.toString() ?? '';\n\ndynamic search(dynamic query, dynamic page, dynamic filters, Function httpGet, Function soupParse, Function sha256Hex) async {\n  final queryStr = _asString(query);\n  final pageNum = _asInt(page, fallback: 1);\n  final pages = {\n    'list': [\n      {\n        'title': 'Example: ' + queryStr,\n        'url': 'https://example.com/search/' + pageNum.toString(),\n        'cover': '',\n        'description': '',\n        'episodes': [],\n      }\n    ],\n    'hasNextPage': false\n  };\n  return json.encode(pages);\n}\n"
    }
  ]
}
```

On desktop (Windows/Linux), the same URIs can be passed as process arguments; the deep link service will detect and process them on startup.

## 🔧 Development Guides

Bridge docs (path dependency):

- [Extension Bridge README](deps/DartotsuExtensionBridge/README.md)
- [CloudStream Setup](deps/DartotsuExtensionBridge/CLOUDSTREAM_SETUP.md)
- [CloudStream Desktop](deps/DartotsuExtensionBridge/CLOUDSTREAM_DESKTOP.md)
- [Aniyomi Desktop](deps/DartotsuExtensionBridge/ANIYOMI_DESKTOP.md)

## 🔌 CloudStream / Extension Bridge Notes

For bridge internals, setup, and troubleshooting, use the docs in `deps/DartotsuExtensionBridge/` (linked above).

## 🤝 Contributing

1. Fork the project.
2. Create a feature branch (`git checkout -b feature/AmazingFeature`).
3. Commit changes (`git commit -m 'Add some AmazingFeature'`).
4. Push to branch (`git push origin feature/AmazingFeature`).
5. Open a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙌 Acknowledgments

- Flutter Team
- Open-source contributors

---
