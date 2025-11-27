import 'package:flutter_test/flutter_test.dart';
import 'package:aniya/core/utils/provider_priority_config.dart';

void main() {
  group('ProviderPriorityConfig', () {
    group('constructor', () {
      test('creates config with default values', () {
        final config = ProviderPriorityConfig();

        expect(config.episodeThumbnailPriority, [
          'kitsu',
          'anilist',
          'jikan',
          'tmdb',
        ]);
        expect(config.imageQualityPriority, [
          'tmdb',
          'kitsu',
          'anilist',
          'simkl',
        ]);
        expect(config.animeMetadataPriority, [
          'anilist',
          'kitsu',
          'jikan',
          'simkl',
        ]);
        expect(config.mangaChapterPriority, ['kitsu', 'anilist']);
        expect(config.characterPriority, ['anilist', 'jikan', 'kitsu']);
        expect(config.minConfidenceThreshold, 0.8);
      });

      test('creates config with custom values', () {
        final config = ProviderPriorityConfig(
          episodeThumbnailPriority: ['tmdb', 'kitsu'],
          imageQualityPriority: ['anilist', 'tmdb'],
          animeMetadataPriority: ['jikan', 'anilist'],
          mangaChapterPriority: ['anilist'],
          characterPriority: ['kitsu', 'anilist'],
          minConfidenceThreshold: 0.9,
        );

        expect(config.episodeThumbnailPriority, ['tmdb', 'kitsu']);
        expect(config.imageQualityPriority, ['anilist', 'tmdb']);
        expect(config.animeMetadataPriority, ['jikan', 'anilist']);
        expect(config.mangaChapterPriority, ['anilist']);
        expect(config.characterPriority, ['kitsu', 'anilist']);
        expect(config.minConfidenceThreshold, 0.9);
      });

      test('throws error for invalid confidence threshold below 0', () {
        expect(
          () => ProviderPriorityConfig(minConfidenceThreshold: -0.1),
          throwsArgumentError,
        );
      });

      test('throws error for invalid confidence threshold above 1', () {
        expect(
          () => ProviderPriorityConfig(minConfidenceThreshold: 1.1),
          throwsArgumentError,
        );
      });

      test('accepts confidence threshold at boundaries', () {
        final config1 = ProviderPriorityConfig(minConfidenceThreshold: 0.0);
        expect(config1.minConfidenceThreshold, 0.0);

        final config2 = ProviderPriorityConfig(minConfidenceThreshold: 1.0);
        expect(config2.minConfidenceThreshold, 1.0);
      });
    });

    group('defaultConfig factory', () {
      test('creates config with default values', () {
        final config = ProviderPriorityConfig.defaultConfig();

        expect(config.episodeThumbnailPriority, [
          'kitsu',
          'anilist',
          'jikan',
          'tmdb',
        ]);
        expect(config.imageQualityPriority, [
          'tmdb',
          'kitsu',
          'anilist',
          'simkl',
        ]);
        expect(config.animeMetadataPriority, [
          'anilist',
          'kitsu',
          'jikan',
          'simkl',
        ]);
        expect(config.mangaChapterPriority, ['kitsu', 'anilist']);
        expect(config.characterPriority, ['anilist', 'jikan', 'kitsu']);
        expect(config.minConfidenceThreshold, 0.8);
      });
    });

    group('copyWith', () {
      test('creates copy with same values when no overrides', () {
        final original = ProviderPriorityConfig(
          episodeThumbnailPriority: ['tmdb'],
          minConfidenceThreshold: 0.9,
        );
        final copy = original.copyWith();

        expect(
          copy.episodeThumbnailPriority,
          original.episodeThumbnailPriority,
        );
        expect(copy.minConfidenceThreshold, original.minConfidenceThreshold);
      });

      test('creates copy with overridden values', () {
        final original = ProviderPriorityConfig();
        final copy = original.copyWith(
          episodeThumbnailPriority: ['anilist', 'tmdb'],
          minConfidenceThreshold: 0.7,
        );

        expect(copy.episodeThumbnailPriority, ['anilist', 'tmdb']);
        expect(copy.minConfidenceThreshold, 0.7);
        // Other values should remain the same
        expect(copy.imageQualityPriority, original.imageQualityPriority);
        expect(copy.animeMetadataPriority, original.animeMetadataPriority);
      });

      test('allows partial overrides', () {
        final original = ProviderPriorityConfig();
        final copy = original.copyWith(minConfidenceThreshold: 0.85);

        expect(copy.minConfidenceThreshold, 0.85);
        expect(
          copy.episodeThumbnailPriority,
          original.episodeThumbnailPriority,
        );
      });
    });

    group('getPriorityForDataType', () {
      late ProviderPriorityConfig config;

      setUp(() {
        config = ProviderPriorityConfig();
      });

      test('returns episode thumbnail priority for episode types', () {
        expect(
          config.getPriorityForDataType('episode_thumbnail'),
          config.episodeThumbnailPriority,
        );
        expect(
          config.getPriorityForDataType('episode'),
          config.episodeThumbnailPriority,
        );
      });

      test('returns image quality priority for image types', () {
        expect(
          config.getPriorityForDataType('image'),
          config.imageQualityPriority,
        );
        expect(
          config.getPriorityForDataType('cover'),
          config.imageQualityPriority,
        );
        expect(
          config.getPriorityForDataType('banner'),
          config.imageQualityPriority,
        );
      });

      test('returns anime metadata priority for anime types', () {
        expect(
          config.getPriorityForDataType('anime_metadata'),
          config.animeMetadataPriority,
        );
        expect(
          config.getPriorityForDataType('anime'),
          config.animeMetadataPriority,
        );
      });

      test('returns manga chapter priority for chapter types', () {
        expect(
          config.getPriorityForDataType('manga_chapter'),
          config.mangaChapterPriority,
        );
        expect(
          config.getPriorityForDataType('chapter'),
          config.mangaChapterPriority,
        );
      });

      test('returns character priority for character type', () {
        expect(
          config.getPriorityForDataType('character'),
          config.characterPriority,
        );
      });

      test('is case insensitive', () {
        expect(
          config.getPriorityForDataType('EPISODE'),
          config.episodeThumbnailPriority,
        );
        expect(
          config.getPriorityForDataType('Image'),
          config.imageQualityPriority,
        );
      });

      test('returns anime metadata priority for unknown types', () {
        expect(
          config.getPriorityForDataType('unknown_type'),
          config.animeMetadataPriority,
        );
        expect(config.getPriorityForDataType(''), config.animeMetadataPriority);
      });
    });

    group('meetsConfidenceThreshold', () {
      test('returns true for confidence above threshold', () {
        final config = ProviderPriorityConfig(minConfidenceThreshold: 0.8);

        expect(config.meetsConfidenceThreshold(0.9), true);
        expect(config.meetsConfidenceThreshold(1.0), true);
      });

      test('returns true for confidence equal to threshold', () {
        final config = ProviderPriorityConfig(minConfidenceThreshold: 0.8);

        expect(config.meetsConfidenceThreshold(0.8), true);
      });

      test('returns false for confidence below threshold', () {
        final config = ProviderPriorityConfig(minConfidenceThreshold: 0.8);

        expect(config.meetsConfidenceThreshold(0.79), false);
        expect(config.meetsConfidenceThreshold(0.5), false);
        expect(config.meetsConfidenceThreshold(0.0), false);
      });

      test('works with custom threshold', () {
        final config = ProviderPriorityConfig(minConfidenceThreshold: 0.9);

        expect(config.meetsConfidenceThreshold(0.95), true);
        expect(config.meetsConfidenceThreshold(0.9), true);
        expect(config.meetsConfidenceThreshold(0.85), false);
      });
    });

    group('sortProvidersByPriority', () {
      late ProviderPriorityConfig config;

      setUp(() {
        config = ProviderPriorityConfig();
      });

      test('sorts providers according to priority order', () {
        final providers = ['anilist', 'tmdb', 'kitsu'];
        final sorted = config.sortProvidersByPriority(providers, 'episode');

        // Episode priority is ['kitsu', 'anilist', 'jikan', 'tmdb']
        expect(sorted, ['kitsu', 'anilist', 'tmdb']);
      });

      test('handles providers not in priority list', () {
        final providers = ['anilist', 'tmdb', 'kitsu', 'unknown_provider'];
        final sorted = config.sortProvidersByPriority(providers, 'episode');

        // Episode priority is ['kitsu', 'anilist', 'jikan', 'tmdb']
        // unknown_provider should be at the end
        expect(sorted.take(3).toList(), ['kitsu', 'anilist', 'tmdb']);
        expect(sorted.last, 'unknown_provider');
      });

      test('handles subset of priority providers', () {
        final providers = ['tmdb', 'anilist'];
        final sorted = config.sortProvidersByPriority(providers, 'episode');

        // Episode priority is ['kitsu', 'anilist', 'jikan', 'tmdb']
        // kitsu is not in providers, so should be skipped
        expect(sorted, ['anilist', 'tmdb']);
      });

      test('returns empty list for empty input', () {
        final sorted = config.sortProvidersByPriority([], 'episode');
        expect(sorted, isEmpty);
      });

      test('preserves all providers in output', () {
        final providers = ['a', 'b', 'c', 'd', 'e'];
        final sorted = config.sortProvidersByPriority(providers, 'episode');

        expect(sorted.length, providers.length);
        for (final provider in providers) {
          expect(sorted.contains(provider), true);
        }
      });

      test('works with different data types', () {
        final providers = ['anilist', 'tmdb', 'kitsu', 'simkl'];

        // Image priority is ['tmdb', 'kitsu', 'anilist', 'simkl']
        final imageSorted = config.sortProvidersByPriority(providers, 'image');
        expect(imageSorted, ['tmdb', 'kitsu', 'anilist', 'simkl']);

        // Anime metadata priority is ['anilist', 'kitsu', 'jikan', 'simkl']
        final animeSorted = config.sortProvidersByPriority(providers, 'anime');
        expect(animeSorted, ['anilist', 'kitsu', 'simkl', 'tmdb']);
      });
    });

    group('toString', () {
      test('returns string representation', () {
        final config = ProviderPriorityConfig();
        final str = config.toString();

        expect(str, contains('ProviderPriorityConfig'));
        expect(str, contains('episodeThumbnailPriority'));
        expect(str, contains('minConfidenceThreshold'));
      });
    });

    group('equality', () {
      test('equal configs are equal', () {
        final config1 = ProviderPriorityConfig(
          episodeThumbnailPriority: ['kitsu', 'tmdb'],
          minConfidenceThreshold: 0.8,
        );
        final config2 = ProviderPriorityConfig(
          episodeThumbnailPriority: ['kitsu', 'tmdb'],
          minConfidenceThreshold: 0.8,
        );

        expect(config1, equals(config2));
        expect(config1.hashCode, equals(config2.hashCode));
      });

      test('different configs are not equal', () {
        final config1 = ProviderPriorityConfig(minConfidenceThreshold: 0.8);
        final config2 = ProviderPriorityConfig(minConfidenceThreshold: 0.9);

        expect(config1, isNot(equals(config2)));
      });

      test('configs with different priority lists are not equal', () {
        final config1 = ProviderPriorityConfig(
          episodeThumbnailPriority: ['kitsu', 'tmdb'],
        );
        final config2 = ProviderPriorityConfig(
          episodeThumbnailPriority: ['tmdb', 'kitsu'],
        );

        expect(config1, isNot(equals(config2)));
      });

      test('identical configs are equal', () {
        final config = ProviderPriorityConfig();
        expect(config, equals(config));
      });
    });

    group('requirements validation', () {
      test('validates Requirement 10.1: Episode thumbnail priority', () {
        final config = ProviderPriorityConfig();
        expect(config.episodeThumbnailPriority.first, 'kitsu');
      });

      test('validates Requirement 10.2: Image quality priority', () {
        final config = ProviderPriorityConfig();
        expect(config.imageQualityPriority.first, 'tmdb');
      });

      test('validates Requirement 10.3: Anime metadata priority', () {
        final config = ProviderPriorityConfig();
        expect(config.animeMetadataPriority.first, 'anilist');
        final anilistIndex = config.animeMetadataPriority.indexOf('anilist');
        final jikanIndex = config.animeMetadataPriority.indexOf('jikan');
        expect(anilistIndex, lessThan(jikanIndex));
      });

      test('validates Requirement 10.4: Manga chapter priority', () {
        final config = ProviderPriorityConfig();
        expect(config.mangaChapterPriority.first, 'kitsu');
      });

      test('validates Requirement 10.5: Runtime configuration adjustment', () {
        final config = ProviderPriorityConfig();
        final adjusted = config.copyWith(
          episodeThumbnailPriority: ['tmdb', 'kitsu', 'anilist'],
          minConfidenceThreshold: 0.85,
        );

        expect(adjusted.episodeThumbnailPriority, ['tmdb', 'kitsu', 'anilist']);
        expect(adjusted.minConfidenceThreshold, 0.85);
        // Original should be unchanged
        expect(config.episodeThumbnailPriority, [
          'kitsu',
          'anilist',
          'jikan',
          'tmdb',
        ]);
        expect(config.minConfidenceThreshold, 0.8);
      });
    });
  });
}
