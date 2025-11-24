import 'package:dartotsu_extension_bridge/dartotsu_extension_bridge.dart';
import '../../domain/entities/episode_entity.dart';

class EpisodeModel extends EpisodeEntity {
  const EpisodeModel({
    required super.id,
    required super.mediaId,
    required super.title,
    required super.number,
    super.thumbnail,
    super.duration,
    super.releaseDate,
  });

  factory EpisodeModel.fromJson(Map<String, dynamic> json) {
    return EpisodeModel(
      id: json['id'] as String,
      mediaId: json['mediaId'] as String,
      title: json['title'] as String,
      number: json['number'] as int,
      thumbnail: json['thumbnail'] as String?,
      duration: json['duration'] as int?,
      releaseDate: json['releaseDate'] != null
          ? DateTime.parse(json['releaseDate'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mediaId': mediaId,
      'title': title,
      'number': number,
      'thumbnail': thumbnail,
      'duration': duration,
      'releaseDate': releaseDate?.toIso8601String(),
    };
  }

  factory EpisodeModel.fromDEpisode(DEpisode dEpisode, String mediaId) {
    final episodeNumber = int.tryParse(dEpisode.episodeNumber) ?? 0;

    return EpisodeModel(
      id: dEpisode.url ?? '',
      mediaId: mediaId,
      title: dEpisode.name ?? 'Episode $episodeNumber',
      number: episodeNumber,
      thumbnail: dEpisode.thumbnail,
      duration: null,
      releaseDate: dEpisode.dateUpload != null
          ? DateTime.tryParse(dEpisode.dateUpload!)
          : null,
    );
  }

  EpisodeEntity toEntity() {
    return EpisodeEntity(
      id: id,
      mediaId: mediaId,
      title: title,
      number: number,
      thumbnail: thumbnail,
      duration: duration,
      releaseDate: releaseDate,
    );
  }
}
