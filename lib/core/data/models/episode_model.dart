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
    super.seasonNumber,
    super.sourceProvider,
    super.alternativeData,
  });

  factory EpisodeModel.fromJson(Map<String, dynamic> json) {
    Map<String, EpisodeData>? alternativeData;
    if (json['alternativeData'] != null) {
      final altDataMap = json['alternativeData'] as Map<String, dynamic>;
      alternativeData = altDataMap.map(
        (key, value) => MapEntry(
          key,
          EpisodeData(
            title: value['title'] as String?,
            thumbnail: value['thumbnail'] as String?,
            description: value['description'] as String?,
            airDate: value['airDate'] != null
                ? DateTime.parse(value['airDate'] as String)
                : null,
          ),
        ),
      );
    }

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
      seasonNumber: json['seasonNumber'] as int?,
      sourceProvider: json['sourceProvider'] as String?,
      alternativeData: alternativeData,
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic>? alternativeDataJson;
    if (alternativeData != null) {
      alternativeDataJson = alternativeData!.map(
        (key, value) => MapEntry(key, {
          'title': value.title,
          'thumbnail': value.thumbnail,
          'description': value.description,
          'airDate': value.airDate?.toIso8601String(),
        }),
      );
    }

    return {
      'id': id,
      'mediaId': mediaId,
      'title': title,
      'number': number,
      'thumbnail': thumbnail,
      'duration': duration,
      'releaseDate': releaseDate?.toIso8601String(),
      'seasonNumber': seasonNumber,
      'sourceProvider': sourceProvider,
      'alternativeData': alternativeDataJson,
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
      seasonNumber: seasonNumber,
      sourceProvider: sourceProvider,
      alternativeData: alternativeData,
    );
  }

  EpisodeModel copyWith({
    String? id,
    String? mediaId,
    String? title,
    int? number,
    String? thumbnail,
    int? duration,
    DateTime? releaseDate,
    int? seasonNumber,
    String? sourceProvider,
    Map<String, EpisodeData>? alternativeData,
  }) {
    return EpisodeModel(
      id: id ?? this.id,
      mediaId: mediaId ?? this.mediaId,
      title: title ?? this.title,
      number: number ?? this.number,
      thumbnail: thumbnail ?? this.thumbnail,
      duration: duration ?? this.duration,
      releaseDate: releaseDate ?? this.releaseDate,
      seasonNumber: seasonNumber ?? this.seasonNumber,
      sourceProvider: sourceProvider ?? this.sourceProvider,
      alternativeData: alternativeData ?? this.alternativeData,
    );
  }
}
