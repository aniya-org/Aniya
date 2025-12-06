import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/provider_cache.dart';

import '../../../../core/enums/tracking_service.dart';
import '../../../../core/services/tracking_auth_service.dart';

/// Enum for video quality preferences
enum VideoQuality { auto, p360, p480, p720, p1080 }

class SettingsViewModel extends ChangeNotifier {
  final TrackingAuthService _authService;
  final Box _settingsBox;
  final ProviderCache _providerCache;

  SettingsViewModel(this._authService, this._settingsBox, this._providerCache) {
    _setupAuthListeners();
  }

  /// Setup listeners for auth state changes
  void _setupAuthListeners() {
    // Since we can't directly listen to GetX controllers from outside,
    // we'll rely on the sync method being called when needed
    // This could be enhanced in the future with a more reactive approach
  }

  // Theme settings
  AppThemeMode _themeMode = AppThemeMode.system;

  // Video settings
  VideoQuality _defaultVideoQuality = VideoQuality.auto;
  bool _autoPlayNextEpisode = true;

  // Extension settings
  bool _showNsfwExtensions = false;

  // Tracking service settings
  final Set<TrackingService> _connectedTrackingServices = {};
  final Map<TrackingService, String> _trackingUsernames = {};
  final Map<TrackingService, bool> _trackingAutoSync = {};

  // Error state
  String? _error;

  // Cache statistics
  int _cacheSize = 0;
  int _cacheEntryCount = 0;
  bool _isLoadingCacheStats = false;

  // Getters
  AppThemeMode get themeMode => _themeMode;
  VideoQuality get defaultVideoQuality => _defaultVideoQuality;
  bool get autoPlayNextEpisode => _autoPlayNextEpisode;
  bool get showNsfwExtensions => _showNsfwExtensions;
  Set<TrackingService> get connectedTrackingServices =>
      _connectedTrackingServices;
  Map<TrackingService, String> get trackingUsernames => _trackingUsernames;
  Map<TrackingService, bool> get trackingAutoSync => _trackingAutoSync;
  String? get error => _error;
  int get cacheSize => _cacheSize;
  int get cacheEntryCount => _cacheEntryCount;
  bool get isLoadingCacheStats => _isLoadingCacheStats;

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

      // Load tracking service preferences from storage
      final connectedServices = _settingsBox.get(
        'connected_tracking_services',
        defaultValue: <String>[],
      );
      final trackingUsernamesData = _settingsBox.get(
        'tracking_usernames',
        defaultValue: <String, String>{},
      );
      final trackingAutoSyncData = _settingsBox.get(
        'tracking_auto_sync',
        defaultValue: <String, bool>{},
      );

      // Convert stored data back to enums/maps
      _connectedTrackingServices.clear();
      for (final serviceName in connectedServices) {
        try {
          final service = TrackingService.values.firstWhere(
            (s) => s.name == serviceName,
          );
          _connectedTrackingServices.add(service);
        } catch (e) {
          Logger.warning(
            'Unknown tracking service in stored data: $serviceName',
          );
        }
      }

      _trackingUsernames.clear();
      trackingUsernamesData.forEach((serviceName, username) {
        try {
          final service = TrackingService.values.firstWhere(
            (s) => s.name == serviceName,
          );
          _trackingUsernames[service] = username;
        } catch (e) {
          Logger.warning(
            'Unknown tracking service in username data: $serviceName',
          );
        }
      });

      _trackingAutoSync.clear();
      trackingAutoSyncData.forEach((serviceName, autoSync) {
        try {
          final service = TrackingService.values.firstWhere(
            (s) => s.name == serviceName,
          );
          _trackingAutoSync[service] = autoSync;
        } catch (e) {
          Logger.warning(
            'Unknown tracking service in auto-sync data: $serviceName',
          );
        }
      });

      // Sync with actual authentication status
      await _syncTrackingAuthStatus();

      // Load cache statistics
      await loadCacheStatistics();

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

  /// Sync tracking service auth status with stored preferences
  Future<void> _syncTrackingAuthStatus() async {
    final actuallyConnected = <TrackingService>{};
    final usernames = <TrackingService, String>{};

    // Check actual authentication status
    for (final service in TrackingService.values) {
      if (await _authService.isAuthenticated(service)) {
        actuallyConnected.add(service);
        final username = await _authService.getUsername(service);
        if (username != null) {
          usernames[service] = username;
        }
      }
    }

    // Update stored preferences to match actual auth status
    _connectedTrackingServices.clear();
    _connectedTrackingServices.addAll(actuallyConnected);

    _trackingUsernames.clear();
    _trackingUsernames.addAll(usernames);

    // Initialize auto-sync settings for newly connected services
    for (final service in actuallyConnected) {
      if (!_trackingAutoSync.containsKey(service)) {
        _trackingAutoSync[service] = true; // Default to enabled
      }
    }

    // Save updated preferences
    await _saveTrackingSettings();
  }

