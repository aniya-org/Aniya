import 'package:flutter_test/flutter_test.dart';
import 'package:aniya/core/data/models/extension_model.dart';
import 'package:aniya/core/domain/entities/extension_entity.dart';

void main() {
  group('ExtensionModel', () {
    final tExtensionModel = ExtensionModel(
      id: 'ext1',
      name: 'Test Extension',
      version: '1.0.0',
      type: ExtensionType.cloudstream,
      language: 'en',
      isInstalled: true,
      isNsfw: false,
      iconUrl: 'https://example.com/icon.png',
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
        'type': 'cloudstream',
        'language': 'en',
        'isInstalled': true,
        'isNsfw': false,
        'iconUrl': 'https://example.com/icon.png',
      });
    });

    test('fromJson should return a valid ExtensionModel', () {
      final json = {
        'id': 'ext1',
        'name': 'Test Extension',
        'version': '1.0.0',
        'type': 'cloudstream',
        'language': 'en',
        'isInstalled': true,
        'isNsfw': false,
        'iconUrl': 'https://example.com/icon.png',
      };

      final result = ExtensionModel.fromJson(json);

      expect(result, tExtensionModel);
    });

    test('copyWith should return a new instance with updated values', () {
      final result = tExtensionModel.copyWith(
        isInstalled: false,
        version: '2.0.0',
      );

      expect(result.isInstalled, false);
      expect(result.version, '2.0.0');
      expect(result.id, tExtensionModel.id);
      expect(result.name, tExtensionModel.name);
    });
  });
}
