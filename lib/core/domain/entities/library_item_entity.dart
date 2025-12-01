import 'package:equatable/equatable.dart';
import 'media_entity.dart';
import '../../enums/tracking_service.dart';

/// Status of a media item in user's library
enum LibraryStatus {
  // Anime/Manga statuses
  currentlyWatching,
  completed,
  onHold,
  dropped,
  planToWatch, // Only for anime

  // Movie statuses (different terminology)
  watched,
  wantToWatch,

  // Unified statuses for cross-service compatibility
  watching, // represents currentlyWatching for anime, inProgress for manga
  finished; // represents completed for all media types

  /// Convert to API-specific status strings
  String toApiString(TrackingService service, MediaType mediaType) {
    switch (service) {
      case TrackingService.anilist:
        return _toAniListString(mediaType);
      case TrackingService.mal:
        return _toMalString(mediaType);
      case TrackingService.simkl:
        return _toSimklString(mediaType);
      case TrackingService.jikan:
        return _toMalString(mediaType); // Jikan uses MAL-compatible strings
      case TrackingService.local:
        return name; // Local storage uses enum name directly
    }
  }

  String _toAniListString(MediaType mediaType) {
    switch (this) {
      case LibraryStatus.currentlyWatching:
        return mediaType == MediaType.anime ? 'CURRENT' : 'CURRENT';
      case LibraryStatus.completed:
        return 'COMPLETED';
      case LibraryStatus.onHold:
        return 'PAUSED';
      case LibraryStatus.dropped:
        return 'DROPPED';
      case LibraryStatus.planToWatch:
        return 'PLANNING';
      case LibraryStatus.watching:
        return mediaType == MediaType.anime ? 'CURRENT' : 'CURRENT';
      case LibraryStatus.finished:
        return 'COMPLETED';
      case LibraryStatus.watched:
        return 'COMPLETED';
      case LibraryStatus.wantToWatch:
        return 'PLANNING';
    }
  }

  String _toMalString(MediaType mediaType) {
    switch (this) {
      case LibraryStatus.currentlyWatching:
        return mediaType == MediaType.anime ? 'watching' : 'reading';
      case LibraryStatus.completed:
        return 'completed';
      case LibraryStatus.onHold:
        return 'on_hold';
      case LibraryStatus.dropped:
        return 'dropped';
      case LibraryStatus.planToWatch:
        return mediaType == MediaType.anime ? 'plan_to_watch' : 'plan_to_read';
      case LibraryStatus.watching:
        return mediaType == MediaType.anime ? 'watching' : 'reading';
      case LibraryStatus.finished:
        return 'completed';
      case LibraryStatus.watched:
        return 'completed';
      case LibraryStatus.wantToWatch:
        return mediaType == MediaType.anime ? 'plan_to_watch' : 'plan_to_read';
    }
  }

  String _toSimklString(MediaType mediaType) {
    switch (this) {
      case LibraryStatus.currentlyWatching:
        return 'watching';
      case LibraryStatus.completed:
        return 'completed';
      case LibraryStatus.onHold:
        return 'hold';
      case LibraryStatus.dropped:
        return 'dropped';
      case LibraryStatus.planToWatch:
        return 'plan_to_watch';
      case LibraryStatus.watching:
        return 'watching';
      case LibraryStatus.finished:
        return 'completed';
      case LibraryStatus.watched:
        return 'completed';
      case LibraryStatus.wantToWatch:
        return 'plan_to_watch';
    }
  }
}

/// Score/Rating given to a media item
class UserScore {
  final int? rawScore; // 1-10 scale used internally
  final double? normalizedScore; // 0.0-1.0 scale for UI
  final String? displayText; // Human readable score

  const UserScore({this.rawScore, this.normalizedScore, this.displayText});

  /// Convert to service-specific format
  dynamic toApiFormat(TrackingService service) {
    switch (service) {
      case TrackingService.anilist:
        return rawScore != null
            ? rawScore! * 10
            : null; // AniList expects 1-100
      case TrackingService.mal:
        return rawScore; // MAL expects 1-10
      case TrackingService.simkl:
        return rawScore; // Simkl expects 1-10
      case TrackingService.jikan:
        return rawScore; // Jikan uses same as MAL
      case TrackingService.local:
        return rawScore; // Local uses same format
    }
  }
}

/// Progress tracking for media consumption
class WatchProgress {
  final int? currentEpisode; // For anime
  final int? currentChapter; // For manga
  final int? currentVolume; // For manga
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? updatedAt;

  const WatchProgress({
    this.currentEpisode,
    this.currentChapter,
    this.currentVolume,
    this.startedAt,
    this.completedAt,
    this.updatedAt,
  });

