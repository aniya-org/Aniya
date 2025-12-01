import 'package:equatable/equatable.dart';

/// Comprehensive media type enum supporting all content categories
/// Used for library filtering and watch history tracking
enum MediaType {
  anime,
  manga,
  novel,
  movie,
  tvShow,
  cartoon,
  documentary,
  livestream,
  nsfw;

  /// Returns true if this is a video-based media type
  bool get isVideoType => switch (this) {
    MediaType.anime ||
    MediaType.movie ||
    MediaType.tvShow ||
    MediaType.cartoon ||
    MediaType.documentary ||
    MediaType.livestream => true,
    _ => false,
  };

  /// Returns true if this is a reading-based media type
  bool get isReadingType => switch (this) {
    MediaType.manga || MediaType.novel => true,
    _ => false,
  };

  /// Returns the display name for this media type
  String get displayName => switch (this) {
    MediaType.anime => 'Anime',
    MediaType.manga => 'Manga',
    MediaType.novel => 'Novel',
    MediaType.movie => 'Movie',
    MediaType.tvShow => 'TV Show',
    MediaType.cartoon => 'Cartoon',
    MediaType.documentary => 'Documentary',
    MediaType.livestream => 'Livestream',
    MediaType.nsfw => 'NSFW',
  };

  /// Returns the icon name for this media type
  String get iconName => switch (this) {
    MediaType.anime => 'play_circle',
    MediaType.manga => 'menu_book',
    MediaType.novel => 'auto_stories',
    MediaType.movie => 'movie',
    MediaType.tvShow => 'tv',
    MediaType.cartoon => 'animation',
    MediaType.documentary => 'documentary',
    MediaType.livestream => 'live_tv',
    MediaType.nsfw => 'eighteen_up_rating',
  };

  /// Maps CloudStream tvTypes to MediaType
  static MediaType? fromTvType(String tvType) => switch (tvType.toLowerCase()) {
    'anime' || 'animemovie' || 'ova' => MediaType.anime,
    'manga' => MediaType.manga,
    'audiobook' || 'audio' || 'podcast' => MediaType.novel,
    'movie' || 'torrent' => MediaType.movie,
    'tvseries' || 'asiandrama' => MediaType.tvShow,
    'cartoon' => MediaType.cartoon,
    'documentary' => MediaType.documentary,
    'live' => MediaType.livestream,
    'nsfw' => MediaType.nsfw,
    _ => null,
  };
}

enum MediaStatus { ongoing, completed, upcoming }

class MediaEntity extends Equatable {
  final String id;
  final String title;
  final String? coverImage;
  final String? bannerImage;
  final String? description;
  final MediaType type;
  final double? rating;
  final List<String> genres;
  final MediaStatus status;
  final int? totalEpisodes;
  final int? totalChapters;
  final DateTime? startDate;
  final String sourceId;
  final String sourceName;
  final MediaType? sourceType;

  const MediaEntity({
    required this.id,
    required this.title,
    this.coverImage,
    this.bannerImage,
    this.description,
    required this.type,
    this.rating,
    required this.genres,
    required this.status,
    this.totalEpisodes,
    this.totalChapters,
    this.startDate,
    required this.sourceId,
    required this.sourceName,
    this.sourceType,
  });

  @override
  List<Object?> get props => [
    id,
    title,
    coverImage,
    bannerImage,
    description,
    type,
    rating,
    genres,
    status,
    totalEpisodes,
    totalChapters,
    startDate,
    sourceId,
    sourceName,
    sourceType,
  ];
}
