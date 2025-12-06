/// AniList API service implementation
/// Provides authentication and tracking functionality for AniList
///
/// CREDIT: Based on research from AnymeX and other open source AniList implementations
/// for Flutter/Dart applications. This implementation follows common patterns
/// for OAuth2 authentication and GraphQL API interactions.
/// CREDIT: OAuth2 implementation based on AniList API documentation at https://docs.anilist.co/guide/auth/
library;

import 'package:get/get.dart';
import '../../../../core/domain/entities/entities.dart';
import '../../../../core/services/tracking/tracking_service_interface.dart';
import '../../../../core/services/tracking/anilist_auth.dart';
import '../../../../core/utils/logger.dart';

class AniListTrackingService implements TrackingServiceInterface {
  final AnilistAuth _auth = Get.find<AnilistAuth>();

  @override
  TrackingService get serviceType => TrackingService.anilist;

  @override
  bool get isAuthenticated => _auth.isLoggedIn.value;

  /// Initialize with stored tokens if available
  Future<void> initialize() async {
    await _auth.tryAutoLogin();
    Logger.info('AniList service initialized');
  }

  @override
  Future<bool> authenticate() async {
    try {
      await _auth.login();
      return _auth.isLoggedIn.value;
    } catch (e) {
      Logger.error('AniList authentication failed', error: e);
      return false;
    }
  }

  @override
  Future<TrackingUserProfile?> getUserProfile() async {
    if (!isAuthenticated) {
      Logger.warning('AniList: Not authenticated');
      return null;
    }

    try {
      await _auth.fetchUserProfile();
      return _auth.profileData.value;
    } catch (e) {
      Logger.error('AniList: Failed to get user profile', error: e);
      return null;
    }
  }

  @override
  Future<List<TrackingSearchResult>> searchMedia(
    String query,
    MediaType mediaType,
  ) async {
    if (!isAuthenticated) {
      Logger.warning('AniList: Not authenticated for search');
      return [];
    }

    try {
      // For now, return empty list as search is not implemented in AnilistAuth
      // TODO: Implement search in AnilistAuth controller
      Logger.info('AniList search not yet implemented');
      return [];
    } catch (e) {
      Logger.error('AniList: Search failed', error: e);
      return [];
    }
  }

  @override
  Future<bool> addToWatchlist(TrackingMediaItem media) async {
    if (!isAuthenticated) {
      Logger.warning('AniList: Not authenticated');
      return false;
    }

    try {
      // Use the auth controller's updateListEntry method
      await _auth.updateListEntry(
        UpdateListEntryParams(id: media.id, status: TrackingStatus.planning),
      );
      return true;
    } catch (e) {
      Logger.error('AniList: Add to watchlist failed', error: e);
      return false;
    }
  }

  @override
  Future<bool> removeFromWatchlist(String mediaId) async {
    if (!isAuthenticated) {
      Logger.warning('AniList: Not authenticated');
      return false;
    }

    try {
      await _auth.deleteListEntry(mediaId);
      return true;
    } catch (e) {
      Logger.error('AniList: Remove from watchlist failed', error: e);
      return false;
    }
  }

  @override
  Future<bool> updateProgress(TrackingProgressUpdate progress) async {
    if (!isAuthenticated) {
      Logger.warning('AniList: Not authenticated');
      return false;
    }

    try {
      TrackingStatus? status;
      if (progress.completed == true) {
        status = TrackingStatus.completed;
      }

      await _auth.updateListEntry(
        UpdateListEntryParams(
          id: progress.mediaId,
          progress: progress.episode ?? progress.chapter,
          status: status,
        ),
      );
      return true;
    } catch (e) {
      Logger.error('AniList: Update progress failed', error: e);
      return false;
    }
  }

  @override
  Future<TrackingProgress?> getProgress(String mediaId) async {
    if (!isAuthenticated) {
      Logger.warning('AniList: Not authenticated');
      return null;
    }

    try {
      // For now, return null as progress tracking is not fully implemented
      // TODO: Implement progress retrieval in AnilistAuth controller
      Logger.info('AniList getProgress not yet implemented');
      return null;
    } catch (e) {
      Logger.error('AniList: Get progress failed', error: e);
      return null;
    }
  }

  @override
  Future<bool> rateMedia(String mediaId, double rating) async {
    if (!isAuthenticated) {
      Logger.warning('AniList: Not authenticated');
      return false;
    }

    try {
      await _auth.updateListEntry(
        UpdateListEntryParams(id: mediaId, score: rating),
      );
      return true;
    } catch (e) {
      Logger.error('AniList: Rate media failed', error: e);
      return false;
    }
  }

  @override
  Future<List<TrackingMediaItem>> getWatchlist() async {
    if (!isAuthenticated) {
      Logger.warning('AniList: Not authenticated');
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
      Logger.error('AniList: Get watchlist failed', error: e);
      return [];
    }
  }

  @override
  Future<void> logout() async {
    await _auth.logout();
    Logger.info('AniList logout completed');
  }
}
