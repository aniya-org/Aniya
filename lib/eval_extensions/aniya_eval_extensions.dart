import 'package:get/get.dart';
import 'package:dartotsu_extension_bridge/Extensions/Extensions.dart';
import 'package:dartotsu_extension_bridge/Models/Source.dart';
import 'storage/aniya_eval_plugin_store.dart';
import 'runtime/aniya_eval_runtime.dart';

class AniyaEvalExtensions extends Extension {
  final AniyaEvalPluginStore store;

  AniyaEvalExtensions({required this.store});

  @override
  bool get supportsMovie => true;
  @override
  bool get supportsTvShow => true;
  @override
  bool get supportsCartoon => true;
  @override
  bool get supportsDocumentary => true;
  @override
  bool get supportsLivestream => true;
  @override
  bool get supportsNsfw => true;

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
    await store.init();
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
    installedMovieExtensions.value = store
        .byType(ItemType.movie)
        .map(store.toBridgeSource)
        .toList();
    installedTvShowExtensions.value = store
        .byType(ItemType.tvShow)
        .map(store.toBridgeSource)
        .toList();
    installedCartoonExtensions.value = store
        .byType(ItemType.cartoon)
        .map(store.toBridgeSource)
        .toList();
    installedDocumentaryExtensions.value = store
        .byType(ItemType.documentary)
        .map(store.toBridgeSource)
        .toList();
    installedLivestreamExtensions.value = store
        .byType(ItemType.livestream)
        .map(store.toBridgeSource)
        .toList();
    installedNsfwExtensions.value = store
        .byType(ItemType.nsfw)
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
  Future<List<Source>> getInstalledMovieExtensions() async {
    await _refreshInstalled();
    return installedMovieExtensions.value;
  }

  @override
  Future<List<Source>> getInstalledTvShowExtensions() async {
    await _refreshInstalled();
    return installedTvShowExtensions.value;
  }

  @override
  Future<List<Source>> getInstalledCartoonExtensions() async {
    await _refreshInstalled();
    return installedCartoonExtensions.value;
  }

  @override
  Future<List<Source>> getInstalledDocumentaryExtensions() async {
    await _refreshInstalled();
    return installedDocumentaryExtensions.value;
  }

  @override
  Future<List<Source>> getInstalledLivestreamExtensions() async {
    await _refreshInstalled();
    return installedLivestreamExtensions.value;
  }

  @override
  Future<List<Source>> getInstalledNsfwExtensions() async {
    await _refreshInstalled();
    return installedNsfwExtensions.value;
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
