import 'package:flutter_test/flutter_test.dart';
import 'package:aniya/core/data/models/repository_config_model.dart';

void main() {
  group('RepositoryConfig', () {
    test('should create RepositoryConfig with all fields', () {
      const config = RepositoryConfig(
        animeRepoUrl: 'https://example.com/anime',
        mangaRepoUrl: 'https://example.com/manga',
        novelRepoUrl: 'https://example.com/novel',
      );

      expect(config.animeRepoUrl, 'https://example.com/anime');
      expect(config.mangaRepoUrl, 'https://example.com/manga');
      expect(config.novelRepoUrl, 'https://example.com/novel');
    });

    test('empty constructor should create config with no URLs', () {
      const config = RepositoryConfig.empty();

      expect(config.animeRepoUrl, isNull);
      expect(config.mangaRepoUrl, isNull);
      expect(config.novelRepoUrl, isNull);
      expect(config.hasAnyUrl, false);
    });

    test('hasAnyUrl should return true when at least one URL is provided', () {
      const config = RepositoryConfig(
        animeRepoUrl: 'https://example.com/anime',
      );

      expect(config.hasAnyUrl, true);
    });

    test('hasAnyUrl should return false when no URLs are provided', () {
      const config = RepositoryConfig();

      expect(config.hasAnyUrl, false);
    });

    test('hasAllUrls should return true when all URLs are provided', () {
      const config = RepositoryConfig(
        animeRepoUrl: 'https://example.com/anime',
        mangaRepoUrl: 'https://example.com/manga',
        novelRepoUrl: 'https://example.com/novel',
      );

      expect(config.hasAllUrls, true);
    });

    test('hasAllUrls should return false when not all URLs are provided', () {
      const config = RepositoryConfig(
        animeRepoUrl: 'https://example.com/anime',
        mangaRepoUrl: 'https://example.com/manga',
      );

      expect(config.hasAllUrls, false);
    });

    test('allUrls should return list of all non-null URLs', () {
      const config = RepositoryConfig(
        animeRepoUrl: 'https://example.com/anime',
        novelRepoUrl: 'https://example.com/novel',
      );

      expect(config.allUrls, [
        'https://example.com/anime',
        'https://example.com/novel',
      ]);
    });

    test('fromJson should create RepositoryConfig from JSON', () {
      final json = {
        'animeRepoUrl': 'https://example.com/anime',
        'mangaRepoUrl': 'https://example.com/manga',
        'novelRepoUrl': 'https://example.com/novel',
      };

      final config = RepositoryConfig.fromJson(json);

      expect(config.animeRepoUrl, 'https://example.com/anime');
      expect(config.mangaRepoUrl, 'https://example.com/manga');
      expect(config.novelRepoUrl, 'https://example.com/novel');
    });

    test('fromJson should handle missing fields', () {
      final json = <String, dynamic>{
        'animeRepoUrl': 'https://example.com/anime',
      };

      final config = RepositoryConfig.fromJson(json);

      expect(config.animeRepoUrl, 'https://example.com/anime');
      expect(config.mangaRepoUrl, isNull);
      expect(config.novelRepoUrl, isNull);
    });

    test('toJson should return valid JSON map', () {
      const config = RepositoryConfig(
        animeRepoUrl: 'https://example.com/anime',
        mangaRepoUrl: 'https://example.com/manga',
        novelRepoUrl: 'https://example.com/novel',
      );

      final json = config.toJson();

      expect(json, {
        'animeRepoUrl': 'https://example.com/anime',
        'mangaRepoUrl': 'https://example.com/manga',
        'novelRepoUrl': 'https://example.com/novel',
        // CloudStream-specific fields (null when not set)
        'movieRepoUrl': null,
        'tvShowRepoUrl': null,
        'cartoonRepoUrl': null,
        'documentaryRepoUrl': null,
        'livestreamRepoUrl': null,
        'nsfwRepoUrl': null,
      });
    });

    test('copyWith should return new instance with updated values', () {
      const config = RepositoryConfig(
        animeRepoUrl: 'https://example.com/anime',
        mangaRepoUrl: 'https://example.com/manga',
      );

      final updated = config.copyWith(
        mangaRepoUrl: 'https://example.com/manga-new',
        novelRepoUrl: 'https://example.com/novel',
      );

      expect(updated.animeRepoUrl, 'https://example.com/anime');
      expect(updated.mangaRepoUrl, 'https://example.com/manga-new');
      expect(updated.novelRepoUrl, 'https://example.com/novel');
    });

    test('copyWith with clear flags should set URLs to null', () {
      const config = RepositoryConfig(
        animeRepoUrl: 'https://example.com/anime',
        mangaRepoUrl: 'https://example.com/manga',
        novelRepoUrl: 'https://example.com/novel',
      );

      final updated = config.copyWith(clearMangaUrl: true);

      expect(updated.animeRepoUrl, 'https://example.com/anime');
      expect(updated.mangaRepoUrl, isNull);
      expect(updated.novelRepoUrl, 'https://example.com/novel');
    });

    test('two RepositoryConfigs with same values should be equal', () {
      const config1 = RepositoryConfig(
        animeRepoUrl: 'https://example.com/anime',
      );
      const config2 = RepositoryConfig(
        animeRepoUrl: 'https://example.com/anime',
      );

      expect(config1, config2);
    });
  });
}
