import 'package:get/get.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';
import '../../../../core/utils/logger.dart';
import 'tracking_service_interface.dart';
import '../../../../core/domain/entities/entities.dart';
import 'anilist_tracking_service.dart';
import 'mal_tracking_service.dart';
import 'simkl_tracking_service.dart';
import '../../../../core/enums/tracking_service.dart';

/// Centralized authentication state manager
/// Manages authentication state across all tracking services
/// Provides a single source of truth for auth status
class AuthStateManager extends GetxController {
  late final Box _storage;

  // Tracking service instances
  late final AniListTrackingService _anilistService;
  late final MyAnimeListTrackingService _malService;
  late final SimklTrackingService _simklService;

  // Auth state observables
  RxMap<TrackingService, bool> isServiceConnected = <TrackingService, bool>{}.obs;
  RxMap<TrackingService, TrackingUserProfile?> userProfiles = <TrackingService, TrackingUserProfile?>{}.obs;
  RxMap<TrackingService, String?> usernames = <TrackingService, String?>{}.obs;
  RxMap<TrackingService, bool> autoSyncEnabled = <TrackingService, bool>{}.obs;

  AuthStateManager() {
    // Get the auth box from service locator (opened during DI initialization)
    final getIt = GetIt.instance;
    if (getIt.isRegistered<Box>(instanceName: 'authBox')) {
      _storage = getIt<Box>(instanceName: 'authBox');
    } else {
      throw Exception(
        'Auth box not initialized. Make sure Hive boxes are opened before instantiating AuthStateManager.',
      );
    }

    _initializeServices();
  }

  void _initializeServices() {
    // Initialize tracking services
    _anilistService = AniListTrackingService();
    _malService = MyAnimeListTrackingService();
    _simklService = SimklTrackingService();

    // Initialize auth state observables
    for (final service in TrackingService.values) {
      if (service != TrackingService.jikan && service != TrackingService.local) {
        isServiceConnected[service] = false;
        userProfiles[service] = null;
        usernames[service] = null;
        autoSyncEnabled[service] = false;
      }
    }

    // Try to auto-login
    tryAutoLogin();
  }

  /// Initialize all services and attempt auto-login
  Future<void> tryAutoLogin() async {
    try {
      await Future.wait([
        _anilistService.initialize(),
        _malService.initialize(),
        _simklService.initialize(),
      ]);

      // Update auth states
      _updateAuthStates();
      Logger.info('Auth state manager initialized successfully');
    } catch (e) {
      Logger.error('Failed to initialize auth state manager', error: e);
    }
  }

  /// Update authentication states from all services
  void _updateAuthStates() {
    isServiceConnected[TrackingService.anilist] = _anilistService.isAuthenticated;
    isServiceConnected[TrackingService.mal] = _malService.isAuthenticated;
    isServiceConnected[TrackingService.simkl] = _simklService.isAuthenticated;

    // Update user profiles
    _updateUserProfiles();
  }

  /// Update user profiles from all services
  Future<void> _updateUserProfiles() async {
    try {
      final profiles = await Future.wait([
        _anilistService.getUserProfile(),
        _malService.getUserProfile(),
        _simklService.getUserProfile(),
      ]);

      userProfiles[TrackingService.anilist] = profiles[0];
      userProfiles[TrackingService.mal] = profiles[1];
      userProfiles[TrackingService.simkl] = profiles[2];

      // Update usernames
      usernames[TrackingService.anilist] = profiles[0]?.username;
      usernames[TrackingService.mal] = profiles[1]?.username;
      usernames[TrackingService.simkl] = profiles[2]?.username;
    } catch (e) {
      Logger.error('Failed to update user profiles', error: e);
    }
  }

  /// Connect to a tracking service
  Future<bool> connectService(TrackingService service) async {
    try {
      bool success = false;

      switch (service) {
        case TrackingService.anilist:
          success = await _anilistService.authenticate();
          break;
        case TrackingService.mal:
          success = await _malService.authenticate();
          break;
        case TrackingService.simkl:
          success = await _simklService.authenticate();
          break;
        default:
          return false;
      }

      if (success) {
        _updateAuthStates();
        // Load auto-sync setting
        await _loadAutoSyncSetting(service);
        Logger.info('Successfully connected to ${service.name}');
      }

      return success;
    } catch (e) {
      Logger.error('Failed to connect to ${service.name}', error: e);
      return false;
    }
  }

  /// Disconnect from a tracking service
  Future<void> disconnectService(TrackingService service) async {
    try {
      switch (service) {
        case TrackingService.anilist:
          await _anilistService.logout();
          break;
        case TrackingService.mal:
          await _malService.logout();
          break;
        case TrackingService.simkl:
          await _simklService.logout();
          break;
        default:
          return;
      }

      _updateAuthStates();
      Logger.info('Disconnected from ${service.name}');
    } catch (e) {
      Logger.error('Failed to disconnect from ${service.name}', error: e);
    }
  }

  /// Get authentication status for a service
  bool isConnected(TrackingService service) {
    return isServiceConnected[service] ?? false;
  }

  /// Get username for a service
  String? getUsername(TrackingService service) {
    return usernames[service];
  }

  /// Get user profile for a service
  TrackingUserProfile? getUserProfile(TrackingService service) {
    return userProfiles[service];
  }

  /// Get auto-sync status for a service
  bool getAutoSync(TrackingService service) {
    return autoSyncEnabled[service] ?? false;
  }

  /// Set auto-sync status for a service
  Future<void> setAutoSync(TrackingService service, bool value) async {
    autoSyncEnabled[service] = value;
    await _storage.put('auto_sync_${service.name}', value);
  }

  /// Load auto-sync settings from storage
  Future<void> _loadAutoSyncSetting(TrackingService service) async {
    final value = await _storage.get('auto_sync_${service.name}');
    if (value != null) {
      autoSyncEnabled[service] = value;
    }
  }

  /// Refresh authentication status for all services
  Future<void> refreshAuthStatus() async {
    await _updateUserProfiles();
  }

  /// Get tracking service instance
  TrackingServiceInterface? getService(TrackingService service) {
    switch (service) {
      case TrackingService.anilist:
        return _anilistService;
      case TrackingService.mal:
        return _malService;
      case TrackingService.simkl:
        return _simklService;
      default:
        return null;
    }
  }

  /// Get all available tracking services
  List<TrackingServiceInterface> getAllServices() {
    return [
      _anilistService,
      _malService,
      _simklService,
    ];
  }

  /// Get connected tracking services
  List<TrackingServiceInterface> getConnectedServices() {
    return getAllServices()
        .where((service) => service.isAuthenticated)
        .toList();
  }
}