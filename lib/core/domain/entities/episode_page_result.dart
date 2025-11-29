import 'media_entity.dart';
import 'episode_entity.dart';

class EpisodePageRequest {
  final MediaEntity media;
  final int offset;
  final int limit;
  final String? providerId;
  final String? providerMediaId;

  const EpisodePageRequest({
    required this.media,
    this.offset = 0,
    this.limit = 50,
    this.providerId,
    this.providerMediaId,
  });

  EpisodePageRequest copyWith({
    int? offset,
    int? limit,
    String? providerId,
    String? providerMediaId,
  }) {
    return EpisodePageRequest(
      media: media,
      offset: offset ?? this.offset,
      limit: limit ?? this.limit,
      providerId: providerId ?? this.providerId,
      providerMediaId: providerMediaId ?? this.providerMediaId,
    );
  }
}

class EpisodePageResult {
  final List<EpisodeEntity> episodes;
  final int? nextOffset;
  final String providerId;
  final String providerMediaId;

  const EpisodePageResult({
    required this.episodes,
    required this.providerId,
    required this.providerMediaId,
    this.nextOffset,
  });

  bool get hasMore => nextOffset != null;
}
