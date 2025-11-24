import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Application-wide constants
class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'Aniya';
  static const String appVersion = '1.0.0';

  // Storage Keys
  static const String themeKey = 'theme_mode';
  static const String languageKey = 'language';
  static const String videoQualityKey = 'video_quality';
  static const String autoPlayKey = 'auto_play';

  // API Configuration
  static String get tmdbApiKey =>
      dotenv.env['TMDB_API_KEY'] ?? 'fb7bb23f03b6994dafc674c074d01761';
  static const String tmdbBaseUrl = 'https://api.themoviedb.org/3';

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 50;

  // Performance
  static const int searchDebounceMs = 500;
  static const int transitionDurationMs = 300;
  static const int imageCacheDurationDays = 7;

  // Download
  static const int maxConcurrentDownloads = 3;
  static const int downloadChunkSize = 1024 * 1024; // 1MB
}
