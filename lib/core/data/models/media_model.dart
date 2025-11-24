import 'package:dartotsu_extension_bridge/dartotsu_extension_bridge.dart';
import '../../domain/entities/media_entity.dart';

class MediaModel extends MediaEntity {
  const MediaModel({
    required super.id,
    required super.title,
    super.coverImage,
    super.bannerImage,
    super.description,
    required super.type,
    super.rating,
    required super.genres,
    required super.status,
    super.totalEpisodes,
    super.totalChapters,
    required super.sourceId,
    required super.sourceName,
  });

  factory MediaModel.fromJson(Map<String, dynamic> json) {
    return MediaModel(
      id: json['id'] as String,
      title: json['title'] as String,
      coverImage: json['coverImage'] as String?,
      bannerImage: json['bannerImage'] as String?,
      description: json['description'] as String?,
      type: MediaType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MediaType.anime,
      ),
      rating: json['rating'] != null
          ? (json['rating'] as num).toDouble()
          : null,
      genres:
          (json['genres'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      status: MediaStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => MediaStatus.ongoing,
      ),
      totalEpisodes: json['totalEpisodes'] as int?,
      totalChapters: json['totalChapters'] as int?,
      sourceId: json['sourceId'] as String,
      sourceName: json['sourceName'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'coverImage': coverImage,
      'bannerImage': bannerImage,
      'description': description,
      'type': type.name,
      'rating': rating,
      'genres': genres,
      'status': status.name,
      'totalEpisodes': totalEpisodes,
      'totalChapters': totalChapters,
      'sourceId': sourceId,
      'sourceName': sourceName,
    };
  }

  factory MediaModel.fromDMedia(
    DMedia dMedia,
    String sourceId,
    String sourceName,
  ) {
    // Infer type from episodes - if present, could be anime/manga
    // This is a simplified approach; in production, you'd check the source type
    final hasEpisodes = dMedia.episodes != null && dMedia.episodes!.isNotEmpty;

    return MediaModel(
      id: dMedia.url ?? '',
      title: dMedia.title ?? '',
      coverImage: dMedia.cover,
      bannerImage: null,
      description: dMedia.description,
      type: hasEpisodes ? MediaType.anime : MediaType.manga,
      rating: null,
      genres: dMedia.genre ?? [],
      status: MediaStatus.ongoing,
      totalEpisodes: dMedia.episodes?.length,
      totalChapters: dMedia.episodes?.length,
      sourceId: sourceId,
      sourceName: sourceName,
    );
  }

  MediaEntity toEntity() {
    return MediaEntity(
      id: id,
      title: title,
      coverImage: coverImage,
      bannerImage: bannerImage,
      description: description,
      type: type,
      rating: rating,
      genres: genres,
      status: status,
      totalEpisodes: totalEpisodes,
      totalChapters: totalChapters,
      sourceId: sourceId,
      sourceName: sourceName,
    );
  }
}
