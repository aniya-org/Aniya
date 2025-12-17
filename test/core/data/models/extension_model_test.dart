import 'package:flutter_test/flutter_test.dart';
import 'package:aniya/core/data/models/extension_model.dart';
import 'package:aniya/core/domain/entities/extension_entity.dart';
import 'package:dartotsu_extension_bridge/Lnreader/LnReaderExtensions.dart';
import 'package:dartotsu_extension_bridge/Mangayomi/Models/Source.dart'
    as bridge;
import 'package:dartotsu_extension_bridge/dartotsu_extension_bridge.dart'
    as bridge;

void main() {
  group('ExtensionModel', () {
    final tExtensionModel = ExtensionModel(
      id: 'ext1',
      name: 'Test Extension',
      version: '1.0.0',
      versionLast: '1.1.0',
      type: ExtensionType.cloudstream,
      itemType: ItemType.anime,
      language: 'en',
      isInstalled: true,
      isNsfw: false,
      hasUpdate: true,
      iconUrl: 'https://example.com/icon.png',
      apkUrl: 'https://example.com/ext.apk',
      description: 'A test extension',
    );

    test('should be a subclass of ExtensionEntity', () {
      expect(tExtensionModel, isA<ExtensionEntity>());
    });

    test('toJson should return a valid JSON map', () {
      final result = tExtensionModel.toJson();

      expect(result, {
        'id': 'ext1',
        'name': 'Test Extension',
        'version': '1.0.0',
        'versionLast': '1.1.0',
        'type': 'cloudstream',
        'itemType': 'anime',
        'language': 'en',
        'isInstalled': true,
        'isNsfw': false,
        'hasUpdate': true,
        'iconUrl': 'https://example.com/icon.png',
        'apkUrl': 'https://example.com/ext.apk',
        'description': 'A test extension',
        'isExecutableOnDesktop': null,
      });
    });

    test('fromJson should return a valid ExtensionModel', () {
      final json = {
        'id': 'ext1',
        'name': 'Test Extension',
        'version': '1.0.0',
        'versionLast': '1.1.0',
        'type': 'cloudstream',
        'itemType': 'anime',
        'language': 'en',
        'isInstalled': true,
        'isNsfw': false,
        'hasUpdate': true,
        'iconUrl': 'https://example.com/icon.png',
        'apkUrl': 'https://example.com/ext.apk',
        'description': 'A test extension',
      };

      final result = ExtensionModel.fromJson(json);

      expect(result, tExtensionModel);
    });

    test('fromJson should handle missing optional fields', () {
      final json = {
        'id': 'ext2',
        'name': 'Minimal Extension',
        'version': '1.0.0',
        'type': 'aniyomi',
        'language': 'ja',
        'isInstalled': false,
        'isNsfw': true,
      };

      final result = ExtensionModel.fromJson(json);

      expect(result.id, 'ext2');
      expect(result.versionLast, isNull);
      expect(result.itemType, ItemType.anime); // default
      expect(result.hasUpdate, false); // default
      expect(result.apkUrl, isNull);
      expect(result.description, isNull);
    });

    test('copyWith should return a new instance with updated values', () {
      final result = tExtensionModel.copyWith(
        isInstalled: false,
        version: '2.0.0',
        hasUpdate: false,
        itemType: ItemType.manga,
      );

      expect(result.isInstalled, false);
      expect(result.version, '2.0.0');
      expect(result.hasUpdate, false);
      expect(result.itemType, ItemType.manga);
      expect(result.id, tExtensionModel.id);
      expect(result.name, tExtensionModel.name);
    });

    test('toEntity should return a valid ExtensionEntity', () {
      final entity = tExtensionModel.toEntity();

      expect(entity.id, tExtensionModel.id);
      expect(entity.name, tExtensionModel.name);
      expect(entity.version, tExtensionModel.version);
      expect(entity.versionLast, tExtensionModel.versionLast);
      expect(entity.type, tExtensionModel.type);
      expect(entity.itemType, tExtensionModel.itemType);
      expect(entity.hasUpdate, tExtensionModel.hasUpdate);
      expect(entity.apkUrl, tExtensionModel.apkUrl);
      expect(entity.description, tExtensionModel.description);
    });
  });

  group('LnReader Repo Parsing', () {
    test('parsePlugins supports official LnReader url/iconUrl fields', () {
      final pluginJson = <dynamic, dynamic>{
        'id': 'arnovel',
        'name': 'ArNovel',
        'site': 'https://ar-no.com/',
        'lang': '‎العربية',
        'version': '1.0.10',
        'url':
            'https://raw.githubusercontent.com/lnreader/lnreader-plugins/plugins/v3.0.0/.js/src/plugins/arabic/ArNovel[madara].js',
        'iconUrl':
            'https://raw.githubusercontent.com/lnreader/lnreader-plugins/plugins/v3.0.0/public/static/multisrc/madara/arnovel/icon.png',
      };

      final sources = LnReaderExtensions.parsePlugins({
        'pluginsJson': [pluginJson],
        'repoUrl':
            'https://raw.githubusercontent.com/LNReader/lnreader-plugins/plugins/v3.0.0/.dist/plugins.min.json',
      });

      expect(sources.length, equals(1));

      final source = sources.single;
      expect(source.id, equals('arnovel'));
      expect(source.name, equals('ArNovel'));
      expect(source.baseUrl, equals('https://ar-no.com/'));
      expect(source.iconUrl, contains('/icon.png'));
      expect(source.apkUrl, startsWith('https://'));
      expect(source.itemType, equals(bridge.ItemType.novel));
      expect(source.extensionType, equals(bridge.ExtensionType.lnreader));
    });

    test('parsePlugins supports map types other than Map<String, dynamic>', () {
      final pluginJson = <dynamic, dynamic>{
        'id': 'test',
        'name': 'Test',
        'site': 'https://example.com/',
        'lang': 'en',
        'version': '1.0.0',
        'iconUrl': 'https://example.com/icon.png',
        'url': 'https://example.com/plugin.js',
      };

      final sources = LnReaderExtensions.parsePlugins({
        'pluginsJson': [pluginJson],
        'repoUrl': 'https://example.com/plugins.min.json',
      });

      expect(sources.length, equals(1));

      final source = sources.single;
      expect(source.id, equals('test'));
      expect(source.name, equals('Test'));
      expect(source.version, equals('1.0.0'));
      expect(source.lang, equals('en'));
      expect(source.iconUrl, equals('https://example.com/icon.png'));
      expect(source.baseUrl, equals('https://example.com/'));
      expect(source.itemType, equals(bridge.ItemType.novel));
      expect(source.extensionType, equals(bridge.ExtensionType.lnreader));
      expect(source.repo, equals('https://example.com/plugins.min.json'));
      expect(source.hasUpdate, equals(false));
      expect(source.apkUrl, equals('https://example.com/plugin.js'));
    });
  });
}
