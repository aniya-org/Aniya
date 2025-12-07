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
  late final MalAuth _auth;

  MyAnimeListTrackingService() {
    // Try to find existing instance, otherwise create new one
    if (Get.isRegistered<MalAuth>(tag: 'mal')) {
      _auth = Get.find<MalAuth>(tag: 'mal');
    } else {
      _auth = Get.put<MalAuth>(MalAuth(), tag: 'mal', permanent: true);
    }
  }

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
      return await _auth.searchMedia(query, mediaType);
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
      // First, try direct update with the provided ID
      try {
        await _auth.updateListEntry(
          media.id,
          status: TrackingStatus.planning,
          isAnime: media.mediaType == MediaType.anime,
        );
        return true;
      } catch (e) {
        Logger.warning(
          'MAL: Direct add failed, searching for correct media ID by title: $e',
        );

        // If direct update fails, search for the media by title
        final correctId = await _auth.searchMediaByTitle(
          media.title,
          media.mediaType == MediaType.anime,
        );

        if (correctId != null) {
          Logger.info(
            'MAL: Found correct ID $correctId for "${media.title}"',
          );

          await _auth.updateListEntry(
            correctId,
            status: TrackingStatus.planning,
            isAnime: media.mediaType == MediaType.anime,
          );

          Logger.info('MAL: Add to watchlist successful after search');
          return true;
        } else {
          Logger.error(
            'MAL: Could not find media "${media.title}" on MyAnimeList',
          );
          return false;
        }
      }
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

      // First, try direct update with the provided ID
      try {
        // For new items with no progress, use planning status instead of watching
        final updateStatus = status ??
            ((progress.episode ?? progress.chapter ?? 0) > 0
                ? TrackingStatus.watching
                : TrackingStatus.planning);

        Logger.info(
          'MAL: Calling updateListEntry with ID ${progress.mediaId}, status: $updateStatus, progress: ${progress.episode ?? progress.chapter}',
        );

        await _auth.updateListEntry(
          progress.mediaId,
          status: updateStatus,
          progress: progress.episode ?? progress.chapter,
          isAnime: progress.mediaType == MediaType.anime,
        );

        Logger.info('MAL: Update successful');
        return true;
      } catch (e) {
        Logger.warning(
          'MAL: Direct update failed, searching for correct media ID by title: $e',
        );

        // If direct update fails, search for the media by title
        final correctId = await _auth.searchMediaByTitle(
          progress.mediaTitle,
          progress.mediaType == MediaType.anime,
        );

        if (correctId != null) {
          Logger.info(
            'MAL: Found correct ID $correctId for "${progress.mediaTitle}"',
          );

          // For new items with no progress, use planning status instead of watching
          final updateStatus = status ??
              ((progress.episode ?? progress.chapter ?? 0) > 0
                  ? TrackingStatus.watching
                  : TrackingStatus.planning);

          await _auth.updateListEntry(
            correctId,
            status: updateStatus,
            progress: progress.episode ?? progress.chapter,
            isAnime: progress.mediaType == MediaType.anime,
          );

          Logger.info('MAL: Update successful after search');
          return true;
        } else {
          Logger.error(
            'MAL: Could not find media "${progress.mediaTitle}" on MyAnimeList',
          );
          return false;
        }
      }
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
      final entry = await _auth.getMediaListEntry(mediaId, true); // Assume anime for now
      if (entry == null) return null;

      return TrackingProgress(
        mediaId: mediaId,
        mediaType: MediaType.anime, // Would need to be determined based on media
        currentEpisode: entry['num_episodes_watched'],
        currentChapter: entry['num_chapters_read'],
        completed: entry['status'] == 'completed',
        lastUpdated: DateTime.now(),
      );
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
