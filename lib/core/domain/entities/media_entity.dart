import 'package:equatable/equatable.dart';

enum MediaType { anime, manga, novel, movie, tvShow }

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
  final String sourceId;
  final String sourceName;

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
    required this.sourceId,
    required this.sourceName,
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
    sourceId,
    sourceName,
  ];
}
