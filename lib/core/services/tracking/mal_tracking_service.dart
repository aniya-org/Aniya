/// MyAnimeList API service implementation
/// Provides authentication and tracking functionality for MyAnimeList
///
/// CREDIT: Based on research from AnymeX and other open source MAL implementations
/// for Flutter/Dart applications. This implementation follows common patterns
/// for OAuth2 authentication and REST API interactions.
/// CREDIT: OAuth2 with PKCE implementation based on MyAnimeList API v2 documentation at https://myanimelist.net/apiconfig/references/authorization
import 'package:get/get.dart';
import '../../../../core/domain/entities/entities.dart';
import '../../../../core/services/tracking/tracking_service_interface.dart';
import '../../../../core/services/tracking/mal_auth.dart';
import '../../../../core/utils/logger.dart';

class MyAnimeListTrackingService implements TrackingServiceInterface {
  final MalAuth _auth = Get.find<MalAuth>();

  @override
  TrackingService get serviceType => TrackingService.mal;

  @override
  bool get isAuthenticated => _auth.isAuthenticated;

  /// Initialize with stored tokens if available
  Future<void> initialize() async {
    await _auth.tryAutoLogin();
    Logger.info('MyAnimeList service initialized');
  }

  @override
  Future<bool> authenticate() async {
    try {
      await _auth.login();
      return _auth.isLoggedIn.value;
    } catch (e) {
      Logger.error('MyAnimeList authentication failed', error: e);
      return false;
    }
  }

  @override
  Future<TrackingUserProfile?> getUserProfile() async {
    if (!isAuthenticated) {
      Logger.warning('MAL: Not authenticated');
      return null;
    }

    try {
      await _auth.fetchUserProfile();
      return _auth.profileData.value;
    } catch (e) {
      Logger.error('MAL: Failed to get user profile', error: e);
      return null;
    }
  }

  @override
  Future<List<TrackingSearchResult>> searchMedia(
    String query,
    MediaType mediaType,
  ) async {
    if (!isAuthenticated) {
      Logger.warning('MAL: Not authenticated for search');
      return [];
    }

    try {
      // For now, return empty list as search is not implemented in MalAuth
      // TODO: Implement search in MalAuth controller
      Logger.info('MAL search not yet implemented');
      return [];
    } catch (e) {
      Logger.error('MAL: Search failed', error: e);
      return [];
    }
  }

  @override
  Future<bool> addToWatchlist(TrackingMediaItem media) async {
    if (!isAuthenticated) {
      Logger.warning('MAL: Not authenticated');
      return false;
    }

    try {
      await _auth.updateListEntry(
        media.id,
        status: TrackingStatus.planning,
        isAnime: media.mediaType == MediaType.anime,
      );
      return true;
    } catch (e) {
      Logger.error('MAL: Add to watchlist failed', error: e);
      return false;
    }
  }

  @override
  Future<bool> removeFromWatchlist(String mediaId) async {
    if (!isAuthenticated) {
      Logger.warning('MAL: Not authenticated');
      return false;
    }

    try {
      // MAL doesn't support removing items from list via API
      Logger.warning('MAL: Remove from watchlist not supported by API');
      return false;
    } catch (e) {
      Logger.error('MAL: Remove from watchlist failed', error: e);
      return false;
    }
  }

  @override
  Future<bool> updateProgress(TrackingProgressUpdate progress) async {
    if (!isAuthenticated) {
      Logger.warning('MAL: Not authenticated');
      return false;
    }

    Logger.info(
      'MAL: Updating progress for "${progress.mediaTitle}" (ID: ${progress.mediaId})',
    );

    try {
      TrackingStatus? status;
      if (progress.completed == true) {
        status = TrackingStatus.completed;
      }

      Logger.info(
        'MAL: Calling updateListEntry with ID ${progress.mediaId}, status: $status, progress: ${progress.episode ?? progress.chapter}',
      );

      await _auth.updateListEntry(
        progress.mediaId,
        status: status,
        progress: progress.episode ?? progress.chapter,
        isAnime: progress.mediaType == MediaType.anime,
      );

      Logger.info('MAL: Update successful');
      return true;
    } catch (e) {
      Logger.error('MAL: Update progress failed', error: e);
      return false;
    }
  }

  @override
  Future<TrackingProgress?> getProgress(String mediaId) async {
    if (!isAuthenticated) {
      Logger.warning('MAL: Not authenticated');
      return null;
    }

    try {
      // For now, return null as progress tracking is not fully implemented
      // TODO: Implement progress retrieval in MalAuth controller
      Logger.info('MAL getProgress not yet implemented');
      return null;
    } catch (e) {
      Logger.error('MAL: Get progress failed', error: e);
      return null;
    }
  }

  @override
  Future<bool> rateMedia(String mediaId, double rating) async {
    if (!isAuthenticated) {
      Logger.warning('MAL: Not authenticated');
      return false;
    }

    try {
      await _auth.updateListEntry(mediaId, score: rating);
      return true;
    } catch (e) {
      Logger.error('MAL: Rate media failed', error: e);
      return false;
    }
  }

  @override
  Future<List<TrackingMediaItem>> getWatchlist() async {
    if (!isAuthenticated) {
      Logger.warning('MAL: Not authenticated');
      return [];
    }

    try {
      // Refresh the lists from the auth controller
      await _auth.fetchUserAnimeList();
      await _auth.fetchUserMangaList();

      // Combine anime and manga lists
      final allItems = <TrackingMediaItem>[];
      allItems.addAll(_auth.animeList);
      allItems.addAll(_auth.mangaList);
      return allItems;
    } catch (e) {
      Logger.error('MAL: Get watchlist failed', error: e);
      return [];
    }
  }

  @override
  Future<void> logout() async {
    await _auth.logout();
    Logger.info('MAL logout completed');
  }
}
