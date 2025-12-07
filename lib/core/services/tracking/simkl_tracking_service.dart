/// Simkl API service implementation
/// Provides authentication and tracking functionality for Simkl
///
/// CREDIT: Based on research from AnymeX and other open source Simkl implementations
/// for Flutter/Dart applications. This implementation follows common patterns
/// for OAuth2 authentication and REST API interactions.
/// CREDIT: OAuth2 implementation based on common OAuth2 patterns and Simkl API documentation research
library;

import 'package:get/get.dart';
import '../../../../core/domain/entities/entities.dart';
import '../../../../core/services/tracking/tracking_service_interface.dart';
import '../../../../core/services/tracking/simkl_auth.dart';
import '../../../../core/utils/logger.dart';

class SimklTrackingService implements TrackingServiceInterface {
  late final SimklAuth _auth;

  SimklTrackingService() {
    // Try to find existing instance, otherwise create new one
    if (Get.isRegistered<SimklAuth>(tag: 'simkl')) {
      _auth = Get.find<SimklAuth>(tag: 'simkl');
    } else {
      _auth = Get.put<SimklAuth>(SimklAuth(), tag: 'simkl', permanent: true);
    }
  }

  @override
  TrackingService get serviceType => TrackingService.simkl;

  @override
  bool get isAuthenticated => _auth.isAuthenticated;

  /// Initialize with stored tokens if available
  Future<void> initialize() async {
    await _auth.tryAutoLogin();
    Logger.info('Simkl service initialized');
  }

  @override
  Future<bool> authenticate() async {
    try {
      await _auth.login();
      return _auth.isLoggedIn.value;
    } catch (e) {
      Logger.error('Simkl authentication failed', error: e);
      return false;
    }
  }

  @override
  Future<TrackingUserProfile?> getUserProfile() async {
    if (!isAuthenticated) {
      Logger.warning('Simkl: Not authenticated');
      return null;
    }

    try {
      await _auth.fetchUserProfile();
      return _auth.profileData.value;
    } catch (e) {
      Logger.error('Simkl: Failed to get user profile', error: e);
      return null;
    }
  }

  @override
  Future<List<TrackingSearchResult>> searchMedia(
    String query,
    MediaType mediaType,
  ) async {
    if (!isAuthenticated) {
      Logger.warning('Simkl: Not authenticated for search');
      return [];
    }

    try {
      return await _auth.searchMedia(query, mediaType);
    } catch (e) {
      Logger.error('Simkl: Search failed', error: e);
      return [];
    }
  }

  @override
  Future<bool> addToWatchlist(TrackingMediaItem media) async {
    if (!isAuthenticated) {
      Logger.warning('Simkl: Not authenticated');
      return false;
    }

    try {
      // First, try direct update with the provided ID
      try {
        await _auth.updateListEntry(media.id, status: TrackingStatus.planning);
        return true;
      } catch (e) {
        Logger.warning(
          'Simkl: Direct add failed, searching for correct media ID by title: $e',
        );

        // If direct update fails, search for the media by title
        final correctId = await _auth.searchMediaByTitle(media.title);

        if (correctId != null) {
          Logger.info(
            'Simkl: Found correct ID $correctId for "${media.title}"',
          );

          await _auth.updateListEntry(correctId, status: TrackingStatus.planning);
          Logger.info('Simkl: Add to watchlist successful after search');
          return true;
        } else {
          Logger.error(
            'Simkl: Could not find media "${media.title}" in Simkl',
          );
          return false;
        }
      }
    } catch (e) {
      Logger.error('Simkl: Add to watchlist failed', error: e);
      return false;
    }
  }

  @override
  Future<bool> removeFromWatchlist(String mediaId) async {
    if (!isAuthenticated) {
      Logger.warning('Simkl: Not authenticated');
      return false;
    }

    try {
      // Simkl doesn't support removing items from list via API
      Logger.warning('Simkl: Remove from watchlist not supported by API');
      return false;
    } catch (e) {
      Logger.error('Simkl: Remove from watchlist failed', error: e);
      return false;
    }
  }

  @override
  Future<bool> updateProgress(TrackingProgressUpdate progress) async {
    if (!isAuthenticated) {
      Logger.warning('Simkl: Not authenticated');
      return false;
    }

    try {
      TrackingStatus? status;
      if (progress.completed == true) {
        status = TrackingStatus.completed;
      }

      // Try direct update first
      try {
        // Ensure we always have a status when updating progress
        final updateStatus = status ?? TrackingStatus.watching;

        await _auth.updateListEntry(
          progress.mediaId,
          status: updateStatus,
          progress: progress.episode ?? progress.chapter,
        );
        return true;
      } catch (e) {
        Logger.warning(
          'Simkl: Direct update failed, trying to find correct Simkl ID by searching',
        );

        // Try to search for the media by title to get the correct Simkl ID
        final correctId = await _auth.searchMediaByTitle(progress.mediaTitle);

        if (correctId != null) {
          Logger.info(
            'Simkl: Found correct ID $correctId for "${progress.mediaTitle}"',
          );

          // Ensure we always have a status when updating progress
          final updateStatus = status ?? TrackingStatus.watching;

          await _auth.updateListEntry(
            correctId,
            status: updateStatus,
            progress: progress.episode ?? progress.chapter,
          );
          return true;
        } else {
          Logger.error(
            'Simkl: Could not find media "${progress.mediaTitle}" in Simkl',
          );
          return false;
        }
      }
    } catch (e) {
      Logger.error('Simkl: Update progress failed', error: e);
      return false;
    }
  }

  @override
  Future<TrackingProgress?> getProgress(String mediaId) async {
    if (!isAuthenticated) {
      Logger.warning('Simkl: Not authenticated');
      return null;
    }

    try {
      final entry = await _auth.getMediaListEntry(mediaId);
      if (entry == null) return null;

      return TrackingProgress(
        mediaId: mediaId,
        mediaType: MediaType.anime, // Simkl primarily handles anime
        currentEpisode: entry['progress'],
        progress: entry['progress'] != null ? (entry['progress'] / 100.0) : null,
        completed: entry['status'] == 'completed',
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      Logger.error('Simkl: Get progress failed', error: e);
      return null;
    }
  }

  @override
  Future<bool> rateMedia(String mediaId, double rating) async {
    if (!isAuthenticated) {
      Logger.warning('Simkl: Not authenticated');
      return false;
    }

    try {
      await _auth.updateListEntry(mediaId, score: rating);
      return true;
    } catch (e) {
      Logger.error('Simkl: Rate media failed', error: e);
      return false;
    }
  }

  @override
  Future<List<TrackingMediaItem>> getWatchlist() async {
    if (!isAuthenticated) {
      Logger.warning('Simkl: Not authenticated');
      return [];
    }

    try {
      // Refresh the watchlist from the auth controller
      await _auth.fetchWatchlist();
      return _auth.watchlist;
    } catch (e) {
      Logger.error('Simkl: Get watchlist failed', error: e);
      return [];
    }
  }

  @override
  Future<void> logout() async {
    await _auth.logout();
    Logger.info('Simkl logout completed');
  }
}
