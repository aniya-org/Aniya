import '../../domain/entities/library_item_entity.dart';
import '../../domain/entities/media_entity.dart';
import '../../enums/tracking_service.dart';
import 'media_model.dart';

class LibraryItemModel extends LibraryItemEntity {
  const LibraryItemModel({
    required super.id,
    required super.mediaId,
    required super.userService,
    super.media,
    required super.status,
    required super.addedAt,
    super.lastUpdated,
    required WatchProgress progress,
  }) : super(progress: progress);

  factory LibraryItemModel.fromJson(Map<String, dynamic> json) {
    final mediaId = json['mediaId'] as String? ?? json['media']['id'] as String;
    final userService = TrackingService.values.firstWhere(
      (e) => e.name == json['userService'],
      orElse: () => TrackingService.anilist,
    );

    return LibraryItemModel(
      id: json['id'] as String,
      mediaId: mediaId,
      userService: userService,
      media: MediaModel.fromJson(json['media'] as Map<String, dynamic>),
      status: LibraryStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => LibraryStatus.planToWatch,
      ),
      progress: WatchProgress(
        currentEpisode: json['currentEpisode'] as int?,
        currentChapter: json['currentChapter'] as int?,
      ),
      addedAt: DateTime.parse(json['addedAt'] as String),
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mediaId': mediaId,
      'userService': userService.name,
      'media': (media as MediaModel).toJson(),
      'status': status.name,
      'currentEpisode': progress?.currentEpisode,
      'currentChapter': progress?.currentChapter,
      'addedAt': addedAt!.toIso8601String(),
      'lastUpdated': lastUpdated?.toIso8601String(),
    };
  }

  LibraryItemEntity toEntity() {
    return LibraryItemEntity(
      id: id,
      mediaId: mediaId,
      userService: userService,
      media: media,
      status: status,
      progress: progress,
      addedAt: addedAt,
      lastUpdated: lastUpdated,
    );
  }

  @override
  LibraryItemModel copyWith({
    String? id,
    String? mediaId,
    TrackingService? userService,
    MediaEntity? media,
    LibraryStatus? status,
    UserScore? score,
    WatchProgress? progress,
    UserNotes? notes,
    DateTime? addedAt,
    DateTime? lastUpdated,
  }) {
    return LibraryItemModel(
      id: id ?? this.id,
      mediaId: mediaId ?? this.mediaId,
      userService: userService ?? this.userService,
      media: media ?? this.media,
      status: status ?? this.status,
      progress: progress ?? this.progress!,
      addedAt: addedAt ?? this.addedAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
