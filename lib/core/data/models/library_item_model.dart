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
    super.mediaType,
    super.normalizedId,
    super.sourceId,
    super.sourceName,
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

    MediaType? mediaType;
    if (json['mediaType'] != null) {
      mediaType = MediaType.values.firstWhere(
        (e) => e.name == json['mediaType'],
        orElse: () => MediaType.anime,
      );
    }

    Map<String, dynamic>? _coerceToStringMap(dynamic value) {
      if (value is Map<String, dynamic>) {
        return value;
      }
      if (value is Map) {
        return value.map((key, val) => MapEntry(key.toString(), val));
      }
      return null;
    }

    MediaModel? media;
    final rawMedia = json['media'];
    if (rawMedia != null) {
      final mediaMap = _coerceToStringMap(rawMedia);
      if (mediaMap != null) {
        media = MediaModel.fromJson(mediaMap);
      }
    }

    return LibraryItemModel(
      id: json['id'] as String,
      mediaId: mediaId,
      userService: userService,
      media: media,
      mediaType: mediaType,
      normalizedId: json['normalizedId'] as String?,
      sourceId: json['sourceId'] as String?,
      sourceName: json['sourceName'] as String?,
      status: LibraryStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => LibraryStatus.planToWatch,
      ),
      progress: WatchProgress(
        currentEpisode: json['currentEpisode'] as int?,
        currentChapter: json['currentChapter'] as int?,
        currentVolume: json['currentVolume'] as int?,
        startedAt: json['startedAt'] != null
            ? DateTime.parse(json['startedAt'] as String)
            : null,
        completedAt: json['completedAt'] != null
            ? DateTime.parse(json['completedAt'] as String)
            : null,
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : null,
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
      'media': media != null ? (media as MediaModel).toJson() : null,
      'mediaType': mediaType?.name,
      'normalizedId': normalizedId,
      'sourceId': sourceId,
      'sourceName': sourceName,
      'status': status.name,
      'currentEpisode': progress?.currentEpisode,
      'currentChapter': progress?.currentChapter,
      'currentVolume': progress?.currentVolume,
      'startedAt': progress?.startedAt?.toIso8601String(),
      'completedAt': progress?.completedAt?.toIso8601String(),
      'updatedAt': progress?.updatedAt?.toIso8601String(),
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
      mediaType: mediaType,
      normalizedId: normalizedId,
      sourceId: sourceId,
      sourceName: sourceName,
      status: status,
      progress: progress,
      addedAt: addedAt,
      lastUpdated: lastUpdated,
    );
  }

  /// Create from entity
  factory LibraryItemModel.fromEntity(LibraryItemEntity entity) {
    return LibraryItemModel(
      id: entity.id,
      mediaId: entity.mediaId,
      userService: entity.userService,
      media: entity.media,
      mediaType: entity.mediaType,
      normalizedId: entity.normalizedId,
      sourceId: entity.sourceId,
      sourceName: entity.sourceName,
      status: entity.status,
      progress: entity.progress ?? const WatchProgress(),
      addedAt: entity.addedAt,
      lastUpdated: entity.lastUpdated,
    );
  }

  @override
  LibraryItemModel copyWith({
    String? id,
    String? mediaId,
    TrackingService? userService,
    MediaEntity? media,
    MediaType? mediaType,
    String? normalizedId,
    String? sourceId,
    String? sourceName,
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
      mediaType: mediaType ?? this.mediaType,
      normalizedId: normalizedId ?? this.normalizedId,
      sourceId: sourceId ?? this.sourceId,
      sourceName: sourceName ?? this.sourceName,
      status: status ?? this.status,
      progress: progress ?? this.progress ?? const WatchProgress(),
      addedAt: addedAt ?? this.addedAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
