import '../../domain/entities/entities.dart';
import '../../enums/tracking_service.dart';

/// Base interface for media tracking services
/// Supports authentication, progress tracking, and watchlist management
abstract class TrackingServiceInterface {
  /// Get service type
  TrackingService get serviceType;

  /// Check if user is authenticated
  bool get isAuthenticated;

  /// Authenticate user with OAuth flow
  /// Returns [true] if authentication was successful
  Future<bool> authenticate();

  /// Get user profile information
  Future<TrackingUserProfile?> getUserProfile();

  /// Search for media on tracking service
  Future<List<TrackingSearchResult>> searchMedia(
    String query,
    MediaType mediaType,
  );

  /// Add media to user's watchlist/library
  Future<bool> addToWatchlist(TrackingMediaItem media);

  /// Remove media from user's watchlist/library
  Future<bool> removeFromWatchlist(String mediaId);

  /// Update progress for anime/manga episodes or chapters
  Future<bool> updateProgress(TrackingProgressUpdate progress);

  /// Get current progress for a media item
  Future<TrackingProgress?> getProgress(String mediaId);

  /// Rate media
  Future<bool> rateMedia(String mediaId, double rating);

  /// Get user's watchlist/library
  Future<List<TrackingMediaItem>> getWatchlist();

  /// Logout user
  Future<void> logout();
}

/// User profile information from tracking service
class TrackingUserProfile {
  final String id;
  final String username;
  final String? avatar;
  final int? mediaCount;

  const TrackingUserProfile({
    required this.id,
    required this.username,
    this.avatar,
    this.mediaCount,
  });
}

/// Search result from tracking service
class TrackingSearchResult {
  final String id;
  final String title;
  final Map<String, String?>? alternativeTitles;
  final String? coverImage;
  final MediaType mediaType;
  final int? year;
  final Map<String, dynamic> serviceIds; // IDs for different services

  const TrackingSearchResult({
    required this.id,
    required this.title,
    this.alternativeTitles,
    this.coverImage,
    required this.mediaType,
    this.year,
    required this.serviceIds,
  });
}

/// Media item for tracking purposes
class TrackingMediaItem {
  final String id;
  final String title;
  final MediaType mediaType;
  final String? coverImage;
  final int? year;
  final TrackingStatus? status;
  final double? rating;
  final int? episodesWatched;
  final int? totalEpisodes;
  final int? chaptersRead;
  final int? totalChapters;
  final Map<String, dynamic> serviceIds;

  const TrackingMediaItem({
    required this.id,
    required this.title,
    required this.mediaType,
    this.coverImage,
    this.year,
    this.status,
    this.rating,
    this.episodesWatched,
    this.totalEpisodes,
    this.chaptersRead,
    this.totalChapters,
    required this.serviceIds,
  });
}

/// Progress update for tracking
class TrackingProgressUpdate {
  final String mediaId;
  final String mediaTitle;
  final MediaType mediaType;
  final int? episode;
  final int? chapter;
  final double? progress; // 0.0 to 1.0
  final bool? completed;

  const TrackingProgressUpdate({
    required this.mediaId,
    required this.mediaTitle,
    required this.mediaType,
    this.episode,
    this.chapter,
    this.progress,
    this.completed,
  });
}

/// Current progress from tracking service
class TrackingProgress {
  final String mediaId;
  final MediaType mediaType;
  final int? currentEpisode;
  final int? currentChapter;
  final double? progress;
  final bool? completed;
  final DateTime? lastUpdated;

  const TrackingProgress({
    required this.mediaId,
    required this.mediaType,
    this.currentEpisode,
    this.currentChapter,
    this.progress,
    this.completed,
    this.lastUpdated,
  });
}

/// Tracking status for media items
enum TrackingStatus { planning, watching, completed, onHold, dropped }
