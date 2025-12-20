import 'dart:io';

import 'package:beautiful_soup_dart/beautiful_soup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:dartotsu_extension_bridge/Models/Source.dart';
import 'package:hive/hive.dart';
import 'package:aniya/eval_extensions/storage/aniya_eval_plugin_store.dart';
import 'package:aniya/eval_extensions/aniya_eval_extensions.dart';
import 'package:aniya/eval_extensions/runtime/aniya_eval_runtime.dart';
import 'package:aniya/eval_extensions/templates/sample_plugin.dart';

String _unwrapEvalString(dynamic value) {
  if (value == null) return '';
  final s = value.toString();
  if (s.length >= 3) {
    if (s.startsWith(r'$"') && s.endsWith('"')) {
      return s.substring(2, s.length - 1);
    }
    if (s.startsWith(r"$'") && s.endsWith("'")) {
      return s.substring(2, s.length - 1);
    }
  }
  return s;
}

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

  test('BeautifulSoup can find nested link attributes', () {
    const html = '''
<html>
  <body>
    <div class="flw-item">
      <a title="Stranger Things" href="/tv/stranger-things">
        <img data-src="https://img.example/cover.jpg" />
      </a>
    </div>
  </body>
</html>
''';

    final soup = BeautifulSoup(html);
    final card = soup.find('div', class_: 'flw-item');
    expect(card, isNotNull);
    final a = card!.find('a');
    expect(a, isNotNull);
    expect(a!['title'], 'Stranger Things');
    expect(a['href'], '/tv/stranger-things');
    final img = a.find('img');
    expect(img, isNotNull);
    expect(img!['data-src'], 'https://img.example/cover.jpg');
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
    'Aniya eval runtime soupParse supports find() and element string',
    () async {
      const pluginSource = r'''
dynamic getTitle(
  dynamic html,
  dynamic Function(dynamic, [dynamic]) httpGet,
  dynamic Function(dynamic) soupParse,
  dynamic Function(dynamic) sha256Hex,
) {
  final soup = soupParse(html);
  final titleEl = soup.find('title');
  if (titleEl == null) return null;
  return titleEl.string;
}
''';

      final store = AniyaEvalPluginStore();
      await store.init();
      await store.put(
        AniyaEvalPlugin(
          id: 'soup',
          name: 'Soup',
          version: '0.0.1',
          language: 'en',
          itemType: ItemType.anime,
          sourceCode: pluginSource,
        ),
      );

      final runtime = AniyaEvalRuntime(store);
      final result = await runtime.callFunction('soup', 'getTitle', [
        '<html><head><title>Hello</title></head><body></body></html>',
      ]);

      expect(_unwrapEvalString(result), 'Hello');
    },
  );

  test('Himovies-style _asString unwraps soup attr strings safely', () async {
    const pluginSource = r'''
String _asString(dynamic value) {
  final s = value?.toString();
  if (s == null || s == 'null') return '';
  if (s.length >= 3) {
    if (s.startsWith(r'$"') && s.endsWith('"')) {
      return s.substring(2, s.length - 1);
    }
    if (s.startsWith(r"$'") && s.endsWith("'")) {
      return s.substring(2, s.length - 1);
    }
  }
  return s;
}

List<dynamic> _asList(dynamic value) {
  if (value is List) return value;
  if (value is Iterable) return value.toList();
  return const <dynamic>[];
}

dynamic parseCards(
  dynamic html,
  dynamic Function(dynamic, [dynamic]) httpGet,
  dynamic Function(dynamic) soupParse,
  dynamic Function(dynamic) sha256Hex,
) {
  final soup = soupParse(html);
  final cards = soup.findAll('div', {'class_': 'flw-item'});
  final out = <dynamic>[];
  for (final card in _asList(cards)) {
    final a = card.find('a');
    final img = card.find('img');
    final title = _asString(a?.attr('title'));
    final href = _asString(a?.attr('href'));
    final cover = _asString(img?.attr('data-src'));
    out.add({'title': title, 'href': href, 'cover': cover});
  }
  return out;
}
''';

    final store = AniyaEvalPluginStore();
    await store.init();
    await store.put(
      AniyaEvalPlugin(
        id: 'himovies_parse',
        name: 'HimoviesParse',
        version: '0.0.1',
        language: 'en',
        itemType: ItemType.anime,
        sourceCode: pluginSource,
      ),
    );

    final runtime = AniyaEvalRuntime(store);
    final result = await runtime.callFunction('himovies_parse', 'parseCards', [
      '''
<html>
  <body>
    <div class="flw-item">
      <a title="Stranger Things" href="/tv/stranger-things">
        <img data-src="https://img.example/cover.jpg" />
      </a>
    </div>
  </body>
</html>
''',
    ]);

    expect(result, isA<List>());
    final list = List<dynamic>.from(result as List);
    expect(list, hasLength(1));
    final map = Map<String, dynamic>.from(list.first as Map);
    expect(map['title'], 'Stranger Things');
    expect(map['href'], '/tv/stranger-things');
    expect(map['cover'], 'https://img.example/cover.jpg');
  });

  test(
    'Aniya eval runtime supports attrs option map for soup findAll',
    () async {
      const pluginSource = r'''
List<dynamic> parseLinks(
  dynamic html,
  dynamic Function(dynamic, [dynamic]) httpGet,
  dynamic Function(dynamic) soupParse,
  dynamic Function(dynamic) sha256Hex,
) {
  final soup = soupParse(html);
  final links = soup.findAll('a', {
    'attrs': {'href': true}
  });
  final out = <dynamic>[];
  for (final a in links) {
    out.add(a.attr('href'));
  }
  return out;
}
''';

      final store = AniyaEvalPluginStore();
      await store.init();
      await store.put(
        AniyaEvalPlugin(
          id: 'attrs_map',
          name: 'AttrsMap',
          version: '0.0.1',
          language: 'en',
          itemType: ItemType.anime,
          sourceCode: pluginSource,
        ),
      );

      final runtime = AniyaEvalRuntime(store);
      final result = await runtime.callFunction('attrs_map', 'parseLinks', [
        '<html><body><a href="/a"></a><a></a><a href="/b"></a></body></html>',
      ]);
      expect(result, ['/a', '/b']);
    },
  );

  test('Aniya eval runtime injects interop helpers and boxes args', () async {
    const pluginSource = r'''
import 'dart:convert';

dynamic interopEcho(
  dynamic query,
  dynamic Function(dynamic, [dynamic]) httpGet,
  dynamic Function(dynamic) soupParse,
  dynamic Function(dynamic) sha256Hex,
) {
  final encoded = Uri.encodeQueryComponent(query.toString());
  final payload = json.decode(json.encode({'q': encoded}));
  return payload['q'];
}
''';

    final store = AniyaEvalPluginStore();
    await store.init();
    await store.put(
      AniyaEvalPlugin(
        id: 'interop',
        name: 'Interop',
        version: '0.0.1',
        language: 'en',
        itemType: ItemType.anime,
        sourceCode: pluginSource,
      ),
    );

    final runtime = AniyaEvalRuntime(store);
    final result = await runtime.callFunction('interop', 'interopEcho', [
      'Stranger Things',
    ]);
    expect(result, 'Stranger+Things');
  });

  test(
    'Aniya eval runtime rewrites typed collection literals safely',
    () async {
      const pluginSource = r'''
dynamic typedCollections(
  dynamic query,
  dynamic Function(dynamic, [dynamic]) httpGet,
  dynamic Function(dynamic) soupParse,
  dynamic Function(dynamic) sha256Hex,
) {
  final tags = <String>['a', query.toString()];
  final map = <String, String>{'q': query.toString()};
  final set = <int>{1, 2};
  return {
    'tags': tags,
    'map': map,
    'set': set,
  };
}
''';

      final store = AniyaEvalPluginStore();
      await store.init();
      await store.put(
        AniyaEvalPlugin(
          id: 'typed',
          name: 'Typed',
          version: '0.0.1',
          language: 'en',
          itemType: ItemType.anime,
          sourceCode: pluginSource,
        ),
      );

      final runtime = AniyaEvalRuntime(store);
      final result = await runtime.callFunction('typed', 'typedCollections', [
        'x',
      ]);
      expect(result, isA<Map>());
      final map = Map<String, dynamic>.from(result as Map);
      expect(map['tags'], isA<List>());
      expect(map['map'], isA<Map>());
      expect(map['set'], isA<Set>());
    },
  );

  test(
    'Aniya eval runtime rewrites typed collection declarations safely',
    () async {
      const pluginSource = r'''
dynamic typedDeclarations(
  dynamic query,
  dynamic Function(dynamic, [dynamic]) httpGet,
  dynamic Function(dynamic) soupParse,
  dynamic Function(dynamic) sha256Hex,
) {
  List<String> tags = ['a', query.toString()];
  Map<String, String> map = {'q': query.toString()};
  Set<int> set = {1, 2};
  return {
    'tags': tags,
    'map': map,
    'set': set,
  };
}
''';

      final store = AniyaEvalPluginStore();
      await store.init();
      await store.put(
        AniyaEvalPlugin(
          id: 'typedDecl',
          name: 'TypedDecl',
          version: '0.0.1',
          language: 'en',
          itemType: ItemType.anime,
          sourceCode: pluginSource,
        ),
      );

      final runtime = AniyaEvalRuntime(store);
      final result = await runtime.callFunction(
        'typedDecl',
        'typedDeclarations',
        ['x'],
      );
      expect(result, isA<Map>());
      final map = Map<String, dynamic>.from(result as Map);
      expect(map['tags'], isA<List>());
      expect(map['map'], isA<Map>());
      expect(map['set'], isA<Set>());
    },
  );

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
