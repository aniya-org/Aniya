import 'media_entity.dart';
import 'chapter_entity.dart';

class ChapterPageRequest {
  final MediaEntity media;
  final int offset;
  final int limit;
  final String? providerId;
  final String? providerMediaId;

  const ChapterPageRequest({
    required this.media,
    this.offset = 0,
    this.limit = 20,
    this.providerId,
    this.providerMediaId,
  });

  ChapterPageRequest copyWith({
    int? offset,
    int? limit,
    String? providerId,
    String? providerMediaId,
  }) {
    return ChapterPageRequest(
      media: media,
      offset: offset ?? this.offset,
      limit: limit ?? this.limit,
      providerId: providerId ?? this.providerId,
      providerMediaId: providerMediaId ?? this.providerMediaId,
    );
  }
}

class ChapterPageResult {
  final List<ChapterEntity> chapters;
  final int? nextOffset;
  final String providerId;
  final String providerMediaId;

  const ChapterPageResult({
    required this.chapters,
    required this.providerId,
    required this.providerMediaId,
    this.nextOffset,
  });

  bool get hasMore => nextOffset != null;
}
