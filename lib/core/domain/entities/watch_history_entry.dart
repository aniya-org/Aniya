import 'package:equatable/equatable.dart';
import 'media_entity.dart';

/// Represents a watch/read history entry for tracking user progress
/// Supports both video-based (anime, movies, TV) and reading-based (manga, novels) content
class WatchHistoryEntry extends Equatable {
  /// Unique identifier for this history entry
  /// Format: {mediaType}_{normalizedMediaId}_{sourceId}
  final String id;

  /// The media item this entry tracks
  final String mediaId;

  /// Normalized ID for cross-source matching
  /// Allows the same show from CloudStream or Mangayomi to map to the same entry
  final String? normalizedId;

  /// Media type for filtering (anime, manga, movie, etc.)
  final MediaType mediaType;

  /// Title of the media for display purposes
  final String title;

  /// Cover image URL
  final String? coverImage;

  /// Source extension ID that provided this content
  final String sourceId;

  /// Source extension name for display
  final String sourceName;

  // === Video Progress (for anime, movies, TV, cartoons, documentaries, livestreams) ===

  /// Current episode number (1-indexed)
  final int? episodeNumber;

  /// Episode identifier from the source
  final String? episodeId;

  /// Episode title
  final String? episodeTitle;

  /// Playback position in milliseconds
  final int? playbackPositionMs;

  /// Total duration of the episode in milliseconds
  final int? totalDurationMs;

  // === Reading Progress (for manga, novels) ===

  /// Current chapter number
  final int? chapterNumber;

  /// Chapter identifier from the source
  final String? chapterId;

  /// Chapter title
  final String? chapterTitle;

  /// Current volume number
  final int? volumeNumber;

  /// Current page number within the chapter
  final int? pageNumber;

  /// Total pages in the current chapter
  final int? totalPages;

  // === Livestream specific ===

  /// Livestream identifier
  final String? livestreamId;

  /// Whether the stream was live when last watched
  final bool? wasLive;

  // === Timestamps ===

  /// When this entry was first created (first watch/read)
  final DateTime createdAt;

  /// When this entry was last updated
  final DateTime lastPlayedAt;

  /// When the user completed this media (if applicable)
  final DateTime? completedAt;

  const WatchHistoryEntry({
    required this.id,
    required this.mediaId,
    this.normalizedId,
    required this.mediaType,
    required this.title,
    this.coverImage,
    required this.sourceId,
    required this.sourceName,
    this.episodeNumber,
    this.episodeId,
    this.episodeTitle,
    this.playbackPositionMs,
    this.totalDurationMs,
    this.chapterNumber,
    this.chapterId,
    this.chapterTitle,
    this.volumeNumber,
    this.pageNumber,
    this.totalPages,
    this.livestreamId,
    this.wasLive,
    required this.createdAt,
    required this.lastPlayedAt,
    this.completedAt,
  });

  /// Returns true if this is a video-based entry
  bool get isVideoEntry => mediaType.isVideoType;

  /// Returns true if this is a reading-based entry
  bool get isReadingEntry => mediaType.isReadingType;

  /// Returns the progress percentage (0.0 to 1.0)
  double get progressPercentage {
    if (isVideoEntry) {
      if (playbackPositionMs != null &&
          totalDurationMs != null &&
          totalDurationMs! > 0) {
        return (playbackPositionMs! / totalDurationMs!).clamp(0.0, 1.0);
      }
    } else if (isReadingEntry) {
      if (pageNumber != null && totalPages != null && totalPages! > 0) {
        return (pageNumber! / totalPages!).clamp(0.0, 1.0);
      }
    }
    return 0.0;
  }

  /// Returns true if the user has completed this episode/chapter
  bool get isCurrentUnitCompleted {
    if (isVideoEntry) {
      // Consider completed if watched more than 90%
      return progressPercentage >= 0.9;
    } else if (isReadingEntry) {
      // Consider completed if on last page
      return pageNumber != null &&
          totalPages != null &&
          pageNumber! >= totalPages!;
    }
    return false;
  }

