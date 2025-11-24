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

## 🛠 Tech Stack

- **Framework**: Flutter (Dart)
- **Architecture**: Clean Architecture / Domain-Driven Design
- **State Management**: Provider / Riverpod via DI container
- **Networking**: Dio / HTTP (inferred from data layers)
- **Caching**: Custom image cache manager
- **Platform Services**: Responsive layout, desktop window utils, mobile integrations

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

## 🧪 Testing

```
flutter test
```

## 🔧 Development Guides

See `lib/core/` docs:

- [ANIMATIONS_GUIDE.md](lib/core/ANIMATIONS_GUIDE.md)
- [QUICK_ANIMATION_REFERENCE.md](lib/core/QUICK_ANIMATION_REFERENCE.md)
- [UI_COMPONENTS_SUMMARY.md](lib/core/UI_COMPONENTS_SUMMARY.md)
- [SETUP_SUMMARY.md](lib/core/SETUP_SUMMARY.md)

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
