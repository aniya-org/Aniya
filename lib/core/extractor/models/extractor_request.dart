import 'package:aniya/core/domain/entities/media_entity.dart';

/// Inspired by the ExtractorVideo/ExtractorAudio payloads from
/// ref/umbrella/src/features/plugins/data/model/media (TypeScript version).
/// Captures the data an extractor needs to resolve real media streams.
class ExtractorRequest {
  final Uri url;
  final ExtractorCategory category;
  final MediaType? mediaType;
  final String? referer;
  final Map<String, String>? headers;
  final String? mediaTitle;
  final String? serverName;

  const ExtractorRequest({
    required this.url,
    required this.category,
    this.mediaType,
    this.referer,
    this.headers,
    this.mediaTitle,
    this.serverName,
  });

  ExtractorRequest copyWith({
    Uri? url,
    ExtractorCategory? category,
    String? referer,
    Map<String, String>? headers,
    MediaType? mediaType,
    String? mediaTitle,
    String? serverName,
  }) {
    return ExtractorRequest(
      url: url ?? this.url,
      category: category ?? this.category,
      referer: referer ?? this.referer,
      headers: headers ?? this.headers,
      mediaType: mediaType ?? this.mediaType,
      mediaTitle: mediaTitle ?? this.mediaTitle,
      serverName: serverName ?? this.serverName,
    );
  }
}

/// Historical mapping of extractor payload types. We currently only support
/// video extraction but keep the enum ready for audio-based hosts.
enum ExtractorCategory { video, audio }
