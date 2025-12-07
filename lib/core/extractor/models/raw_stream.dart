import 'package:equatable/equatable.dart';

/// Mirrors the RawVideo/RawAudio interfaces from
/// ref/umbrella/src/features/plugins/data/model/media.
class RawStream extends Equatable {
  final Uri url;
  final bool isM3u8;
  final String? fileType;
  final String? quality;
  final String? sourceLabel;
  final Map<String, String>? headers;
  final List<SubtitleTrack> subtitles;

  const RawStream({
    required this.url,
    this.isM3u8 = false,
    this.fileType,
    this.quality,
    this.sourceLabel,
    this.headers,
    this.subtitles = const [],
  });

  RawStream copyWith({
    Uri? url,
    bool? isM3u8,
    String? fileType,
    String? quality,
    String? sourceLabel,
    Map<String, String>? headers,
    List<SubtitleTrack>? subtitles,
  }) {
    return RawStream(
      url: url ?? this.url,
      isM3u8: isM3u8 ?? this.isM3u8,
      fileType: fileType ?? this.fileType,
      quality: quality ?? this.quality,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      headers: headers ?? this.headers,
      subtitles: subtitles ?? this.subtitles,
    );
  }

  @override
  List<Object?> get props => [
    url,
    isM3u8,
    fileType,
    quality,
    sourceLabel,
    headers,
    subtitles,
  ];
}

class SubtitleTrack extends Equatable {
  final Uri url;
  final String? name;
  final String? language;
  final String? mimeType;

  const SubtitleTrack({
    required this.url,
    this.name,
    this.language,
    this.mimeType,
  });

  @override
  List<Object?> get props => [url, name, language, mimeType];
}
