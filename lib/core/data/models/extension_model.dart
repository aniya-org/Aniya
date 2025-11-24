import 'package:dartotsu_extension_bridge/ExtensionManager.dart' as bridge;
import 'package:dartotsu_extension_bridge/Models/Source.dart';
import '../../domain/entities/extension_entity.dart';

class ExtensionModel extends ExtensionEntity {
  const ExtensionModel({
    required super.id,
    required super.name,
    required super.version,
    required super.type,
    required super.language,
    required super.isInstalled,
    required super.isNsfw,
    super.iconUrl,
  });

  factory ExtensionModel.fromJson(Map<String, dynamic> json) {
    return ExtensionModel(
      id: json['id'] as String,
      name: json['name'] as String,
      version: json['version'] as String,
      type: ExtensionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ExtensionType.cloudstream,
      ),
      language: json['language'] as String,
      isInstalled: json['isInstalled'] as bool,
      isNsfw: json['isNsfw'] as bool,
      iconUrl: json['iconUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'version': version,
      'type': type.name,
      'language': language,
      'isInstalled': isInstalled,
      'isNsfw': isNsfw,
      'iconUrl': iconUrl,
    };
  }

  factory ExtensionModel.fromSource(
    Source source,
    bridge.ExtensionType bridgeType,
  ) {
    return ExtensionModel(
      id: source.id ?? '',
      name: source.name ?? '',
      version: source.version ?? '0.0.1',
      type: _mapBridgeTypeToEntityType(bridgeType),
      language: source.lang ?? 'en',
      isInstalled: true, // If we have the source, it's installed
      isNsfw: source.isNsfw ?? false,
      iconUrl: source.iconUrl,
    );
  }

  static ExtensionType _mapBridgeTypeToEntityType(
    bridge.ExtensionType bridgeType,
  ) {
    switch (bridgeType) {
      case bridge.ExtensionType.cloudstream:
        return ExtensionType.cloudstream;
      case bridge.ExtensionType.aniyomi:
        return ExtensionType.aniyomi;
      case bridge.ExtensionType.mangayomi:
        return ExtensionType.mangayomi;
      case bridge.ExtensionType.lnreader:
        return ExtensionType.lnreader;
    }
  }

  ExtensionEntity toEntity() {
    return ExtensionEntity(
      id: id,
      name: name,
      version: version,
      type: type,
      language: language,
      isInstalled: isInstalled,
      isNsfw: isNsfw,
      iconUrl: iconUrl,
    );
  }

  ExtensionModel copyWith({
    String? id,
    String? name,
    String? version,
    ExtensionType? type,
    String? language,
    bool? isInstalled,
    bool? isNsfw,
    String? iconUrl,
  }) {
    return ExtensionModel(
      id: id ?? this.id,
      name: name ?? this.name,
      version: version ?? this.version,
      type: type ?? this.type,
      language: language ?? this.language,
      isInstalled: isInstalled ?? this.isInstalled,
      isNsfw: isNsfw ?? this.isNsfw,
      iconUrl: iconUrl ?? this.iconUrl,
    );
  }
}
