import 'package:get/get.dart';
import 'package:dartotsu_extension_bridge/Extensions/Extensions.dart';
import 'package:dartotsu_extension_bridge/Models/Source.dart';
import 'storage/aniya_eval_plugin_store.dart';
import 'runtime/aniya_eval_runtime.dart';

class AniyaEvalExtensions extends Extension {
  final AniyaEvalPluginStore store;

  AniyaEvalExtensions({required this.store});

  @override
  bool get supportsMovie => false;
  @override
  bool get supportsTvShow => false;
  @override
  bool get supportsCartoon => false;
  @override
  bool get supportsDocumentary => false;
  @override
  bool get supportsLivestream => false;
  @override
  bool get supportsNsfw => false;

  @override
  Future<void> initialize() async {
    await store.init();
    await _refreshInstalled();
    isInitialized.value = true;
    if (!Get.isRegistered<AniyaEvalRuntime>()) {
      Get.put(AniyaEvalRuntime(store));
    }
  }

  Future<void> _refreshInstalled() async {
    installedAnimeExtensions.value = store
        .byType(ItemType.anime)
        .map(store.toBridgeSource)
        .toList();
    installedMangaExtensions.value = store
        .byType(ItemType.manga)
        .map(store.toBridgeSource)
        .toList();
    installedNovelExtensions.value = store
        .byType(ItemType.novel)
        .map(store.toBridgeSource)
        .toList();
  }

  @override
  Future<List<Source>> getInstalledAnimeExtensions() async {
    await _refreshInstalled();
    return installedAnimeExtensions.value;
  }

  @override
  Future<List<Source>> getInstalledMangaExtensions() async {
    await _refreshInstalled();
    return installedMangaExtensions.value;
  }

  @override
  Future<List<Source>> getInstalledNovelExtensions() async {
    await _refreshInstalled();
    return installedNovelExtensions.value;
  }

  @override
  Future<void> installSource(Source source) async {
    final existing = store.get(source.id ?? '');
    if (existing == null) {
      throw StateError(
        'No persisted Aniya plugin with id ${source.id}. Use the editor to add one.',
      );
    }
    await _refreshInstalled();
  }

  @override
  Future<void> uninstallSource(Source source) async {
    final id = source.id ?? '';
    await store.remove(id);
    await _refreshInstalled();
  }

  @override
  Future<void> updateSource(Source source) async {
    // Optional: Implement update via plugin.url fetch flow
    await _refreshInstalled();
  }
}
