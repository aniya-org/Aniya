import '../../domain/entities/library_item_entity.dart';
import '../../domain/entities/media_entity.dart';
import 'media_model.dart';

class LibraryItemModel extends LibraryItemEntity {
  const LibraryItemModel({
    required super.id,
    required super.media,
    required super.status,
    required super.currentEpisode,
    required super.currentChapter,
    required super.addedAt,
    super.lastUpdated,
  });

  factory LibraryItemModel.fromJson(Map<String, dynamic> json) {
    return LibraryItemModel(
      id: json['id'] as String,
      media: MediaModel.fromJson(json['media'] as Map<String, dynamic>),
      status: LibraryStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => LibraryStatus.planToWatch,
      ),
      currentEpisode: json['currentEpisode'] as int,
      currentChapter: json['currentChapter'] as int,
      addedAt: DateTime.parse(json['addedAt'] as String),
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'media': (media as MediaModel).toJson(),
      'status': status.name,
      'currentEpisode': currentEpisode,
      'currentChapter': currentChapter,
      'addedAt': addedAt.toIso8601String(),
      'lastUpdated': lastUpdated?.toIso8601String(),
    };
  }

  LibraryItemEntity toEntity() {
    return LibraryItemEntity(
      id: id,
      media: media,
      status: status,
      currentEpisode: currentEpisode,
      currentChapter: currentChapter,
      addedAt: addedAt,
      lastUpdated: lastUpdated,
    );
  }

  LibraryItemModel copyWith({
    String? id,
    MediaEntity? media,
    LibraryStatus? status,
    int? currentEpisode,
    int? currentChapter,
    DateTime? addedAt,
    DateTime? lastUpdated,
  }) {
    return LibraryItemModel(
      id: id ?? this.id,
      media: media ?? this.media,
      status: status ?? this.status,
      currentEpisode: currentEpisode ?? this.currentEpisode,
      currentChapter: currentChapter ?? this.currentChapter,
      addedAt: addedAt ?? this.addedAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
