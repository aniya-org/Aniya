import 'package:equatable/equatable.dart';

class VideoSource extends Equatable {
  final String id;
  final String name;
  final String url;
  final String quality;
  final String server;
  final Map<String, String>? headers;

  const VideoSource({
    required this.id,
    required this.name,
    required this.url,
    required this.quality,
    required this.server,
    this.headers,
  });

  @override
  List<Object?> get props => [id, name, url, quality, server, headers];
}
