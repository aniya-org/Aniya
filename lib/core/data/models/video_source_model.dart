import '../../domain/entities/video_source_entity.dart';

class VideoSourceModel extends VideoSource {
  const VideoSourceModel({
    required super.id,
    required super.name,
    required super.url,
    required super.quality,
    required super.server,
    super.headers,
  });

  factory VideoSourceModel.fromJson(Map<String, dynamic> json) {
    return VideoSourceModel(
      id: json['id'] as String,
      name: json['name'] as String,
      url: json['url'] as String,
      quality: json['quality'] as String,
      server: json['server'] as String,
      headers: json['headers'] != null
          ? Map<String, String>.from(json['headers'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'quality': quality,
      'server': server,
      'headers': headers,
    };
  }

  VideoSource toEntity() {
    return VideoSource(
      id: id,
      name: name,
      url: url,
      quality: quality,
      server: server,
      headers: headers,
    );
  }

  VideoSourceModel copyWith({
    String? id,
    String? name,
    String? url,
    String? quality,
    String? server,
    Map<String, String>? headers,
  }) {
    return VideoSourceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      quality: quality ?? this.quality,
      server: server ?? this.server,
      headers: headers ?? this.headers,
    );
  }
}