  /// Load cache statistics
  Future<void> loadCacheStatistics() async {
    try {
      _isLoadingCacheStats = true;
      notifyListeners();

      _cacheSize = await _providerCache.getCacheSize();
      _cacheEntryCount = await _providerCache.getEntryCount();

      _isLoadingCacheStats = false;
      notifyListeners();
    } catch (e, stackTrace) {
      _isLoadingCacheStats = false;
      Logger.error(
        'Error loading cache statistics',
        tag: 'SettingsViewModel',
        error: e,
        stackTrace: stackTrace,
      );
      notifyListeners();
    }
  }

  /// Clear provider cache
  Future<void> clearProviderCache() async {
    try {
      await _providerCache.clearAll();
      await loadCacheStatistics();
      _error = null;
      notifyListeners();
    } catch (e, stackTrace) {
      _error = 'Failed to clear cache. Please try again.';
      Logger.error(
        'Error clearing cache',
        tag: 'SettingsViewModel',
        error: e,
        stackTrace: stackTrace,
      );
      notifyListeners();
    }
  }

  /// Format cache size for display
  String getFormattedCacheSize() {
    if (_cacheSize < 1024) {
      return '$_cacheSize B';
    } else if (_cacheSize < 1024 * 1024) {
      return '${(_cacheSize / 1024).toStringAsFixed(2)} KB';
    } else {
      return '${(_cacheSize / (1024 * 1024)).toStringAsFixed(2)} MB';
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

        // Get and store username
        final username = await _authService.getUsername(service);
        if (username != null) {
          _trackingUsernames[service] = username;
        }

        // Initialize auto-sync setting
        if (!_trackingAutoSync.containsKey(service)) {
          _trackingAutoSync[service] = true;
        }

        _error = null;
        await _saveTrackingSettings();
        notifyListeners();
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
      _trackingUsernames.remove(service);
      // Keep auto-sync preference for potential future reconnection
      _error = null;
      await _saveTrackingSettings();
      notifyListeners();
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

  /// Sync tracking auth status with current authentication state
  Future<void> syncTrackingAuthStatus() async {
    await _syncTrackingAuthStatus();
    notifyListeners();
  }

  /// Check if a tracking service is connected
  bool isTrackingServiceConnected(TrackingService service) {
    return _connectedTrackingServices.contains(service);
  }

  /// Get username for a connected tracking service
  String? getTrackingUsername(TrackingService service) {
    return _trackingUsernames[service];
  }

  /// Get auto-sync setting for a tracking service
  bool getTrackingAutoSync(TrackingService service) {
    return _trackingAutoSync[service] ?? true;
  }

  /// Set auto-sync setting for a tracking service
  Future<void> setTrackingAutoSync(
    TrackingService service,
    bool enabled,
  ) async {
    try {
      _trackingAutoSync[service] = enabled;
      await _saveTrackingSettings();
      _error = null;
      notifyListeners();
    } catch (e, stackTrace) {
      _error = 'Failed to save auto-sync setting. Please try again.';
      Logger.error(
        'Error saving auto-sync setting',
        tag: 'SettingsViewModel',
        error: e,
        stackTrace: stackTrace,
      );
      notifyListeners();
    }
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

  /// Save tracking service settings to storage
  Future<void> _saveTrackingSettings() async {
    await _settingsBox.put(
      'connected_tracking_services',
      _connectedTrackingServices.map((s) => s.name).toList(),
    );
    await _settingsBox.put(
      'tracking_usernames',
      _trackingUsernames.map((k, v) => MapEntry(k.name, v)),
    );
    await _settingsBox.put(
      'tracking_auto_sync',
      _trackingAutoSync.map((k, v) => MapEntry(k.name, v)),
    );
  }

  /// Private method to save settings to storage
  Future<void> _saveSettings() async {
    await _settingsBox.put('theme_mode', _themeMode.index);
    await _settingsBox.put('video_quality', _defaultVideoQuality.index);
    await _settingsBox.put('auto_play', _autoPlayNextEpisode);
    await _settingsBox.put('show_nsfw', _showNsfwExtensions);
    await _saveTrackingSettings();
  }
}
