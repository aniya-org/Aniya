import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:aniya/core/services/deep_link_handler.dart';
import 'package:aniya/core/data/models/repository_config_model.dart';
import 'package:aniya/core/domain/entities/extension_entity.dart';
import 'package:aniya/eval_extensions/storage/aniya_eval_plugin_store.dart';

class _MockHttpClient extends Mock implements http.Client {}

void main() {
  late DeepLinkHandler handler;

  setUp(() {
    handler = DeepLinkHandler();
  });

  group('DeepLinkHandler - parseDeepLinkParams', () {
    group('Aniyomi/Tachiyomi scheme', () {
      test('parses aniyomi scheme with url parameter', () {
        final uri = Uri.parse(
          'aniyomi://add-repo?url=https://example.com/repo.json',
        );
        final params = handler.parseDeepLinkParams(uri);

        expect(params.extensionType, ExtensionType.aniyomi);
        expect(params.mangaRepoUrl, 'https://example.com/repo.json');
        expect(params.animeRepoUrl, isNull);
        expect(params.novelRepoUrl, isNull);
      });

      test('parses tachiyomi scheme with url parameter', () {
        final uri = Uri.parse(
          'tachiyomi://add-repo?url=https://example.com/repo.json',
        );
        final params = handler.parseDeepLinkParams(uri);

        expect(params.extensionType, ExtensionType.aniyomi);
        expect(params.mangaRepoUrl, 'https://example.com/repo.json');
      });

      test('throws on missing url parameter', () {
        final uri = Uri.parse('aniyomi://add-repo');

        expect(
          () => handler.parseDeepLinkParams(uri),
          throwsA(isA<DeepLinkParseException>()),
        );
      });

      test('throws on invalid host', () {
        final uri = Uri.parse('aniyomi://invalid-host?url=https://example.com');

        expect(
          () => handler.parseDeepLinkParams(uri),
          throwsA(isA<DeepLinkParseException>()),
        );
      });
    });

    group('Mangayomi/Dar scheme', () {
      test('parses mangayomi scheme with all URL parameters', () {
        final uri = Uri.parse(
          'mangayomi://add-repo?url=https://anime.com&manga_url=https://manga.com&novel_url=https://novel.com',
        );
        final params = handler.parseDeepLinkParams(uri);

        expect(params.extensionType, ExtensionType.mangayomi);
        expect(params.animeRepoUrl, 'https://anime.com');
        expect(params.mangaRepoUrl, 'https://manga.com');
        expect(params.novelRepoUrl, 'https://novel.com');
      });

      test('parses dar scheme with anime_url parameter', () {
        final uri = Uri.parse('dar://add-repo?anime_url=https://anime.com');
        final params = handler.parseDeepLinkParams(uri);

        expect(params.extensionType, ExtensionType.mangayomi);
        expect(params.animeRepoUrl, 'https://anime.com');
        expect(params.mangaRepoUrl, isNull);
        expect(params.novelRepoUrl, isNull);
      });

      test('parses mangayomi scheme with only manga_url', () {
        final uri = Uri.parse(
          'mangayomi://add-repo?manga_url=https://manga.com',
        );
        final params = handler.parseDeepLinkParams(uri);

        expect(params.extensionType, ExtensionType.mangayomi);
        expect(params.mangaRepoUrl, 'https://manga.com');
      });

      test('throws on missing all URL parameters', () {
        final uri = Uri.parse('mangayomi://add-repo');

        expect(
          () => handler.parseDeepLinkParams(uri),
          throwsA(isA<DeepLinkParseException>()),
        );
      });

      test('throws on invalid host', () {
        final uri = Uri.parse('mangayomi://wrong-host?url=https://example.com');

        expect(
          () => handler.parseDeepLinkParams(uri),
          throwsA(isA<DeepLinkParseException>()),
        );
      });
    });

    group('CloudStream scheme', () {
      test('parses cloudstreamrepo scheme with https URL', () {
        final uri = Uri.parse(
          'cloudstreamrepo://https://example.com/repo.json',
        );
        final params = handler.parseDeepLinkParams(uri);

        expect(params.extensionType, ExtensionType.cloudstream);
        expect(params.animeRepoUrl, contains('example.com'));
      });

      test('parses cloudstreamrepo scheme without https prefix', () {
        final uri = Uri.parse('cloudstreamrepo://example.com/repo.json');
        final params = handler.parseDeepLinkParams(uri);

        expect(params.extensionType, ExtensionType.cloudstream);
        expect(params.animeRepoUrl, 'https://example.com/repo.json');
      });

      test('throws on empty cloudstreamrepo URL', () {
        final uri = Uri.parse('cloudstreamrepo://');

        expect(
          () => handler.parseDeepLinkParams(uri),
          throwsA(isA<DeepLinkParseException>()),
        );
      });
    });

    group('cs.repo host', () {
      test('parses cs.repo host with query URL', () {
        final uri = Uri.parse('https://cs.repo/?https://example.com/repo.json');
        final params = handler.parseDeepLinkParams(uri);

        expect(params.extensionType, ExtensionType.cloudstream);
        expect(params.animeRepoUrl, 'https://example.com/repo.json');
      });

      test('parses cs.repo host with URL-encoded query', () {
        final uri = Uri.parse(
          'https://cs.repo/?https%3A%2F%2Fexample.com%2Frepo.json',
        );
        final params = handler.parseDeepLinkParams(uri);

        expect(params.extensionType, ExtensionType.cloudstream);
        expect(params.animeRepoUrl, 'https://example.com/repo.json');
      });

      test('throws on empty cs.repo query', () {
        final uri = Uri.parse('https://cs.repo/');

        expect(
          () => handler.parseDeepLinkParams(uri),
          throwsA(isA<DeepLinkParseException>()),
        );
      });
    });

    group('Aniya scheme', () {
      test('parses aniya scheme with add-extension host', () {
        final uri = Uri.parse(
          'aniya://add-extension?url=https://example.com/extension.cs3',
        );
        final params = handler.parseDeepLinkParams(uri);

        expect(params.extensionType, ExtensionType.aniya);
        expect(params.animeRepoUrl, 'https://example.com/extension.cs3');
      });

      test('parses aniya scheme with add-extension-manifest host', () {
        final uri = Uri.parse(
          'aniya://add-extension-manifest?url=https://example.com/manifest.json',
        );
        final params = handler.parseDeepLinkParams(uri);

        expect(params.extensionType, ExtensionType.aniya);
        expect(params.animeRepoUrl, 'https://example.com/manifest.json');
      });

      test('throws on missing url parameter', () {
        final uri = Uri.parse('aniya://add-extension');

        expect(
          () => handler.parseDeepLinkParams(uri),
          throwsA(isA<DeepLinkParseException>()),
        );
      });
    });

    group('Unsupported schemes', () {
      test('throws on unsupported scheme', () {
        final uri = Uri.parse('unknown://add-repo?url=https://example.com');

        expect(
          () => handler.parseDeepLinkParams(uri),
          throwsA(isA<DeepLinkParseException>()),
        );
      });
    });
  });

  group('DeepLinkHandler - handleDeepLink', () {
    test('returns success result for valid aniyomi deep link', () async {
      final uri = Uri.parse(
        'aniyomi://add-repo?url=https://example.com/repo.json',
      );
      final result = await handler.handleDeepLink(uri);

      expect(result.success, isTrue);
      expect(result.addedRepos, contains('https://example.com/repo.json'));
      expect(result.message, contains('Successfully added'));
    });

    test(
      'returns success result for valid mangayomi deep link with multiple URLs',
      () async {
        final uri = Uri.parse(
          'mangayomi://add-repo?url=https://anime.com&manga_url=https://manga.com',
        );
        final result = await handler.handleDeepLink(uri);

        expect(result.success, isTrue);
        expect(result.addedRepos.length, 2);
        expect(result.message, contains('2 repositories'));
      },
    );

    test('returns failure result for invalid deep link', () async {
      final uri = Uri.parse('unknown://invalid');
      final result = await handler.handleDeepLink(uri);

      expect(result.success, isFalse);
      expect(result.message, contains('Unsupported'));
    });

    test('returns failure result for missing parameters', () async {
      final uri = Uri.parse('aniyomi://add-repo');
      final result = await handler.handleDeepLink(uri);

      expect(result.success, isFalse);
      expect(result.message, contains('Missing'));
    });

    test('calls onSaveRepository callback on success', () async {
      ExtensionType? savedType;
      RepositoryConfig? savedConfig;

      final handlerWithCallback = DeepLinkHandler(
        onSaveRepository: (type, config) async {
          savedType = type;
          savedConfig = config;
        },
      );

      final uri = Uri.parse(
        'mangayomi://add-repo?url=https://anime.com&manga_url=https://manga.com',
      );
      await handlerWithCallback.handleDeepLink(uri);

      expect(savedType, ExtensionType.mangayomi);
      expect(savedConfig?.animeRepoUrl, 'https://anime.com');
      expect(savedConfig?.mangaRepoUrl, 'https://manga.com');
    });

    group('Aniya scheme', () {
      late Directory hiveTempDir;

      setUpAll(() async {
        hiveTempDir = await Directory.systemTemp.createTemp(
          'aniya_hive_deeplink_test_',
        );
        Hive.init(hiveTempDir.path);
        registerFallbackValue(Uri.parse('https://example.com/fallback'));
      });

      tearDownAll(() async {
        await Hive.close();
        await Hive.deleteFromDisk();
        if (await hiveTempDir.exists()) {
          await hiveTempDir.delete(recursive: true);
        }
      });

      setUp(() async {
        await Hive.openBox(AniyaEvalPluginStore.boxName);
        await Hive.box(AniyaEvalPluginStore.boxName).clear();
      });

      test('installs a single plugin from plaintext URL', () async {
        final store = AniyaEvalPluginStore();
        final client = _MockHttpClient();
        final handlerWithStore = DeepLinkHandler(
          aniyaStore: store,
          httpClient: client,
        );

        final sourceUrl = Uri.parse('https://example.com/extension.cs3');
        when(
          () => client.get(sourceUrl),
        ).thenAnswer((_) async => http.Response('print("hello")', 200));

        final uri = Uri.parse(
          'aniya://add-extension?url=https://example.com/extension.cs3&id=test_plugin&name=Test%20Plugin&version=1.2.3&lang=en&type=anime',
        );

        final result = await handlerWithStore.handleDeepLink(uri);

        expect(result.success, isTrue);
        expect(
          result.addedRepos,
          contains('https://example.com/extension.cs3'),
        );

        final installed = store.all();
        expect(installed.length, 1);
        expect(installed.first.id, 'test_plugin');
        expect(installed.first.name, 'Test Plugin');
        expect(installed.first.version, '1.2.3');
        expect(installed.first.language, 'en');
        expect(installed.first.url, 'https://example.com/extension.cs3');
        expect(installed.first.sourceCode, contains('hello'));
      });

      test('installs plugins from manifest URL', () async {
        final store = AniyaEvalPluginStore();
        final client = _MockHttpClient();
        final handlerWithStore = DeepLinkHandler(
          aniyaStore: store,
          httpClient: client,
        );

        final manifestUrl = Uri.parse('https://example.com/manifest.json');
        final plugin1Url = Uri.parse('https://example.com/p1.cs3');
        final plugin2Url = Uri.parse('https://example.com/p2.cs3');

        when(() => client.get(manifestUrl)).thenAnswer(
          (_) async => http.Response(
            '[{"id":"p1","name":"One","url":"https://example.com/p1.cs3","version":"0.1.0","lang":"en","type":"anime"},{"id":"p2","name":"Two","url":"https://example.com/p2.cs3","version":"0.2.0","language":"en","itemType":"anime"}]',
            200,
          ),
        );
        when(
          () => client.get(plugin1Url),
        ).thenAnswer((_) async => http.Response('code_one', 200));
        when(
          () => client.get(plugin2Url),
        ).thenAnswer((_) async => http.Response('code_two', 200));

        final uri = Uri.parse(
          'aniya://add-extension-manifest?url=https://example.com/manifest.json',
        );

        final result = await handlerWithStore.handleDeepLink(uri);

        expect(result.success, isTrue);
        expect(result.addedRepos, contains('https://example.com/p1.cs3'));
        expect(result.addedRepos, contains('https://example.com/p2.cs3'));

        final installed = store.all();
        expect(installed.length, 2);
        expect(installed.map((e) => e.id).toSet(), {'p1', 'p2'});
        expect(installed.map((e) => e.sourceCode).toSet(), {
          'code_one',
          'code_two',
        });
      });

      test('returns failure when Aniya store is not provided', () async {
        final client = _MockHttpClient();
        final handlerWithoutStore = DeepLinkHandler(httpClient: client);

        final uri = Uri.parse(
          'aniya://add-extension?url=https://example.com/extension.cs3',
        );

        final result = await handlerWithoutStore.handleDeepLink(uri);

        expect(result.success, isFalse);
        expect(result.message, contains('store'));
      });
    });
  });
}
