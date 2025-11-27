import '../../domain/entities/source_entity.dart';

/// Model for source data
/// Extends SourceEntity to provide serialization capabilities
class SourceModel extends SourceEntity {
  const SourceModel({
    required super.id,
    required super.name,
    super.quality,
    super.language,
    required super.sourceLink,
  });

  /// Create a SourceModel from JSON
  factory SourceModel.fromJson(Map<String, dynamic> json) {
    return SourceModel(
      id: json['id'] as String,
      name: json['name'] as String,
      quality: json['quality'] as String?,
      language: json['language'] as String?,
      sourceLink: json['sourceLink'] as String,
    );
  }

  /// Convert SourceModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'quality': quality,
      'language': language,
      'sourceLink': sourceLink,
    };
  }

  /// Convert to entity (already is an entity, but for consistency)
  SourceEntity toEntity() => this;

  /// Create a copy with optional field replacements
  SourceModel copyWith({
    String? id,
    String? name,
    String? quality,
    String? language,
    String? sourceLink,
  }) {
    return SourceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      quality: quality ?? this.quality,
      language: language ?? this.language,
      sourceLink: sourceLink ?? this.sourceLink,
    );
  }
}
