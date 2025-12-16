import 'package:hive/hive.dart';
import 'package:dartotsu_extension_bridge/ExtensionManager.dart' as bridge;
import 'package:dartotsu_extension_bridge/Models/Source.dart' as bridge_models;

class AniyaEvalPlugin {
  final String id;
  final String name;
  final String version;
  final String language;
  final bridge_models.ItemType itemType;
  final String? url;
  final String sourceCode;
  final List<int>? bytecode;

  const AniyaEvalPlugin({
    required this.id,
    required this.name,
    required this.version,
    required this.language,
    required this.itemType,
    required this.sourceCode,
    this.url,
    this.bytecode,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'version': version,
    'language': language,
    'itemType': itemType.name,
    'url': url,
    'sourceCode': sourceCode,
    'bytecode': bytecode,
  };

  factory AniyaEvalPlugin.fromJson(Map<String, dynamic> json) {
    return AniyaEvalPlugin(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      version: (json['version'] ?? '0.0.0').toString(),
      language: (json['language'] ?? 'en').toString(),
      itemType: _itemTypeFromString((json['itemType'] ?? 'anime').toString()),
      url: json['url']?.toString(),
      sourceCode: (json['sourceCode'] ?? '').toString(),
      bytecode: (json['bytecode'] is List<int>)
          ? (json['bytecode'] as List<int>)
          : (json['bytecode'] is List)
          ? List<int>.from(json['bytecode'] as List)
          : null,
    );
  }

  static bridge_models.ItemType _itemTypeFromString(String raw) {
    return bridge_models.ItemType.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => bridge_models.ItemType.anime,
    );
  }
}

class AniyaEvalPluginStore {
  static const String boxName = 'aniyaEvalPlugins';

  Box? _box;

  Future<void> init() async {
    if (_box != null) {
      return;
    }
    _box = await Hive.openBox(boxName);
  }

  Future<void> put(AniyaEvalPlugin plugin) async {
    final box = _box;
    if (box == null) {
      throw StateError('AniyaEvalPluginStore is not initialized');
    }
    await box.put(plugin.id, plugin.toJson());
  }

  Future<void> remove(String id) async {
    final box = _box;
    if (box == null) {
      throw StateError('AniyaEvalPluginStore is not initialized');
    }
    await box.delete(id);
  }

  AniyaEvalPlugin? get(String id) {
    final box = _box;
    if (box == null) {
      throw StateError('AniyaEvalPluginStore is not initialized');
    }
    final json = box.get(id);
    if (json is Map) {
      return AniyaEvalPlugin.fromJson(Map<String, dynamic>.from(json));
    }
    return null;
  }

  List<AniyaEvalPlugin> all() {
    final box = _box;
    if (box == null) {
      throw StateError('AniyaEvalPluginStore is not initialized');
    }
    return box.values
        .whereType<Map>()
        .map((v) => AniyaEvalPlugin.fromJson(Map<String, dynamic>.from(v)))
        .toList();
  }

  List<AniyaEvalPlugin> byType(bridge_models.ItemType type) {
    return all().where((p) => p.itemType == type).toList();
  }

  bridge_models.Source toBridgeSource(AniyaEvalPlugin plugin) {
    return bridge_models.Source(
      id: plugin.id,
      name: plugin.name,
      version: plugin.version,
      lang: plugin.language,
      apkUrl: null,
      iconUrl: null,
      isNsfw: false,
      itemType: plugin.itemType,
      extensionType: bridge.ExtensionType.aniya,
    );
  }
}
