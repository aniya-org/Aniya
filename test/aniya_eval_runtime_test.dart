import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:dartotsu_extension_bridge/Models/Source.dart';
import 'package:hive/hive.dart';
import 'package:aniya/eval_extensions/storage/aniya_eval_plugin_store.dart';
import 'package:aniya/eval_extensions/aniya_eval_extensions.dart';
import 'package:aniya/eval_extensions/runtime/aniya_eval_runtime.dart';
import 'package:aniya/eval_extensions/templates/sample_plugin.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveTempDir;

  setUpAll(() async {
    hiveTempDir = await Directory.systemTemp.createTemp(
      'aniya_hive_eval_test_',
    );
    Hive.init(hiveTempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    await Hive.deleteFromDisk();
    if (await hiveTempDir.exists()) {
      await hiveTempDir.delete(recursive: true);
    }
    Get.reset();
  });

  test('Aniya eval runtime executes search', () async {
    final store = AniyaEvalPluginStore();
    await store.init();
    final plugin = AniyaEvalPlugin(
      id: 'sample',
      name: 'Sample',
      version: '0.0.1',
      language: 'en',
      itemType: ItemType.anime,
      sourceCode: sampleAniyaPlugin,
    );
    await store.put(plugin);
    final runtime = AniyaEvalRuntime(store);
    Get.put(store);
    final result = await runtime.callFunction('sample', 'search', [
      'hello',
      1,
      const [],
    ]);
    expect(result, isNotNull);
  });

  test(
    'Aniya eval extensions initializes store when listing installed',
    () async {
      final store = AniyaEvalPluginStore();
      final plugin = AniyaEvalPlugin(
        id: 'sample',
        name: 'Sample',
        version: '0.0.1',
        language: 'en',
        itemType: ItemType.manga,
        sourceCode: sampleAniyaPlugin,
      );
      await store.init();
      await store.put(plugin);

      final uninitializedStore = AniyaEvalPluginStore();
      final manager = AniyaEvalExtensions(store: uninitializedStore);
      final installed = await manager.getInstalledMangaExtensions();
      expect(installed, isNotEmpty);
    },
  );
}
