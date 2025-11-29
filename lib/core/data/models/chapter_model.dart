import 'package:dartotsu_extension_bridge/dartotsu_extension_bridge.dart';
import '../../domain/entities/chapter_entity.dart';

class ChapterModel extends ChapterEntity {
  const ChapterModel({
    required super.id,
    required super.mediaId,
    required super.title,
    required super.number,
    super.releaseDate,
    super.pageCount,
    super.sourceProvider,
  });

  factory ChapterModel.fromJson(Map<String, dynamic> json) {
    return ChapterModel(
      id: json['id'] as String,
      mediaId: json['mediaId'] as String,
      title: json['title'] as String,
      number: (json['number'] as num).toDouble(),
      releaseDate: json['releaseDate'] != null
          ? DateTime.parse(json['releaseDate'] as String)
          : null,
      pageCount: json['pageCount'] as int?,
      sourceProvider: json['sourceProvider'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mediaId': mediaId,
      'title': title,
      'number': number,
      'releaseDate': releaseDate?.toIso8601String(),
      'pageCount': pageCount,
      'sourceProvider': sourceProvider,
    };
  }

  factory ChapterModel.fromDEpisode(
    DEpisode dEpisode,
    String mediaId, {
    String? sourceProvider,
  }) {
    final chapterNumber = double.tryParse(dEpisode.episodeNumber) ?? 0.0;

    return ChapterModel(
      id: dEpisode.url ?? '',
      mediaId: mediaId,
      title: dEpisode.name ?? 'Chapter $chapterNumber',
      number: chapterNumber,
      releaseDate: dEpisode.dateUpload != null
          ? DateTime.tryParse(dEpisode.dateUpload!)
          : null,
      pageCount: null,
      sourceProvider: sourceProvider,
    );
  }

  ChapterEntity toEntity() {
    return ChapterEntity(
      id: id,
      mediaId: mediaId,
      title: title,
      number: number,
      releaseDate: releaseDate,
      pageCount: pageCount,
      sourceProvider: sourceProvider,
    );
  }
}
