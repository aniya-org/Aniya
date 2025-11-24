import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aniya/core/utils/platform_utils.dart';

/// Service for managing mobile platform-specific features
class MobilePlatformManager {
  static const platform = MethodChannel('com.aniya.app/platform');
  static Brightness _currentBrightness = Brightness.light;

  /// Initialize mobile platform features
  static Future<void> initializeMobileFeatures() async {
    if (!PlatformUtils.isMobile) return;

    await _configureStatusBar();
    await _configureNavigationBar();
    await _configureOrientationHandling();
  }

  /// Configure status bar styling with theme awareness
  static Future<void> _configureStatusBar() async {
    if (!PlatformUtils.isMobile) return;

    try {
      // Set status bar color to transparent for immersive experience
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarBrightness: _currentBrightness,
          statusBarIconBrightness: _currentBrightness == Brightness.light
              ? Brightness.dark
              : Brightness.light,
        ),
      );
    } catch (e) {
      // Silently fail if not supported
    }
  }

  /// Configure navigation bar styling with theme awareness
  static Future<void> _configureNavigationBar() async {
    if (!PlatformUtils.isAndroid) return;

    try {
      // Configure Android navigation bar with transparent background
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness:
              _currentBrightness == Brightness.light
              ? Brightness.dark
              : Brightness.light,
          systemNavigationBarDividerColor: Colors.transparent,
        ),
      );
    } catch (e) {
      // Silently fail if not supported
    }
  }

  /// Configure orientation handling
  static Future<void> _configureOrientationHandling() async {
    if (!PlatformUtils.isMobile) return;

    try {
      // Allow both portrait and landscape orientations
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } catch (e) {
      // Silently fail if not supported
    }
  }

  /// Update system UI overlay style based on theme brightness
  static Future<void> updateSystemUIForTheme(Brightness brightness) async {
    if (!PlatformUtils.isMobile) return;

    _currentBrightness = brightness;

    try {
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarBrightness: brightness,
          statusBarIconBrightness: brightness == Brightness.light
              ? Brightness.dark
              : Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: brightness == Brightness.light
              ? Brightness.dark
              : Brightness.light,
          systemNavigationBarDividerColor: Colors.transparent,
        ),
      );
    } catch (e) {
      // Silently fail if not supported
    }
  }

  /// Lock orientation to portrait
  static Future<void> lockPortraitOrientation() async {
    if (!PlatformUtils.isMobile) return;

    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } catch (e) {
      // Silently fail if not supported
    }
  }

  /// Lock orientation to landscape
  static Future<void> lockLandscapeOrientation() async {
    if (!PlatformUtils.isMobile) return;

    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } catch (e) {
      // Silently fail if not supported
    }
  }

  /// Unlock all orientations
  static Future<void> unlockOrientation() async {
    if (!PlatformUtils.isMobile) return;

    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } catch (e) {
      // Silently fail if not supported
    }
  }

  /// Get current device orientation
  static Future<DeviceOrientation?> getCurrentOrientation() async {
    if (!PlatformUtils.isMobile) return null;

    try {
      final result = await platform.invokeMethod<String>('getOrientation');
      return _parseOrientation(result);
    } catch (e) {
      return null;
    }
  }

  /// Parse orientation string to DeviceOrientation
  static DeviceOrientation? _parseOrientation(String? orientation) {
    switch (orientation) {
      case 'portrait':
        return DeviceOrientation.portraitUp;
      case 'landscape':
        return DeviceOrientation.landscapeLeft;
      default:
        return null;
    }
  }

  /// Hide status bar
  static Future<void> hideStatusBar() async {
    if (!PlatformUtils.isMobile) return;

    try {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    } catch (e) {
      // Silently fail if not supported
    }
  }

  /// Show status bar
  static Future<void> showStatusBar() async {
    if (!PlatformUtils.isMobile) return;

    try {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    } catch (e) {
      // Silently fail if not supported
    }
  }
}
