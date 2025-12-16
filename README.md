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

Aniya eval extensions can be installed from either a single source file URL or a JSON manifest that describes a group of plugins:

- `aniya://add-extension?url={https://example.com/plugin.cs3}`  
  Installs a single Aniya extension from a plaintext source code URL.
- `aniya://add-extension-manifest?url={https://example.com/manifest.json}`  
  Downloads a JSON manifest, resolves one or more plugin entries, fetches their source code, and installs each as an Aniya extension.

#### Example plugin source

The `url` should point to a plaintext file containing the plugin source code.

```dart
import 'dart:convert';

// Functions passed from host:
// httpGet(url, [headers])
// soupParse(html)
// sha256Hex(input)

dynamic search(
  String query,
  int page,
  List<dynamic> filters,
  Function httpGet,
  Function soupParse,
  Function sha256Hex,
) async {
  final res = httpGet('https://example.com/search?q=$query');
  final html = res is Future ? await res : res.toString();
  final soup = soupParse(html).toString();

  final items = <Map<String, dynamic>>[
    {
      'title': 'Example: ' + query,
      'url': 'https://example.com/item/1',
      'cover': '',
      'description': '',
      'episodes': [],
    }
  ];

  final pages = {'list': items, 'hasNextPage': false};
  return json.encode(pages);
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
      "sourceCode": "import 'dart:convert';\n\ndynamic search(String query, int page, List<dynamic> filters, Function httpGet, Function soupParse, Function sha256Hex) async {\n  final pages = {'list': [], 'hasNextPage': false};\n  return json.encode(pages);\n}\n"
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
