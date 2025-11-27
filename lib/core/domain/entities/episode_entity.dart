import 'package:equatable/equatable.dart';

class EpisodeData extends Equatable {
  final String? title;
  final String? thumbnail;
  final String? description;
  final DateTime? airDate;

  const EpisodeData({
    this.title,
    this.thumbnail,
    this.description,
    this.airDate,
  });

  @override
  List<Object?> get props => [title, thumbnail, description, airDate];

  EpisodeData copyWith({
    String? title,
    String? thumbnail,
    String? description,
    DateTime? airDate,
  }) {
    return EpisodeData(
      title: title ?? this.title,
      thumbnail: thumbnail ?? this.thumbnail,
      description: description ?? this.description,
      airDate: airDate ?? this.airDate,
    );
  }
}

class EpisodeEntity extends Equatable {
  final String id;
  final String mediaId;
  final String title;
  final int number;
  final String? thumbnail;
  final int? duration;
  final DateTime? releaseDate;

  /// Provider that supplied this episode data
  final String? sourceProvider;

  /// Alternative episode data from other providers
  final Map<String, EpisodeData>? alternativeData;

  const EpisodeEntity({
    required this.id,
    required this.mediaId,
    required this.title,
    required this.number,
    this.thumbnail,
    this.duration,
    this.releaseDate,
    this.sourceProvider,
    this.alternativeData,
  });

  @override
  List<Object?> get props => [
    id,
    mediaId,
    title,
    number,
    thumbnail,
    duration,
    releaseDate,
    sourceProvider,
    alternativeData,
  ];

  EpisodeEntity copyWith({
    String? id,
    String? mediaId,
    String? title,
    int? number,
    String? thumbnail,
    int? duration,
    DateTime? releaseDate,
    String? sourceProvider,
    Map<String, EpisodeData>? alternativeData,
  }) {
    return EpisodeEntity(
      id: id ?? this.id,
      mediaId: mediaId ?? this.mediaId,
      title: title ?? this.title,
      number: number ?? this.number,
      thumbnail: thumbnail ?? this.thumbnail,
      duration: duration ?? this.duration,
      releaseDate: releaseDate ?? this.releaseDate,
      sourceProvider: sourceProvider ?? this.sourceProvider,
      alternativeData: alternativeData ?? this.alternativeData,
    );
  }
}
