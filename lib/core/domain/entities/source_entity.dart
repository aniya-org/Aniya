import 'package:equatable/equatable.dart';

/// Entity representing a content source (streaming link, manga reader link, etc.)
class SourceEntity extends Equatable {
  /// Unique identifier for the source
  final String id;

  /// Display name of the source (e.g., "HiAnime", "Gogoanime")
  final String name;

  /// Video/content quality (e.g., "1080p", "720p", "480p")
  final String? quality;

  /// Language of the content (e.g., "English", "Japanese")
  final String? language;

  /// Direct link to the playable/readable content
  final String sourceLink;

  const SourceEntity({
    required this.id,
    required this.name,
    this.quality,
    this.language,
    required this.sourceLink,
  });

  /// Creates a copy of this source with the given fields replaced.
  SourceEntity copyWith({
    String? id,
    String? name,
    String? quality,
    String? language,
    String? sourceLink,
  }) {
    return SourceEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      quality: quality ?? this.quality,
      language: language ?? this.language,
      sourceLink: sourceLink ?? this.sourceLink,
    );
  }

  @override
  List<Object?> get props => [id, name, quality, language, sourceLink];
}
