import 'package:equatable/equatable.dart';

class EpisodeEntity extends Equatable {
  final String id;
  final String mediaId;
  final String title;
  final int number;
  final String? thumbnail;
  final int? duration;
  final DateTime? releaseDate;

  const EpisodeEntity({
    required this.id,
    required this.mediaId,
    required this.title,
    required this.number,
    this.thumbnail,
    this.duration,
    this.releaseDate,
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
  ];
}
