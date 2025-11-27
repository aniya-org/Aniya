import 'package:flutter_test/flutter_test.dart';
import 'package:aniya/core/data/models/extension_model.dart';
import 'package:aniya/core/domain/entities/extension_entity.dart';

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
}
