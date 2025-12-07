/// AniList API service implementation
/// Provides authentication and tracking functionality for AniList
///
/// CREDIT: Based on research from AnymeX and other open source AniList implementations
/// for Flutter/Dart applications. This implementation follows common patterns
/// for OAuth2 authentication and GraphQL API interactions.
/// CREDIT: OAuth2 implementation based on AniList API documentation at https://docs.anilist.co/guide/auth/
/// CREDIT: GraphQL search implementation based on AniList API v2 documentation
library;

import 'package:get/get.dart';
import '../../../../core/domain/entities/entities.dart';
import '../../../../core/services/tracking/tracking_service_interface.dart';
import '../../../../core/services/tracking/anilist_auth.dart';
import '../../../../core/utils/logger.dart';

class AniListTrackingService implements TrackingServiceInterface {
  late final AnilistAuth _auth;

  AniListTrackingService() {
    // Try to find existing instance, otherwise create new one
    if (Get.isRegistered<AnilistAuth>(tag: 'anilist')) {
      _auth = Get.find<AnilistAuth>(tag: 'anilist');
    } else {
      _auth = Get.put<AnilistAuth>(AnilistAuth(), tag: 'anilist', permanent: true);
    }
  }

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
      return await _auth.searchMedia(query, mediaType);
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
      final success = await _auth.updateListEntry(
        UpdateListEntryParams(id: media.id, status: TrackingStatus.planning),
      );
      if (success) {
        Logger.info('AniList: Successfully added to watchlist');
      } else {
        Logger.warning('AniList: Failed to add to watchlist');
      }
      return success;
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

      // First, try direct update with the provided ID
      try {
        // Ensure we always have a status when updating progress
        final updateStatus = status ?? TrackingStatus.watching;

        final success = await _auth.updateListEntry(
          UpdateListEntryParams(
            id: progress.mediaId,
            progress: progress.episode ?? progress.chapter,
            status: updateStatus,
          ),
        );
        return success;
      } catch (e) {
        Logger.warning(
          'AniList: Direct update failed, searching for correct media ID by title: $e',
        );

        // If direct update fails, search for the media by title
        final results = await _auth.searchMedia(
          progress.mediaTitle,
          progress.mediaType,
        );

        if (results.isNotEmpty) {
          final correctId = results.first.id;
          Logger.info(
            'AniList: Found correct ID $correctId for "${progress.mediaTitle}"',
          );

          // Ensure we always have a status when updating progress
          final updateStatus = status ?? TrackingStatus.watching;

          final success = await _auth.updateListEntry(
            UpdateListEntryParams(
              id: correctId,
              progress: progress.episode ?? progress.chapter,
              status: updateStatus,
            ),
          );
          return success;
        } else {
          Logger.error(
            'AniList: Could not find media "${progress.mediaTitle}" on AniList',
          );
          return false;
        }
      }
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
      final entry = await _auth.getMediaListEntry(mediaId);
      if (entry == null) return null;

      return TrackingProgress(
        mediaId: mediaId,
        mediaType: MediaType.anime, // Would need to be determined based on media
        currentEpisode: entry['progress'],
        progress: entry['progress'] != null ? (entry['progress'] / 100.0) : null,
        completed: entry['status'] == 'COMPLETED',
        lastUpdated: DateTime.now(),
      );
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
