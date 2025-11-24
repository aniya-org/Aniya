import 'dart:io';
import 'package:flutter/foundation.dart';

/// Utility class for platform-specific operations
class PlatformUtils {
  /// Check if running on desktop platform
  static bool get isDesktop {
    return !kIsWeb &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
  }

  /// Check if running on mobile platform
  static bool get isMobile {
    return !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  }

  /// Check if running on Windows
  static bool get isWindows {
    return !kIsWeb && Platform.isWindows;
  }

  /// Check if running on macOS
  static bool get isMacOS {
    return !kIsWeb && Platform.isMacOS;
  }

  /// Check if running on Linux
  static bool get isLinux {
    return !kIsWeb && Platform.isLinux;
  }

  /// Check if running on Android
  static bool get isAndroid {
    return !kIsWeb && Platform.isAndroid;
  }

  /// Check if running on iOS
  static bool get isIOS {
    return !kIsWeb && Platform.isIOS;
  }

  /// Check if running on web
  static bool get isWeb {
    return kIsWeb;
  }
}
