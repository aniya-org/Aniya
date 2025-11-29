import 'package:equatable/equatable.dart';

/// Entity representing a content source (streaming link, manga reader link, etc.)
class SourceEntity extends Equatable {
  /// Unique identifier for the source
  final String id;

  /// Display name of the source (e.g., "HiAnime", "Gogoanime")
  final String name;

  /// The extension/provider identifier used to fetch the content
  final String providerId;

  /// Video/content quality (e.g., "1080p", "720p", "480p")
  final String? quality;

  /// Language of the content (e.g., "English", "Japanese")
  final String? language;

  /// Direct link to the playable/readable content
  final String sourceLink;

  /// Optional HTTP headers required to access the source
  final Map<String, String>? headers;

  const SourceEntity({
    required this.id,
    required this.name,
    required this.providerId,
    this.quality,
    this.language,
    required this.sourceLink,
    this.headers,
  });

  /// Creates a copy of this source with the given fields replaced.
  SourceEntity copyWith({
    String? id,
    String? name,
    String? providerId,
    String? quality,
    String? language,
    String? sourceLink,
    Map<String, String>? headers,
  }) {
    return SourceEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      providerId: providerId ?? this.providerId,
      quality: quality ?? this.quality,
      language: language ?? this.language,
      sourceLink: sourceLink ?? this.sourceLink,
      headers: headers ?? this.headers,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    providerId,
    quality,
    language,
    sourceLink,
    headers,
  ];
}
