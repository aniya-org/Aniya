import 'package:flutter/foundation.dart';

/// Simple logger utility for the application
class Logger {
  Logger._();

  static void log(String message, {String? tag}) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toIso8601String();
      final tagPrefix = tag != null ? '[$tag] ' : '';
      debugPrint('[$timestamp] $tagPrefix$message');
    }
  }

  static void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toIso8601String();
      final tagPrefix = tag != null ? '[$tag] ' : '';
      debugPrint('[$timestamp] ERROR $tagPrefix$message');
      if (error != null) {
        debugPrint('Error: $error');
      }
      if (stackTrace != null) {
        debugPrint('StackTrace: $stackTrace');
      }
    }
  }

  static void warning(String message, {String? tag}) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toIso8601String();
      final tagPrefix = tag != null ? '[$tag] ' : '';
      debugPrint('[$timestamp] WARNING $tagPrefix$message');
    }
  }

  static void info(String message, {String? tag}) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toIso8601String();
      final tagPrefix = tag != null ? '[$tag] ' : '';
      debugPrint('[$timestamp] INFO $tagPrefix$message');
    }
  }

  static void debug(String message, {String? tag}) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toIso8601String();
      final tagPrefix = tag != null ? '[$tag] ' : '';
      debugPrint('[$timestamp] DEBUG $tagPrefix$message');
    }
  }
}
