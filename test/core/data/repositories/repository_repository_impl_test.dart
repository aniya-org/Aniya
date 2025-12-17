import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:aniya/core/data/repositories/repository_repository_impl.dart';
import 'package:aniya/core/data/datasources/repository_local_data_source.dart';
import 'package:aniya/core/data/models/repository_config_model.dart';
import 'package:aniya/core/domain/entities/extension_entity.dart';

/// Mock implementation of RepositoryLocalDataSource for testing
class MockRepositoryLocalDataSource implements RepositoryLocalDataSource {
  final Map<ExtensionType, RepositoryConfig> _configs = {};

  @override
  Future<RepositoryConfig?> getRepositoryConfig(ExtensionType type) async {
    return _configs[type];
  }

  @override
  Future<void> saveRepositoryConfig(
    ExtensionType type,
    RepositoryConfig config,
  ) async {
    _configs[type] = config;
  }

  @override
  Future<void> deleteRepositoryConfig(ExtensionType type) async {
    _configs.remove(type);
  }

  @override
  Future<Map<ExtensionType, RepositoryConfig>> getAllRepositoryConfigs() async {
    return Map.from(_configs);
  }
}

void main() {
  late RepositoryRepositoryImpl repository;
  late MockRepositoryLocalDataSource mockLocalDataSource;
  late http.Client mockHttpClient;

  setUp(() {
    mockLocalDataSource = MockRepositoryLocalDataSource();
  });

  group('getRepositoryConfig', () {
    test('should return empty config when no config exists', () async {
      mockHttpClient = MockClient((request) async {
        return http.Response('', 200);
      });
      repository = RepositoryRepositoryImpl(
        localDataSource: mockLocalDataSource,
        httpClient: mockHttpClient,
      );

      final result = await repository.getRepositoryConfig(
        ExtensionType.mangayomi,
      );

      expect(result.isRight(), true);
      result.fold((failure) => fail('Should not return failure'), (config) {
        expect(config.animeRepoUrl, isNull);
        expect(config.mangaRepoUrl, isNull);
        expect(config.novelRepoUrl, isNull);
      });
    });

    test('should return saved config when it exists', () async {
      mockHttpClient = MockClient((request) async {
        return http.Response('', 200);
      });
      repository = RepositoryRepositoryImpl(
        localDataSource: mockLocalDataSource,
        httpClient: mockHttpClient,
      );

      const testConfig = RepositoryConfig(
        animeRepoUrl: 'https://example.com/anime',
        mangaRepoUrl: 'https://example.com/manga',
      );
      await mockLocalDataSource.saveRepositoryConfig(
        ExtensionType.mangayomi,
        testConfig,
      );

      final result = await repository.getRepositoryConfig(
        ExtensionType.mangayomi,
      );

      expect(result.isRight(), true);
      result.fold((failure) => fail('Should not return failure'), (config) {
        expect(config.animeRepoUrl, 'https://example.com/anime');
        expect(config.mangaRepoUrl, 'https://example.com/manga');
      });
    });
  });

  group('saveRepositoryConfig', () {
    test('should save config successfully', () async {
      mockHttpClient = MockClient((request) async {
        return http.Response('', 200);
      });
      repository = RepositoryRepositoryImpl(
        localDataSource: mockLocalDataSource,
        httpClient: mockHttpClient,
      );

      const testConfig = RepositoryConfig(
        animeRepoUrl: 'https://example.com/anime',
      );

      final result = await repository.saveRepositoryConfig(
        ExtensionType.aniyomi,
        testConfig,
      );

      expect(result.isRight(), true);

      // Verify it was saved
      final savedConfig = await mockLocalDataSource.getRepositoryConfig(
        ExtensionType.aniyomi,
      );
      expect(savedConfig?.animeRepoUrl, 'https://example.com/anime');
    });
  });

  group('fetchExtensionsFromRepo', () {
    test('should fetch and parse extensions from valid JSON array', () async {
      final testExtensions = [
        {
          'id': 'ext1',
          'name': 'Extension 1',
          'version': '1.0.0',
          'language': 'en',
          'isNsfw': false,
        },
        {
          'id': 'ext2',
          'name': 'Extension 2',
          'version': '2.0.0',
          'language': 'ja',
          'isNsfw': true,
        },
      ];

      mockHttpClient = MockClient((request) async {
        return http.Response(jsonEncode(testExtensions), 200);
      });
      repository = RepositoryRepositoryImpl(
        localDataSource: mockLocalDataSource,
        httpClient: mockHttpClient,
      );

      final result = await repository.fetchExtensionsFromRepo(
        'https://example.com/extensions.json',
        ItemType.anime,
        ExtensionType.mangayomi,
      );

      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure: ${failure.message}'),
        (extensions) {
          expect(extensions.length, 2);
          expect(extensions[0].id, 'ext1');
          expect(extensions[0].name, 'Extension 1');
          expect(extensions[1].id, 'ext2');
          expect(extensions[1].isNsfw, true);
        },
      );
    });

    test('should return failure for HTTP error', () async {
      mockHttpClient = MockClient((request) async {
        return http.Response('Not Found', 404);
      });
      repository = RepositoryRepositoryImpl(
        localDataSource: mockLocalDataSource,
        httpClient: mockHttpClient,
      );

      final result = await repository.fetchExtensionsFromRepo(
        'https://example.com/extensions.json',
        ItemType.anime,
        ExtensionType.mangayomi,
      );

      expect(result.isLeft(), true);
      result.fold((failure) {
        expect(failure.message, contains('404'));
      }, (extensions) => fail('Should return failure'));
    });

    test('should return failure for invalid URL', () async {
      mockHttpClient = MockClient((request) async {
        return http.Response('', 200);
      });
      repository = RepositoryRepositoryImpl(
        localDataSource: mockLocalDataSource,
        httpClient: mockHttpClient,
      );

      final result = await repository.fetchExtensionsFromRepo(
        'not-a-valid-url',
        ItemType.anime,
        ExtensionType.mangayomi,
      );

      expect(result.isLeft(), true);
    });
  });

  group('aggregateExtensions', () {
    test('should combine extensions from multiple lists', () {
      mockHttpClient = MockClient((request) async {
        return http.Response('', 200);
      });
      repository = RepositoryRepositoryImpl(
        localDataSource: mockLocalDataSource,
        httpClient: mockHttpClient,
      );

      final list1 = [
        const ExtensionEntity(
          id: 'ext1',
          name: 'Extension 1',
          version: '1.0.0',
          type: ExtensionType.mangayomi,
          language: 'en',
          isInstalled: false,
          isNsfw: false,
        ),
      ];

      final list2 = [
        const ExtensionEntity(
          id: 'ext2',
          name: 'Extension 2',
          version: '1.0.0',
          type: ExtensionType.mangayomi,
          language: 'ja',
          isInstalled: false,
          isNsfw: false,
        ),
      ];

      final result = repository.aggregateExtensions([list1, list2]);

      expect(result.length, 2);
      expect(result.map((e) => e.id).toList(), ['ext1', 'ext2']);
    });

    test('should remove duplicates by ID', () {
      mockHttpClient = MockClient((request) async {
        return http.Response('', 200);
      });
      repository = RepositoryRepositoryImpl(
        localDataSource: mockLocalDataSource,
        httpClient: mockHttpClient,
      );

      final list1 = [
        const ExtensionEntity(
          id: 'ext1',
          name: 'Extension 1',
          version: '1.0.0',
          type: ExtensionType.mangayomi,
          language: 'en',
          isInstalled: false,
          isNsfw: false,
        ),
      ];

      final list2 = [
        const ExtensionEntity(
          id: 'ext1', // Same ID as in list1
          name: 'Extension 1 Updated',
          version: '2.0.0',
          type: ExtensionType.mangayomi,
          language: 'en',
          isInstalled: false,
          isNsfw: false,
        ),
        const ExtensionEntity(
          id: 'ext2',
          name: 'Extension 2',
          version: '1.0.0',
          type: ExtensionType.mangayomi,
          language: 'ja',
          isInstalled: false,
          isNsfw: false,
        ),
      ];

      final result = repository.aggregateExtensions([list1, list2]);

      expect(result.length, 2);
      // First occurrence should be kept
      expect(result[0].name, 'Extension 1');
      expect(result[0].version, '1.0.0');
    });
  });

  group('CloudStream validation - Regression tests', () {
    /// **Regression test: CloudStream extensions should not be fetched via RepositoryRepositoryImpl**
    ///
    /// CloudStream extensions must be handled via CloudStreamExtensions bridge,
    /// not the generic repository layer. This prevents duplicate manifest parsing
    /// and ensures proper plugin registration with the native plugin store.
    test(
      'fetchExtensionsFromRepo returns ValidationFailure for CloudStream type',
      () async {
        mockHttpClient = MockClient((request) async {
          // This should never be called for CloudStream
          fail('HTTP client should not be called for CloudStream extensions');
        });
        repository = RepositoryRepositoryImpl(
          localDataSource: mockLocalDataSource,
          httpClient: mockHttpClient,
        );

        final result = await repository.fetchExtensionsFromRepo(
          'https://example.com/cloudstream-repo.json',
          ItemType.anime,
          ExtensionType.cloudstream,
        );

        expect(result.isLeft(), true);
        result.fold(
          (failure) {
            expect(failure.message, contains('CloudStreamExtensions'));
            expect(failure.message, contains('ExtensionsController'));
          },
          (extensions) =>
              fail('Should return ValidationFailure for CloudStream'),
        );
      },
    );

    /// **Regression test: fetchCloudStreamRepository returns ValidationFailure**
    ///
    /// The deprecated fetchCloudStreamRepository method should return a clear
    /// validation failure directing callers to use CloudStreamExtensions.
    test('fetchCloudStreamRepository returns ValidationFailure', () async {
      mockHttpClient = MockClient((request) async {
        // This should never be called
        fail(
          'HTTP client should not be called for deprecated CloudStream method',
        );
      });
      repository = RepositoryRepositoryImpl(
        localDataSource: mockLocalDataSource,
        httpClient: mockHttpClient,
      );

      final result = await repository.fetchCloudStreamRepository(
        'https://example.com/cloudstream-manifest.json',
      );

      expect(result.isLeft(), true);
      result.fold((failure) {
        expect(failure.message, contains('CloudStreamExtensions'));
        expect(failure.message, contains('fetchRepos'));
      }, (extensions) => fail('Should return ValidationFailure'));
    });

    /// **Regression test: Non-CloudStream types still work normally**
    ///
    /// Mangayomi and Aniyomi extension types should continue to work
    /// through the repository layer.
    test('fetchExtensionsFromRepo works for Mangayomi type', () async {
      final testExtensions = [
        {
          'id': 'mangayomi-ext',
          'name': 'Mangayomi Extension',
          'version': '1.0.0',
          'language': 'en',
        },
      ];

      mockHttpClient = MockClient((request) async {
        return http.Response(jsonEncode(testExtensions), 200);
      });
      repository = RepositoryRepositoryImpl(
        localDataSource: mockLocalDataSource,
        httpClient: mockHttpClient,
      );

      final result = await repository.fetchExtensionsFromRepo(
        'https://example.com/mangayomi-repo.json',
        ItemType.manga,
        ExtensionType.mangayomi,
      );

      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure for Mangayomi'),
        (extensions) {
          expect(extensions.length, 1);
          expect(extensions[0].id, 'mangayomi-ext');
        },
      );
    });

    test('fetchExtensionsFromRepo works for Aniyomi type', () async {
      final testExtensions = [
        {
          'id': 'aniyomi-ext',
          'name': 'Aniyomi Extension',
          'version': '1.0.0',
          'language': 'en',
        },
      ];

      mockHttpClient = MockClient((request) async {
        return http.Response(jsonEncode(testExtensions), 200);
      });
      repository = RepositoryRepositoryImpl(
        localDataSource: mockLocalDataSource,
        httpClient: mockHttpClient,
      );

      final result = await repository.fetchExtensionsFromRepo(
        'https://example.com/aniyomi-repo.json',
        ItemType.anime,
        ExtensionType.aniyomi,
      );

      expect(result.isRight(), true);
      result.fold((failure) => fail('Should not return failure for Aniyomi'), (
        extensions,
      ) {
        expect(extensions.length, 1);
        expect(extensions[0].id, 'aniyomi-ext');
      });
    });
  });
}
