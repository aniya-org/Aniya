import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:aniya/core/domain/services/data_export_import_service.dart';

void main() {
  group('DataExportImportService', () {
    late DataExportImportService service;

    setUp(() {
      service = DataExportImportServiceImpl();
    });

    group('exportSettings', () {
      test('should export settings to valid JSON string', () async {
        // Feature: aniya-app, Property 41: Data Export Validity
        final settings = {
          'themeMode': 'dark',
          'videoQuality': 'p720',
          'autoPlayNextEpisode': true,
          'showNsfwExtensions': false,
        };

        final result = await service.exportSettings(settings);

        expect(result.isRight(), true);
        result.fold((failure) => fail('Should not fail'), (jsonString) {
          expect(jsonString, isA<String>());
          final decoded = jsonDecode(jsonString);
          expect(decoded['version'], '1.0');
          expect(decoded['settings'], settings);
        });
      });

      test('should include exportedAt timestamp in settings export', () async {
        final settings = {'key': 'value'};
        final result = await service.exportSettings(settings);

        result.fold((failure) => fail('Should not fail'), (jsonString) {
          final decoded = jsonDecode(jsonString);
          expect(decoded['exportedAt'], isA<String>());
          expect(DateTime.tryParse(decoded['exportedAt']), isNotNull);
        });
      });

      test('should handle empty settings export', () async {
        final result = await service.exportSettings({});

        expect(result.isRight(), true);
        result.fold((failure) => fail('Should not fail'), (jsonString) {
          final decoded = jsonDecode(jsonString);
          expect(decoded['settings'], {});
        });
      });
    });

    group('importSettings', () {
      test('should import valid settings JSON', () async {
        final exportData = {
          'version': '1.0',
          'exportedAt': DateTime.now().toIso8601String(),
          'settings': {
            'themeMode': 'dark',
            'videoQuality': 'p720',
            'autoPlayNextEpisode': true,
          },
        };

        final jsonString = jsonEncode(exportData);
        final result = await service.importSettings(jsonString);

        expect(result.isRight(), true);
        result.fold((failure) => fail('Should not fail'), (settings) {
          expect(settings, isA<Map<String, dynamic>>());
          expect(settings['themeMode'], 'dark');
          expect(settings['videoQuality'], 'p720');
          expect(settings['autoPlayNextEpisode'], true);
        });
      });

      test('should reject invalid settings format', () async {
        const invalidJson = '{"invalid": "format"}';
        final result = await service.importSettings(invalidJson);

        expect(result.isLeft(), true);
      });

      test('should handle malformed JSON', () async {
        const malformedJson = '{invalid json}';
        final result = await service.importSettings(malformedJson);

        expect(result.isLeft(), true);
      });
    });

    group('exportLibrary', () {
      test('should export library items to valid JSON string', () async {
        final result = await service.exportLibrary([]);

        expect(result.isRight(), true);
        result.fold((failure) => fail('Should not fail'), (jsonString) {
          expect(jsonString, isA<String>());
          final decoded = jsonDecode(jsonString);
          expect(decoded['version'], '1.0');
          expect(decoded['itemCount'], 0);
          expect(decoded['items'], isA<List>());
        });
      });

      test('should handle empty library export', () async {
        final result = await service.exportLibrary([]);

        expect(result.isRight(), true);
        result.fold((failure) => fail('Should not fail'), (jsonString) {
          final decoded = jsonDecode(jsonString);
          expect(decoded['itemCount'], 0);
          expect(decoded['items'], []);
        });
      });
    });

    group('importLibrary', () {
      test('should reject invalid library JSON format', () async {
        const invalidJson = '{"invalid": "format"}';
        final result = await service.importLibrary(invalidJson);

        expect(result.isLeft(), true);
      });

      test('should handle malformed library JSON', () async {
        const malformedJson = '{invalid json}';
        final result = await service.importLibrary(malformedJson);

        expect(result.isLeft(), true);
      });
    });

    group('Round-trip property tests', () {
      test('settings export then import should preserve data', () async {
        // Feature: aniya-app, Property 42: Data Import Round-Trip
        final originalSettings = {
          'themeMode': 'dark',
          'videoQuality': 'p720',
          'autoPlayNextEpisode': true,
          'showNsfwExtensions': false,
        };

        // Export
        final exportResult = await service.exportSettings(originalSettings);
        expect(exportResult.isRight(), true);

        String exportedJson = '';
        exportResult.fold(
          (failure) => fail('Export should not fail'),
          (json) => exportedJson = json,
        );

        // Import
        final importResult = await service.importSettings(exportedJson);
        expect(importResult.isRight(), true);

        importResult.fold((failure) => fail('Import should not fail'), (
          settings,
        ) {
          expect(settings['themeMode'], originalSettings['themeMode']);
          expect(settings['videoQuality'], originalSettings['videoQuality']);
          expect(
            settings['autoPlayNextEpisode'],
            originalSettings['autoPlayNextEpisode'],
          );
          expect(
            settings['showNsfwExtensions'],
            originalSettings['showNsfwExtensions'],
          );
        });
      });
    });
  });
}
