import '../../domain/entities/source_entity.dart';

/// Model for source data
/// Extends SourceEntity to provide serialization capabilities
class SourceModel extends SourceEntity {
  const SourceModel({
    required super.id,
    required super.name,
    required super.providerId,
    super.quality,
    super.language,
    required super.sourceLink,
    super.headers,
  });

  /// Create a SourceModel from JSON
  factory SourceModel.fromJson(Map<String, dynamic> json) {
    return SourceModel(
      id: json['id'] as String,
      name: json['name'] as String,
      providerId: json['providerId'] as String,
      quality: json['quality'] as String?,
      language: json['language'] as String?,
      sourceLink: json['sourceLink'] as String,
      headers: json['headers'] != null
          ? Map<String, String>.from(json['headers'] as Map)
          : null,
    );
  }

  /// Convert SourceModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'providerId': providerId,
      'quality': quality,
      'language': language,
      'sourceLink': sourceLink,
      'headers': headers,
    };
  }

  /// Convert to entity (already is an entity, but for consistency)
  SourceEntity toEntity() => this;

  /// Create a copy with optional field replacements
  @override
  SourceModel copyWith({
    String? id,
    String? name,
    String? providerId,
    String? quality,
    String? language,
    String? sourceLink,
    Map<String, String>? headers,
  }) {
    return SourceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      providerId: providerId ?? this.providerId,
      quality: quality ?? this.quality,
      language: language ?? this.language,
      sourceLink: sourceLink ?? this.sourceLink,
      headers: headers ?? this.headers,
    );
  }
}
