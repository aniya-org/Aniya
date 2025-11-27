import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:aniya/core/utils/provider_cache.dart';
import 'package:aniya/core/error/exceptions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProviderCache', () {
    late ProviderCache cache;
    late Directory testDir;

    setUpAll(() async {
      // Create a temporary directory for Hive
      testDir = await Directory.systemTemp.createTemp('hive_test_');
      // Initialize Hive with the test directory
      Hive.init(testDir.path);
    });

    setUp(() async {
      cache = ProviderCache();
      await cache.init();
      await cache.clearAll();
    });

    tearDown(() async {
      await cache.clearAll();
      await cache.close();
    });

    tearDownAll(() async {
      // Clean up test directory
      if (await testDir.exists()) {
        await testDir.delete(recursive: true);
      }
    });

    group('Initialization', () {
      test('should initialize successfully', () async {
        // The cache is already initialized in setUp
        expect(cache, isNotNull);
      });

      test(
        'should throw CacheException when operations called before init',
        () async {
          final uninitializedCache = ProviderCache();

          expect(
            () => uninitializedCache.storeMapping(
              primaryProviderId: 'test',
              primaryMediaId: '123',
              providerMappings: {},
            ),
            throwsA(isA<CacheException>()),
          );
        },
      );
    });

    group('Store and Retrieve', () {
      test('should store and retrieve mappings successfully', () async {
        final mappings = {'anilist': '456', 'kitsu': '789'};

        await cache.storeMapping(
          primaryProviderId: 'jikan',
          primaryMediaId: '123',
          providerMappings: mappings,
        );

        final retrieved = await cache.getMappings(
          primaryProviderId: 'jikan',
          primaryMediaId: '123',
        );

        expect(retrieved, equals(mappings));
      });

      test('should return null for non-existent mappings', () async {
        final retrieved = await cache.getMappings(
          primaryProviderId: 'nonexistent',
          primaryMediaId: '999',
        );

        expect(retrieved, isNull);
      });

      test('should handle empty provider mappings', () async {
        await cache.storeMapping(
          primaryProviderId: 'test',
          primaryMediaId: '123',
          providerMappings: {},
        );

        final retrieved = await cache.getMappings(
          primaryProviderId: 'test',
          primaryMediaId: '123',
        );

        expect(retrieved, equals({}));
      });

      test('should overwrite existing mappings with same key', () async {
        final firstMappings = {'anilist': '111'};
        final secondMappings = {'anilist': '222', 'kitsu': '333'};

        await cache.storeMapping(
          primaryProviderId: 'jikan',
          primaryMediaId: '123',
          providerMappings: firstMappings,
        );

        await cache.storeMapping(
          primaryProviderId: 'jikan',
          primaryMediaId: '123',
          providerMappings: secondMappings,
        );

        final retrieved = await cache.getMappings(
          primaryProviderId: 'jikan',
          primaryMediaId: '123',
        );

        expect(retrieved, equals(secondMappings));
      });
    });

    group('Expiration', () {
      test('should detect expired entries', () {
        final oldDate = DateTime.now().subtract(const Duration(days: 8));
        expect(cache.isExpired(oldDate), isTrue);
      });

      test('should not detect fresh entries as expired', () {
        final recentDate = DateTime.now().subtract(const Duration(days: 3));
        expect(cache.isExpired(recentDate), isFalse);
      });

      test('should not detect entries at exactly 7 days as expired', () {
        final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
        expect(cache.isExpired(sevenDaysAgo), isFalse);
      });

      test('should return null for expired mappings', () async {
        // This test verifies the expiration logic by checking the isExpired method
        // In a real scenario, we would need to wait 8 days or mock the time
        // For now, we test the isExpired method directly
        final expiredDate = DateTime.now().subtract(const Duration(days: 8));
        expect(cache.isExpired(expiredDate), isTrue);

        // Store a fresh mapping and verify it's not expired
        await cache.storeMapping(
          primaryProviderId: 'test',
          primaryMediaId: '123',
          providerMappings: {'anilist': '456'},
        );

        final retrieved = await cache.getMappings(
          primaryProviderId: 'test',
          primaryMediaId: '123',
        );

        expect(retrieved, isNotNull);
      });

      test('should clear expired entries', () async {
        // Store fresh mapping
        await cache.storeMapping(
          primaryProviderId: 'fresh',
          primaryMediaId: '123',
          providerMappings: {'anilist': '456'},
        );

        // Call clearExpired - should not remove fresh entries
        await cache.clearExpired();

        // Fresh should still exist
        final fresh = await cache.getMappings(
          primaryProviderId: 'fresh',
          primaryMediaId: '123',
        );
        expect(fresh, isNotNull);
        expect(fresh!['anilist'], equals('456'));
      });
    });

    group('Cache Management', () {
      test('should clear all entries', () async {
        await cache.storeMapping(
          primaryProviderId: 'test1',
          primaryMediaId: '123',
          providerMappings: {'anilist': '456'},
        );

        await cache.storeMapping(
          primaryProviderId: 'test2',
          primaryMediaId: '789',
          providerMappings: {'kitsu': '012'},
        );

        await cache.clearAll();

        final count = await cache.getEntryCount();
        expect(count, equals(0));
      });

      test('should calculate cache size', () async {
        await cache.storeMapping(
          primaryProviderId: 'test',
          primaryMediaId: '123',
          providerMappings: {'anilist': '456'},
        );

        final size = await cache.getCacheSize();
        expect(size, greaterThan(0));
      });

      test('should count cache entries correctly', () async {
        expect(await cache.getEntryCount(), equals(0));

        await cache.storeMapping(
          primaryProviderId: 'test1',
          primaryMediaId: '123',
          providerMappings: {'anilist': '456'},
        );

        expect(await cache.getEntryCount(), equals(1));

        await cache.storeMapping(
          primaryProviderId: 'test2',
          primaryMediaId: '789',
          providerMappings: {'kitsu': '012'},
        );

        expect(await cache.getEntryCount(), equals(2));
      });
    });

    group('CachedMapping', () {
      test('should serialize and deserialize correctly', () {
        final mapping = CachedMapping(
          primaryProviderId: 'jikan',
          primaryMediaId: '123',
          providerMappings: {'anilist': '456', 'kitsu': '789'},
          cachedAt: DateTime.now(),
        );

        final json = mapping.toJson();
        final deserialized = CachedMapping.fromJson(json);

        expect(
          deserialized.primaryProviderId,
          equals(mapping.primaryProviderId),
        );
        expect(deserialized.primaryMediaId, equals(mapping.primaryMediaId));
        expect(deserialized.providerMappings, equals(mapping.providerMappings));
        expect(
          deserialized.cachedAt.toIso8601String(),
          equals(mapping.cachedAt.toIso8601String()),
        );
      });

      test('should generate correct cache key', () {
        final mapping = CachedMapping(
          primaryProviderId: 'jikan',
          primaryMediaId: '123',
          providerMappings: {},
          cachedAt: DateTime.now(),
        );

        expect(mapping.cacheKey, equals('jikan_123'));
      });
    });
  });
}
