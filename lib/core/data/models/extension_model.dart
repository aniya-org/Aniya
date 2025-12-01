import 'package:dartotsu_extension_bridge/ExtensionManager.dart' as bridge;
import 'package:dartotsu_extension_bridge/Models/Source.dart' hide ItemType;
import '../../domain/entities/extension_entity.dart';

class ExtensionModel extends ExtensionEntity {
  const ExtensionModel({
    required super.id,
    required super.name,
    required super.version,
    super.versionLast,
    required super.type,
    super.itemType = ItemType.anime,
    required super.language,
    required super.isInstalled,
    required super.isNsfw,
    super.hasUpdate = false,
    super.iconUrl,
    super.apkUrl,
    super.description,
    super.isExecutableOnDesktop,
  });

  factory ExtensionModel.fromJson(Map<String, dynamic> json) {
    return ExtensionModel(
      id: json['id'] as String,
      name: json['name'] as String,
      version: json['version'] as String,
      versionLast: json['versionLast'] as String?,
      type: ExtensionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ExtensionType.cloudstream,
      ),
      itemType: json['itemType'] != null
          ? ItemType.values.firstWhere(
              (e) => e.name == json['itemType'],
              orElse: () => ItemType.anime,
            )
          : ItemType.anime,
      language: json['language'] as String,
      isInstalled: json['isInstalled'] as bool,
      isNsfw: json['isNsfw'] as bool,
      hasUpdate: json['hasUpdate'] as bool? ?? false,
      iconUrl: json['iconUrl'] as String?,
      apkUrl: json['apkUrl'] as String?,
      description: json['description'] as String?,
      isExecutableOnDesktop: json['isExecutableOnDesktop'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'version': version,
      'versionLast': versionLast,
      'type': type.name,
      'itemType': itemType.name,
      'language': language,
      'isInstalled': isInstalled,
      'isNsfw': isNsfw,
      'hasUpdate': hasUpdate,
      'iconUrl': iconUrl,
      'apkUrl': apkUrl,
      'description': description,
      'isExecutableOnDesktop': isExecutableOnDesktop,
    };
  }

  factory ExtensionModel.fromSource(
    Source source,
    bridge.ExtensionType bridgeType, {
    bool isInstalled = true,
  }) {
    return ExtensionModel(
      id: source.id ?? '',
      name: source.name ?? '',
      version: source.version ?? '0.0.1',
      versionLast: source.versionLast,
      type: _mapBridgeTypeToEntityType(bridgeType),
      itemType: _mapSourceItemType(source.itemType),
      language: source.lang ?? 'en',
      isInstalled: isInstalled,
      isNsfw: source.isNsfw ?? false,
      hasUpdate: source.hasUpdate ?? false,
      iconUrl: source.iconUrl,
      apkUrl: source.apkUrl,
      description: null, // Source doesn't have description
      isExecutableOnDesktop: source.isExecutableOnDesktop,
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

  static ItemType _mapSourceItemType(dynamic sourceItemType) {
    if (sourceItemType == null) return ItemType.anime;

    // Handle both enum and index-based values from the bridge
    if (sourceItemType is int) {
      if (sourceItemType >= 0 && sourceItemType < ItemType.values.length) {
        return ItemType.values[sourceItemType];
      }
      return ItemType.anime;
    }

    // Try to match by name if it's a string or enum
    final name = sourceItemType.toString().split('.').last.toLowerCase();
    return ItemType.values.firstWhere(
      (e) => e.name.toLowerCase() == name,
      orElse: () => ItemType.anime,
    );
  }

  ExtensionEntity toEntity() {
    return ExtensionEntity(
      id: id,
      name: name,
      version: version,
      versionLast: versionLast,
      type: type,
      itemType: itemType,
      language: language,
      isInstalled: isInstalled,
      isNsfw: isNsfw,
      hasUpdate: hasUpdate,
      iconUrl: iconUrl,
      apkUrl: apkUrl,
      description: description,
      isExecutableOnDesktop: isExecutableOnDesktop,
    );
  }

  @override
  ExtensionModel copyWith({
    String? id,
    String? name,
    String? version,
    String? versionLast,
    ExtensionType? type,
    ItemType? itemType,
    String? language,
    bool? isInstalled,
    bool? isNsfw,
    bool? hasUpdate,
    String? iconUrl,
    String? apkUrl,
    String? description,
    bool? isExecutableOnDesktop,
  }) {
    return ExtensionModel(
      id: id ?? this.id,
      name: name ?? this.name,
      version: version ?? this.version,
      versionLast: versionLast ?? this.versionLast,
      type: type ?? this.type,
      itemType: itemType ?? this.itemType,
      language: language ?? this.language,
      isInstalled: isInstalled ?? this.isInstalled,
      isNsfw: isNsfw ?? this.isNsfw,
      hasUpdate: hasUpdate ?? this.hasUpdate,
      iconUrl: iconUrl ?? this.iconUrl,
      apkUrl: apkUrl ?? this.apkUrl,
      description: description ?? this.description,
      isExecutableOnDesktop:
          isExecutableOnDesktop ?? this.isExecutableOnDesktop,
    );
  }
}
