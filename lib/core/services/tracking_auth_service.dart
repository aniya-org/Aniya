import 'package:get/get.dart';
import '../enums/tracking_service.dart';
import '../utils/logger.dart';
import 'tracking/anilist_auth.dart';
import 'tracking/mal_auth.dart';
import 'tracking/simkl_auth.dart';

class TrackingAuthService {
  final AnilistAuth _anilistAuth = Get.find<AnilistAuth>();
  final MalAuth _malAuth = Get.find<MalAuth>();
  final SimklAuth _simklAuth = Get.find<SimklAuth>();

  Future<bool> authenticate(TrackingService service) async {
    try {
      switch (service) {
        case TrackingService.anilist:
          await _anilistAuth.login();
          return _anilistAuth.isLoggedIn.value;
        case TrackingService.mal:
          await _malAuth.login();
          return _malAuth.isLoggedIn.value;
        case TrackingService.simkl:
          await _simklAuth.login();
          return _simklAuth.isLoggedIn.value;
        case TrackingService.jikan:
        case TrackingService.local:
          return true; // Jikan and local don't require authentication
      }
    } catch (e) {
      Logger.error('Error authenticating with $service', error: e);
      return false;
    }
  }

  Future<void> logout(TrackingService service) async {
    try {
      switch (service) {
        case TrackingService.anilist:
          await _anilistAuth.logout();
          break;
        case TrackingService.mal:
          await _malAuth.logout();
          break;
        case TrackingService.simkl:
          await _simklAuth.logout();
          break;
        case TrackingService.jikan:
        case TrackingService.local:
          // No logout needed for these services
          break;
      }
    } catch (e) {
      Logger.error('Error logging out from $service', error: e);
    }
  }

  Future<bool> isAuthenticated(TrackingService service) async {
    switch (service) {
      case TrackingService.anilist:
        return _anilistAuth.isAuthenticated;
      case TrackingService.mal:
        return _malAuth.isAuthenticated;
      case TrackingService.simkl:
        return _simklAuth.isAuthenticated;
      case TrackingService.jikan:
      case TrackingService.local:
        return true; // These services are always "authenticated"
    }
  }

  Future<String?> getUsername(TrackingService service) async {
    try {
      switch (service) {
        case TrackingService.anilist:
          return _anilistAuth.profileData.value.username;
        case TrackingService.mal:
          return _malAuth.profileData.value.username;
        case TrackingService.simkl:
          return _simklAuth.profileData.value.username;
        case TrackingService.jikan:
        case TrackingService.local:
          return null;
      }
    } catch (e) {
      Logger.error('Error getting username for $service', error: e);
      return null;
    }
  }
}
