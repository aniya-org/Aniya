import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/theme/theme.dart';

import '../../../../core/enums/tracking_service.dart';
import '../../../../core/services/tracking_auth_service.dart';

/// Enum for video quality preferences
enum VideoQuality { auto, p360, p480, p720, p1080 }

class SettingsViewModel extends ChangeNotifier {
  final TrackingAuthService _authService;
  final Box _settingsBox;

  SettingsViewModel(this._authService, this._settingsBox);

  // Theme settings
  AppThemeMode _themeMode = AppThemeMode.system;

  // Video settings
  VideoQuality _defaultVideoQuality = VideoQuality.auto;
  bool _autoPlayNextEpisode = true;

  // Extension settings
  bool _showNsfwExtensions = false;

  // Tracking service settings
  Set<TrackingService> _connectedTrackingServices = {};

  // Error state
  String? _error;

  // Getters
  AppThemeMode get themeMode => _themeMode;
  VideoQuality get defaultVideoQuality => _defaultVideoQuality;
  bool get autoPlayNextEpisode => _autoPlayNextEpisode;
  bool get showNsfwExtensions => _showNsfwExtensions;
  Set<TrackingService> get connectedTrackingServices =>
      _connectedTrackingServices;
  String? get error => _error;

  /// Load settings from local storage
  Future<void> loadSettings() async {
    try {
      // Load Theme
      final themeIndex = _settingsBox.get(
        'theme_mode',
        defaultValue: AppThemeMode.system.index,
      );
      _themeMode = AppThemeMode.values[themeIndex];

      // Load Video Quality
      final qualityIndex = _settingsBox.get(
        'video_quality',
        defaultValue: VideoQuality.auto.index,
      );
      _defaultVideoQuality = VideoQuality.values[qualityIndex];

      // Load other settings
      _autoPlayNextEpisode = _settingsBox.get('auto_play', defaultValue: true);
      _showNsfwExtensions = _settingsBox.get('show_nsfw', defaultValue: false);

      // Check authentication status for tracking services
      // This is still needed as auth tokens are stored securely separate from preferences
      for (final service in TrackingService.values) {
        if (await _authService.isAuthenticated(service)) {
          _connectedTrackingServices.add(service);
        }
      }

      _error = null;
      notifyListeners();
    } catch (e, stackTrace) {
      _error = 'Failed to load settings. Using defaults.';
      Logger.error(
        'Error loading settings',
        tag: 'SettingsViewModel',
        error: e,
        stackTrace: stackTrace,
      );
      notifyListeners();
    }
  }

  /// Set theme mode
  Future<void> setThemeMode(AppThemeMode mode) async {
    try {
      _themeMode = mode;
      _error = null;
      notifyListeners();

      await _saveSettings();
    } catch (e, stackTrace) {
      _error = 'Failed to save theme setting. Please try again.';
      Logger.error(
        'Error saving theme mode',
        tag: 'SettingsViewModel',
        error: e,
        stackTrace: stackTrace,
      );
      notifyListeners();
    }
  }

  /// Set default video quality
  Future<void> setDefaultVideoQuality(VideoQuality quality) async {
    try {
      _defaultVideoQuality = quality;
      _error = null;
      notifyListeners();

      await _saveSettings();
    } catch (e, stackTrace) {
      _error = 'Failed to save video quality setting. Please try again.';
      Logger.error(
        'Error saving video quality',
        tag: 'SettingsViewModel',
        error: e,
        stackTrace: stackTrace,
      );
      notifyListeners();
    }
  }

  /// Toggle auto-play next episode
  Future<void> setAutoPlayNextEpisode(bool enabled) async {
    try {
      _autoPlayNextEpisode = enabled;
      _error = null;
      notifyListeners();

      await _saveSettings();
    } catch (e, stackTrace) {
      _error = 'Failed to save auto-play setting. Please try again.';
      Logger.error(
        'Error saving auto-play setting',
        tag: 'SettingsViewModel',
        error: e,
        stackTrace: stackTrace,
      );
      notifyListeners();
    }
  }

  /// Toggle NSFW extensions visibility
  Future<void> setShowNsfwExtensions(bool show) async {
    try {
      _showNsfwExtensions = show;
      _error = null;
      notifyListeners();

      await _saveSettings();
    } catch (e, stackTrace) {
      _error = 'Failed to save NSFW setting. Please try again.';
      Logger.error(
        'Error saving NSFW setting',
        tag: 'SettingsViewModel',
        error: e,
        stackTrace: stackTrace,
      );
      notifyListeners();
    }
  }

  /// Connect a tracking service
  Future<void> connectTrackingService(TrackingService service) async {
    try {
      final success = await _authService.authenticate(service);
      if (success) {
        _connectedTrackingServices.add(service);
        _error = null;
        notifyListeners();
        // No need to save connected services to Hive as they are derived from auth status
      } else {
        _error = 'Failed to connect to ${service.name}';
        notifyListeners();
      }
    } catch (e, stackTrace) {
      _error = 'Failed to connect tracking service. Please try again.';
      Logger.error(
        'Error connecting tracking service',
        tag: 'SettingsViewModel',
        error: e,
        stackTrace: stackTrace,
      );
      notifyListeners();
    }
  }

  /// Disconnect a tracking service
  Future<void> disconnectTrackingService(TrackingService service) async {
    try {
      await _authService.logout(service);
      _connectedTrackingServices.remove(service);
      _error = null;
      notifyListeners();
      // No need to save connected services to Hive as they are derived from auth status
    } catch (e, stackTrace) {
      _error = 'Failed to disconnect tracking service. Please try again.';
      Logger.error(
        'Error disconnecting tracking service',
        tag: 'SettingsViewModel',
        error: e,
        stackTrace: stackTrace,
      );
      notifyListeners();
    }
  }

  /// Check if a tracking service is connected
  bool isTrackingServiceConnected(TrackingService service) {
    return _connectedTrackingServices.contains(service);
  }

  /// Get Material ThemeMode from AppThemeMode
  ThemeMode getMaterialThemeMode() {
    switch (_themeMode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
      case AppThemeMode.oled:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  /// Private method to save settings to storage
  Future<void> _saveSettings() async {
    await _settingsBox.put('theme_mode', _themeMode.index);
    await _settingsBox.put('video_quality', _defaultVideoQuality.index);
    await _settingsBox.put('auto_play', _autoPlayNextEpisode);
    await _settingsBox.put('show_nsfw', _showNsfwExtensions);
  }
}
