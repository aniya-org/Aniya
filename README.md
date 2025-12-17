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
- **Architecture**: Clean Architecture / Domain-Driven Design
- **State Management**: Provider / Riverpod via DI container
- **Networking**: Dio / HTTP (inferred from data layers)
- **Caching**: Custom image cache manager
- **Platform Services**: Responsive layout, desktop window utils, mobile integrations
- **Extension Systems**: `dartotsu_extension_bridge` (CloudStream DexClassLoader loader, LnReader QuickJS runtime) plus an in-app Aniya eval runtime for script-based extensions.

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
└── main.dart          # App entrypoint
```

Key supporting modules:

- `ref/DartotsuExtensionBridge/` – Native/Dart bridge for CloudStream, LnReader, Aniyomi, Mangayomi plugins. Includes the rewritten CloudStream loader, extractor service, AppCompat shims, and sync-provider stubs.
- `ref/cloudstream/` – Upstream CloudStream reference sources used for shims and manifests.

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

Aniya eval extensions are Dart scripts executed in-app using `dart_eval`. Extensions expose a set of top-level functions (by name) that the host calls to search/browse, load details, and resolve pages/streams.

Aniya eval extensions can be installed from either a single source file URL or a JSON manifest that describes a group of plugins:

- `aniya://add-extension?url={https://example.com/plugin.cs3}`  
  Installs a single Aniya extension from a plaintext source code URL.
- `aniya://add-extension-manifest?url={https://example.com/manifest.json}`  
  Downloads a JSON manifest, resolves one or more plugin entries, fetches their source code, and installs each as an Aniya extension.

#### Host-provided helpers

Every function receives 3 helper functions as the final arguments:

- `httpGet(url, [headers])` → `Future<String>` response body
- `soupParse(html)` → `String` (normalized HTML; currently stringified BeautifulSoup)
- `sha256Hex(input)` → `String`

#### Supported functions

The host calls these functions by name if they exist in the plugin source:

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

- `aniya://add-extension?url={https://example.com/plugin.cs3}&id=example&name=Example%20Source&version=0.1.0&lang=en&type=anime`

#### Example plugin source

The `url` should point to a plaintext file containing the plugin source code. Below is the same template that ships in `lib/eval_extensions/templates/sample_plugin.dart`.

```dart
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
      "url": "https://example.com/plugins/example_one.cs3"
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

See `lib/core/` docs:

- [ANIMATIONS_GUIDE.md](lib/core/ANIMATIONS_GUIDE.md)
- [QUICK_ANIMATION_REFERENCE.md](lib/core/QUICK_ANIMATION_REFERENCE.md)
- [UI_COMPONENTS_SUMMARY.md](lib/core/UI_COMPONENTS_SUMMARY.md)
- [SETUP_SUMMARY.md](lib/core/SETUP_SUMMARY.md)
- [Extension Bridge README](ref/DartotsuExtensionBridge/README.md) – Architecture, plugin APIs, and bridge-specific troubleshooting.

## 🔌 CloudStream / Extension Bridge Notes

- **Plugin Loading**: CloudStream plugins are instantiated as `Plugin` subclasses (not `MainAPI`), mirroring upstream PluginManager.
- **AppCompatActivity Requirement**: Plugins that expect an `AppCompatActivity` (e.g., SuperStream Beta) are run on the Android main thread with a headless activity fallback to avoid `ClassCastException`/`Looper.prepare()` errors.
- **Sync Provider Shims**: Local Kotlin stubs expose `AccountManager.getSimklApi()` and related sync APIs so CineStream and similar plugins can initialize.
- **Extractor Service**: CloudStream extractors are exposed through `ExtractorService` and used automatically when playback sources aren’t direct links.
- **URL Sanitization**: JSON payloads are encoded as `csjson://<base64>` in Flutter to keep media_kit happy; the native bridge automatically decodes before calling plugins or extractors.

### Current Limitations / Tips

1. **StremioX / CineStream**: If the extractor can’t produce a direct link, playback falls back to the bridge’s embed URL (still sanitized). Some sources may still require manual server selection inside the plugin UI.
2. **Plugin Storage**: Clear `/app_cloudstream_plugins` if you suspect a corrupted bundle—plugins are re-initialized on next launch.
3. **LnReader JS Errors**: Logs are surfaced through `ExtensionSearchRepository`; enable verbose logging when developing new JS plugins.
4. **Testing CloudStream**: Use `initializePlugins()` after installing new bundles to load them before issuing search/getDetail requests.

For a deeper dive into the bridge internals, extractor usage, or adding new extension systems, see [`ref/DartotsuExtensionBridge/README.md`](ref/DartotsuExtensionBridge/README.md).

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
