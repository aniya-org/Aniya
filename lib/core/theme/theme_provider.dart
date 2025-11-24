import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'app_theme.dart';

/// Provider for managing application theme state
class ThemeProvider extends ChangeNotifier {
  AppThemeMode _themeMode;
  ColorScheme? _lightDynamicColorScheme;
  ColorScheme? _darkDynamicColorScheme;

  ThemeProvider({AppThemeMode initialThemeMode = AppThemeMode.system})
    : _themeMode = initialThemeMode;

  /// Current theme mode
  AppThemeMode get themeMode => _themeMode;

  /// Whether dynamic color is available
  bool get hasDynamicColor =>
      _lightDynamicColorScheme != null && _darkDynamicColorScheme != null;

  /// Get the current light theme
  ThemeData get lightTheme {
    if (hasDynamicColor) {
      return AppTheme.buildDynamicTheme(
        lightColorScheme: _lightDynamicColorScheme,
        darkColorScheme: _darkDynamicColorScheme,
        themeMode: AppThemeMode.light,
      );
    }
    return AppTheme.lightTheme;
  }

  /// Get the current dark theme
  ThemeData get darkTheme {
    if (hasDynamicColor && _themeMode != AppThemeMode.oled) {
      return AppTheme.buildDynamicTheme(
        lightColorScheme: _lightDynamicColorScheme,
        darkColorScheme: _darkDynamicColorScheme,
        themeMode: AppThemeMode.dark,
      );
    }
    return _themeMode == AppThemeMode.oled
        ? AppTheme.oledTheme
        : AppTheme.darkTheme;
  }

  /// Get ThemeMode for MaterialApp
  ThemeMode get materialThemeMode {
    return AppTheme.getThemeMode(_themeMode);
  }

  /// Check if current theme is dark
  bool get isDarkMode {
    if (_themeMode == AppThemeMode.system) {
      final brightness =
          SchedulerBinding.instance.platformDispatcher.platformBrightness;
      return brightness == Brightness.dark;
    }
    return _themeMode == AppThemeMode.dark || _themeMode == AppThemeMode.oled;
  }

  /// Check if current theme is OLED mode
  bool get isOledMode => _themeMode == AppThemeMode.oled;

  /// Set theme mode
  void setThemeMode(AppThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      notifyListeners();
    }
  }

  /// Set dynamic color schemes
  void setDynamicColorSchemes({ColorScheme? light, ColorScheme? dark}) {
    _lightDynamicColorScheme = light;
    _darkDynamicColorScheme = dark;
    notifyListeners();
  }

  /// Toggle between light and dark mode
  void toggleTheme() {
    if (_themeMode == AppThemeMode.light) {
      setThemeMode(AppThemeMode.dark);
    } else if (_themeMode == AppThemeMode.dark) {
      setThemeMode(AppThemeMode.oled);
    } else if (_themeMode == AppThemeMode.oled) {
      setThemeMode(AppThemeMode.light);
    } else {
      // System mode - toggle to light
      setThemeMode(AppThemeMode.light);
    }
  }
}