  /// Returns a human-readable progress string
  String get progressDisplayString {
    if (isVideoEntry) {
      if (episodeNumber != null) {
        final progress = (progressPercentage * 100).toInt();
        return 'Episode $episodeNumber • $progress%';
      }
      return 'In Progress';
    } else if (isReadingEntry) {
      if (chapterNumber != null) {
        if (pageNumber != null && totalPages != null) {
          // For manga/novels with fixed page counts
          return 'Chapter $chapterNumber • Page $pageNumber/$totalPages';
        } else if (pageNumber != null) {
          // For novels with scroll progress (no totalPages)
          final progress = (progressPercentage * 100).toInt();
          return 'Chapter $chapterNumber • $progress%';
        }
        return 'Chapter $chapterNumber';
      }
      return 'Reading';
    }
    return 'In Progress';
  }

  /// Returns the formatted remaining time for video content
  String? get remainingTimeFormatted {
    if (!isVideoEntry ||
        playbackPositionMs == null ||
        totalDurationMs == null) {
      return null;
    }
    final remainingMs = totalDurationMs! - playbackPositionMs!;
    if (remainingMs <= 0) return null;

    final minutes = (remainingMs / 60000).floor();
    final seconds = ((remainingMs % 60000) / 1000).floor();

    if (minutes > 60) {
      final hours = (minutes / 60).floor();
      final mins = minutes % 60;
      return '${hours}h ${mins}m left';
    }
    return '${minutes}m ${seconds}s left';
  }

  /// Generate a normalized ID for cross-source matching
  static String generateNormalizedId(
    String title,
    MediaType type, {
    int? year,
  }) {
    // Normalize title: lowercase, remove special characters, trim
    final normalized = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();

    final yearSuffix = year != null ? '_$year' : '';
    return '${type.name}_$normalized$yearSuffix';
  }

  /// Generate a unique ID for this entry
  static String generateId(MediaType type, String mediaId, String sourceId) {
    return '${type.name}_${mediaId}_$sourceId';
  }

  WatchHistoryEntry copyWith({
    String? id,
    String? mediaId,
    String? normalizedId,
    MediaType? mediaType,
    String? title,
    String? coverImage,
    String? sourceId,
    String? sourceName,
    int? episodeNumber,
    String? episodeId,
    String? episodeTitle,
    int? playbackPositionMs,
    int? totalDurationMs,
    int? chapterNumber,
    String? chapterId,
    String? chapterTitle,
    int? volumeNumber,
    int? pageNumber,
    int? totalPages,
    String? livestreamId,
    bool? wasLive,
    DateTime? createdAt,
    DateTime? lastPlayedAt,
    DateTime? completedAt,
  }) {
    return WatchHistoryEntry(
      id: id ?? this.id,
      mediaId: mediaId ?? this.mediaId,
      normalizedId: normalizedId ?? this.normalizedId,
      mediaType: mediaType ?? this.mediaType,
      title: title ?? this.title,
      coverImage: coverImage ?? this.coverImage,
      sourceId: sourceId ?? this.sourceId,
      sourceName: sourceName ?? this.sourceName,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      episodeId: episodeId ?? this.episodeId,
      episodeTitle: episodeTitle ?? this.episodeTitle,
      playbackPositionMs: playbackPositionMs ?? this.playbackPositionMs,
      totalDurationMs: totalDurationMs ?? this.totalDurationMs,
      chapterNumber: chapterNumber ?? this.chapterNumber,
      chapterId: chapterId ?? this.chapterId,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      volumeNumber: volumeNumber ?? this.volumeNumber,
      pageNumber: pageNumber ?? this.pageNumber,
      totalPages: totalPages ?? this.totalPages,
      livestreamId: livestreamId ?? this.livestreamId,
      wasLive: wasLive ?? this.wasLive,
      createdAt: createdAt ?? this.createdAt,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    mediaId,
    normalizedId,
    mediaType,
    title,
    coverImage,
    sourceId,
    sourceName,
    episodeNumber,
    episodeId,
    episodeTitle,
    playbackPositionMs,
    totalDurationMs,
    chapterNumber,
    chapterId,
    chapterTitle,
    volumeNumber,
    pageNumber,
    totalPages,
    livestreamId,
    wasLive,
    createdAt,
    lastPlayedAt,
    completedAt,
  ];
}
