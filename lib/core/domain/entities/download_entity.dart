/// Domain entity representing a download item
class DownloadEntity {
  final String id;
  final String mediaId;
  final String mediaTitle;
  final String? episodeId;
  final String? chapterId;
  final int? episodeNumber;
  final double? chapterNumber;
  final String url;
  final String localPath;
  final DownloadStatus status;
  final double progress;
  final int totalBytes;
  final int downloadedBytes;
  final DateTime createdAt;
  final DateTime? completedAt;

  const DownloadEntity({
    required this.id,
    required this.mediaId,
    required this.mediaTitle,
    this.episodeId,
    this.chapterId,
    this.episodeNumber,
    this.chapterNumber,
    required this.url,
    required this.localPath,
    required this.status,
    required this.progress,
    required this.totalBytes,
    required this.downloadedBytes,
    required this.createdAt,
    this.completedAt,
  });

  DownloadEntity copyWith({
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
    return DownloadEntity(
      id: id ?? this.id,
      mediaId: mediaId ?? this.mediaId,
      mediaTitle: mediaTitle ?? this.mediaTitle,
      episodeId: episodeId ?? this.episodeId,
      chapterId: chapterId ?? this.chapterId,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      chapterNumber: chapterNumber ?? this.chapterNumber,
      url: url ?? this.url,
      localPath: localPath ?? this.localPath,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

/// Status of a download
enum DownloadStatus {
  queued,
  downloading,
  paused,
  completed,
  failed,
  cancelled,
}