  /// Convert to service-specific format
  Map<String, dynamic> toApiFormat(
    TrackingService service,
    MediaType mediaType,
  ) {
    switch (service) {
      case TrackingService.anilist:
        return {
          'progress': mediaType == MediaType.anime
              ? currentEpisode
              : currentChapter,
          if (startedAt != null)
            'startedAt': {
              'year': startedAt!.year,
              'month': startedAt!.month,
              'day': startedAt!.day,
            },
          if (completedAt != null)
            'completedAt': {
              'year': completedAt!.year,
              'month': completedAt!.month,
              'day': completedAt!.day,
            },
        };

      case TrackingService.mal:
        if (mediaType == MediaType.anime) {
          return {'num_watched_episodes': currentEpisode ?? 0};
        } else {
          return {
            'num_read_chapters': currentChapter ?? 0,
            'num_read_volumes': currentVolume ?? 0,
          };
        }

      case TrackingService.simkl:
        return {
          if (currentEpisode != null) 'last_watched': currentEpisode,
          if (currentChapter != null) 'last_read': currentChapter,
        };

      case TrackingService.jikan:
        // Jikan uses MAL-compatible format
        if (mediaType == MediaType.anime) {
          return {'num_watched_episodes': currentEpisode ?? 0};
        } else {
          return {
            'num_read_chapters': currentChapter ?? 0,
            'num_read_volumes': currentVolume ?? 0,
          };
        }

      case TrackingService.local:
        // Local storage uses simple format
        return {
          if (currentEpisode != null) 'currentEpisode': currentEpisode,
          if (currentChapter != null) 'currentChapter': currentChapter,
          if (currentVolume != null) 'currentVolume': currentVolume,
        };
    }
  }

  /// Create a copy with modified fields
  WatchProgress copyWith({
    int? currentEpisode,
    int? currentChapter,
    int? currentVolume,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? updatedAt,
  }) {
    return WatchProgress(
      currentEpisode: currentEpisode ?? this.currentEpisode,
      currentChapter: currentChapter ?? this.currentChapter,
      currentVolume: currentVolume ?? this.currentVolume,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// User notes and tags for a media item
class UserNotes {
  final String? personalNotes;
  final String? review;
  final List<String>? tags;
  final bool isFavorite;
  final bool isPrivate; // Hide from public profiles

  const UserNotes({
    this.personalNotes,
    this.review,
    this.tags,
    this.isFavorite = false,
    this.isPrivate = false,
  });
}

class LibraryItemEntity extends Equatable {
  final String id; // Unique ID combining mediaId + userService
  final String mediaId; // The media this item references
  final TrackingService userService; // Which service this belongs to
  final MediaEntity? media; // Full media entity (optional for performance)

  /// Media type for filtering (anime, manga, movie, etc.)
  final MediaType? mediaType;

  /// Normalized ID for cross-source matching
  final String? normalizedId;

  /// Source extension ID that provided this content
  final String? sourceId;

  /// Source extension name for display
  final String? sourceName;

  final LibraryStatus status;
  final UserScore? score;
  final WatchProgress? progress;
  final UserNotes? notes;

  final DateTime? addedAt; // When user added to their list
  final DateTime? lastUpdated;

  /// Convenience getter for current episode from progress
  int? get currentEpisode => progress?.currentEpisode;

  /// Convenience getter for current chapter from progress
  int? get currentChapter => progress?.currentChapter;

  /// Get the effective media type (from mediaType field or media entity)
  MediaType get effectiveMediaType =>
      mediaType ?? media?.type ?? MediaType.anime;

  /// Returns true if this is a video-based library item
  bool get isVideoType => effectiveMediaType.isVideoType;

  /// Returns true if this is a reading-based library item
  bool get isReadingType => effectiveMediaType.isReadingType;

  const LibraryItemEntity({
    required this.id,
    required this.mediaId,
    required this.userService,
    this.media,
    this.mediaType,
    this.normalizedId,
    this.sourceId,
    this.sourceName,
    required this.status,
    this.score,
    this.progress,
    this.notes,
    this.addedAt,
    this.lastUpdated,
  });

  /// Generate a normalized ID for cross-source matching
  static String generateNormalizedId(
    String title,
    MediaType type, [
    int? year,
  ]) {
    // Normalize title: lowercase, remove special characters, trim
    final normalized = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();

    final yearSuffix = year != null ? '_$year' : '';
    return '${type.name}_$normalized$yearSuffix';
  }

  @override
  List<Object?> get props => [
    id,
    mediaId,
    userService,
    media,
    mediaType,
    normalizedId,
    sourceId,
    sourceName,
    status,
    score,
    progress,
    notes,
    addedAt,
    lastUpdated,
  ];

  /// Create a copy with modified fields
  LibraryItemEntity copyWith({
    String? id,
    String? mediaId,
    TrackingService? userService,
    MediaEntity? media,
    MediaType? mediaType,
    String? normalizedId,
    String? sourceId,
    String? sourceName,
    LibraryStatus? status,
    UserScore? score,
    WatchProgress? progress,
    UserNotes? notes,
    DateTime? addedAt,
    DateTime? lastUpdated,
  }) {
    return LibraryItemEntity(
      id: id ?? this.id,
      mediaId: mediaId ?? this.mediaId,
      userService: userService ?? this.userService,
      media: media ?? this.media,
      mediaType: mediaType ?? this.mediaType,
      normalizedId: normalizedId ?? this.normalizedId,
      sourceId: sourceId ?? this.sourceId,
      sourceName: sourceName ?? this.sourceName,
      status: status ?? this.status,
      score: score ?? this.score,
      progress: progress ?? this.progress,
      notes: notes ?? this.notes,
      addedAt: addedAt ?? this.addedAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  /// Convert to API format for a specific service
  Map<String, dynamic> toApiFormat(
    TrackingService targetService,
    MediaType mediaType,
  ) {
    final progressData = progress?.toApiFormat(targetService, mediaType) ?? {};
    final scoreData = score?.toApiFormat(targetService) ?? {};

    return {
      'mediaId': mediaId,
      'status': status.toApiString(targetService, mediaType),
      ...progressData,
      ...scoreData,
    };
  }
}
