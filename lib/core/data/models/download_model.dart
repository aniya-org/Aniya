import 'package:hive/hive.dart';
import '../../domain/entities/download_entity.dart';

part 'download_model.g.dart';

/// Data model for download items
/// Provides JSON serialization for DownloadEntity
@HiveType(typeId: 10)
class DownloadModel {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String mediaId;

  @HiveField(2)
  final String mediaTitle;

  @HiveField(3)
  final String? episodeId;

  @HiveField(4)
  final String? chapterId;

  @HiveField(5)
  final int? episodeNumber;

  @HiveField(6)
  final double? chapterNumber;

  @HiveField(7)
  final String url;

  @HiveField(8)
  final String localPath;

  @HiveField(9)
  final int statusIndex;

  @HiveField(10)
  final double progress;

  @HiveField(11)
  final int totalBytes;

  @HiveField(12)
  final int downloadedBytes;

  @HiveField(13)
  final DateTime createdAt;

  @HiveField(14)
  final DateTime? completedAt;

  const DownloadModel({
    required this.id,
    required this.mediaId,
    required this.mediaTitle,
    this.episodeId,
    this.chapterId,
    this.episodeNumber,
    this.chapterNumber,
    required this.url,
    required this.localPath,
    required this.statusIndex,
    required this.progress,
    required this.totalBytes,
    required this.downloadedBytes,
    required this.createdAt,
    this.completedAt,
  });

  /// Get the download status
  DownloadStatus get status => DownloadStatus.values[statusIndex];

  /// Create from entity
  factory DownloadModel.fromEntity(DownloadEntity entity) {
    return DownloadModel(
      id: entity.id,
      mediaId: entity.mediaId,
      mediaTitle: entity.mediaTitle,
      episodeId: entity.episodeId,
      chapterId: entity.chapterId,
      episodeNumber: entity.episodeNumber,
      chapterNumber: entity.chapterNumber,
      url: entity.url,
      localPath: entity.localPath,
      statusIndex: entity.status.index,
      progress: entity.progress,
      totalBytes: entity.totalBytes,
      downloadedBytes: entity.downloadedBytes,
      createdAt: entity.createdAt,
      completedAt: entity.completedAt,
    );
  }

  /// Create from JSON
  factory DownloadModel.fromJson(Map<String, dynamic> json) {
    return DownloadModel(
      id: json['id'] as String,
      mediaId: json['mediaId'] as String,
      mediaTitle: json['mediaTitle'] as String,
      episodeId: json['episodeId'] as String?,
      chapterId: json['chapterId'] as String?,
      episodeNumber: json['episodeNumber'] as int?,
      chapterNumber: json['chapterNumber'] as double?,
      url: json['url'] as String,
      localPath: json['localPath'] as String,
      statusIndex: json['statusIndex'] as int,
      progress: (json['progress'] as num).toDouble(),
      totalBytes: json['totalBytes'] as int,
      downloadedBytes: json['downloadedBytes'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mediaId': mediaId,
      'mediaTitle': mediaTitle,
      'episodeId': episodeId,
      'chapterId': chapterId,
      'episodeNumber': episodeNumber,
      'chapterNumber': chapterNumber,
      'url': url,
      'localPath': localPath,
      'statusIndex': statusIndex,
      'progress': progress,
      'totalBytes': totalBytes,
      'downloadedBytes': downloadedBytes,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  /// Convert to entity
  DownloadEntity toEntity() {
    return DownloadEntity(
      id: id,
      mediaId: mediaId,
      mediaTitle: mediaTitle,
      episodeId: episodeId,
      chapterId: chapterId,
      episodeNumber: episodeNumber,
      chapterNumber: chapterNumber,
      url: url,
      localPath: localPath,
      status: DownloadStatus.values[statusIndex],
      progress: progress,
      totalBytes: totalBytes,
      downloadedBytes: downloadedBytes,
      createdAt: createdAt,
      completedAt: completedAt,
    );
  }

  /// Copy with
  DownloadModel copyWith({
    String? id,
    String? mediaId,
    String? mediaTitle,
    String? episodeId,
    String? chapterId,
    int? episodeNumber,
    double? chapterNumber,
    String? url,
    String? localPath,
    DownloadStatus? status,
    double? progress,
    int? totalBytes,
    int? downloadedBytes,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return DownloadModel(
      id: id ?? this.id,
      mediaId: mediaId ?? this.mediaId,
      mediaTitle: mediaTitle ?? this.mediaTitle,
      episodeId: episodeId ?? this.episodeId,
      chapterId: chapterId ?? this.chapterId,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      chapterNumber: chapterNumber ?? this.chapterNumber,
      url: url ?? this.url,
      localPath: localPath ?? this.localPath,
      statusIndex: status?.index ?? statusIndex,
      progress: progress ?? this.progress,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
