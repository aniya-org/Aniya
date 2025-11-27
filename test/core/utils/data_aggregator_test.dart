import 'package:flutter_test/flutter_test.dart';
import 'package:aniya/core/utils/data_aggregator.dart';
import 'package:aniya/core/utils/provider_priority_config.dart';
import 'package:aniya/core/domain/entities/media_details_entity.dart';

void main() {
  group('DataAggregator - mergeImages', () {
    late DataAggregator aggregator;

    setUp(() {
      aggregator = DataAggregator(
        priorityConfig: ProviderPriorityConfig.defaultConfig(),
      );
    });

    test(
      'should use primary images when both cover and banner are present',
      () {
        // Arrange
        final primary = ImageUrls(
          coverImage: 'https://primary.com/cover.jpg',
          bannerImage: 'https://primary.com/banner.jpg',
          sourceProvider: 'anilist',
        );
        final alternatives = <String, ImageUrls>{};

        // Act
        final result = aggregator.mergeImages(
          primary: primary,
          alternatives: alternatives,
        );

        // Assert
        expect(result.coverImage, equals('https://primary.com/cover.jpg'));
        expect(result.bannerImage, equals('https://primary.com/banner.jpg'));
        expect(result.sourceProvider, equals('anilist'));
      },
    );

    test('should fallback to TMDB for missing cover image', () {
      // Arrange
      final primary = ImageUrls(
        coverImage: null,
        bannerImage: 'https://primary.com/banner.jpg',
        sourceProvider: 'anilist',
      );
      final alternatives = <String, ImageUrls>{
        'tmdb': ImageUrls(
          coverImage: 'https://tmdb.com/cover.jpg',
          bannerImage: null,
          sourceProvider: 'tmdb',
        ),
        'kitsu': ImageUrls(
          coverImage: 'https://kitsu.com/cover.jpg',
          bannerImage: null,
          sourceProvider: 'kitsu',
        ),
      };

      // Act
      final result = aggregator.mergeImages(
        primary: primary,
        alternatives: alternatives,
      );

      // Assert
      expect(result.coverImage, equals('https://tmdb.com/cover.jpg'));
      expect(result.bannerImage, equals('https://primary.com/banner.jpg'));
    });

    test('should fallback to Kitsu when TMDB lacks cover image', () {
      // Arrange
      final primary = ImageUrls(
        coverImage: null,
        bannerImage: 'https://primary.com/banner.jpg',
        sourceProvider: 'anilist',
      );
      final alternatives = <String, ImageUrls>{
        'tmdb': ImageUrls(
          coverImage: null,
          bannerImage: null,
          sourceProvider: 'tmdb',
        ),
        'kitsu': ImageUrls(
          coverImage: 'https://kitsu.com/cover.jpg',
          bannerImage: null,
          sourceProvider: 'kitsu',
        ),
      };

      // Act
      final result = aggregator.mergeImages(
        primary: primary,
        alternatives: alternatives,
      );

      // Assert
      expect(result.coverImage, equals('https://kitsu.com/cover.jpg'));
      expect(result.bannerImage, equals('https://primary.com/banner.jpg'));
    });

    test('should fallback to TMDB for missing banner image', () {
      // Arrange
      final primary = ImageUrls(
        coverImage: 'https://primary.com/cover.jpg',
        bannerImage: null,
        sourceProvider: 'anilist',
      );
      final alternatives = <String, ImageUrls>{
        'tmdb': ImageUrls(
          coverImage: null,
          bannerImage: 'https://tmdb.com/banner.jpg',
          sourceProvider: 'tmdb',
        ),
        'kitsu': ImageUrls(
          coverImage: null,
          bannerImage: 'https://kitsu.com/banner.jpg',
          sourceProvider: 'kitsu',
        ),
      };

      // Act
      final result = aggregator.mergeImages(
        primary: primary,
        alternatives: alternatives,
      );

      // Assert
      expect(result.coverImage, equals('https://primary.com/cover.jpg'));
      expect(result.bannerImage, equals('https://tmdb.com/banner.jpg'));
    });

    test('should handle empty string images as missing', () {
      // Arrange
      final primary = ImageUrls(
        coverImage: '',
        bannerImage: '',
        sourceProvider: 'anilist',
      );
      final alternatives = <String, ImageUrls>{
        'tmdb': ImageUrls(
          coverImage: 'https://tmdb.com/cover.jpg',
          bannerImage: 'https://tmdb.com/banner.jpg',
          sourceProvider: 'tmdb',
        ),
      };

      // Act
      final result = aggregator.mergeImages(
        primary: primary,
        alternatives: alternatives,
      );

      // Assert
      expect(result.coverImage, equals('https://tmdb.com/cover.jpg'));
      expect(result.bannerImage, equals('https://tmdb.com/banner.jpg'));
    });

    test(
      'should use non-priority provider when priority providers lack images',
      () {
        // Arrange
        final primary = ImageUrls(
          coverImage: null,
          bannerImage: null,
          sourceProvider: 'anilist',
        );
        final alternatives = <String, ImageUrls>{
          'tmdb': ImageUrls(
            coverImage: null,
            bannerImage: null,
            sourceProvider: 'tmdb',
          ),
          'kitsu': ImageUrls(
            coverImage: null,
            bannerImage: null,
            sourceProvider: 'kitsu',
          ),
          'jikan': ImageUrls(
            coverImage: 'https://jikan.com/cover.jpg',
            bannerImage: 'https://jikan.com/banner.jpg',
            sourceProvider: 'jikan',
          ),
        };

        // Act
        final result = aggregator.mergeImages(
          primary: primary,
          alternatives: alternatives,
        );

        // Assert
        expect(result.coverImage, equals('https://jikan.com/cover.jpg'));
        expect(result.bannerImage, equals('https://jikan.com/banner.jpg'));
      },
    );

    test('should return null images when no provider has images', () {
      // Arrange
      final primary = ImageUrls(
        coverImage: null,
        bannerImage: null,
        sourceProvider: 'anilist',
      );
      final alternatives = <String, ImageUrls>{
        'tmdb': ImageUrls(
          coverImage: null,
          bannerImage: null,
          sourceProvider: 'tmdb',
        ),
      };

      // Act
      final result = aggregator.mergeImages(
        primary: primary,
        alternatives: alternatives,
      );

      // Assert
      expect(result.coverImage, isNull);
      expect(result.bannerImage, isNull);
    });

    test('should handle mixed image availability across providers', () {
      // Arrange
      final primary = ImageUrls(
        coverImage: 'https://primary.com/cover.jpg',
        bannerImage: null,
        sourceProvider: 'anilist',
      );
      final alternatives = <String, ImageUrls>{
        'tmdb': ImageUrls(
          coverImage: 'https://tmdb.com/cover.jpg',
          bannerImage: null,
          sourceProvider: 'tmdb',
        ),
        'kitsu': ImageUrls(
          coverImage: null,
          bannerImage: 'https://kitsu.com/banner.jpg',
          sourceProvider: 'kitsu',
        ),
      };

      // Act
      final result = aggregator.mergeImages(
        primary: primary,
        alternatives: alternatives,
      );

      // Assert
      expect(result.coverImage, equals('https://primary.com/cover.jpg'));
      expect(result.bannerImage, equals('https://kitsu.com/banner.jpg'));
    });
  });

  group('ImageUrls', () {
    test('hasAnyImage should return true when cover image exists', () {
      final imageUrls = ImageUrls(
        coverImage: 'https://example.com/cover.jpg',
        bannerImage: null,
        sourceProvider: 'test',
      );

      expect(imageUrls.hasAnyImage, isTrue);
    });

    test('hasAnyImage should return true when banner image exists', () {
      final imageUrls = ImageUrls(
        coverImage: null,
        bannerImage: 'https://example.com/banner.jpg',
        sourceProvider: 'test',
      );

      expect(imageUrls.hasAnyImage, isTrue);
    });

    test('hasAnyImage should return false when no images exist', () {
      final imageUrls = ImageUrls(
        coverImage: null,
        bannerImage: null,
        sourceProvider: 'test',
      );

      expect(imageUrls.hasAnyImage, isFalse);
    });

    test('hasCoverImage should return true for non-empty cover', () {
      final imageUrls = ImageUrls(
        coverImage: 'https://example.com/cover.jpg',
        bannerImage: null,
        sourceProvider: 'test',
      );

      expect(imageUrls.hasCoverImage, isTrue);
    });

    test('hasCoverImage should return false for empty string', () {
      final imageUrls = ImageUrls(
        coverImage: '',
        bannerImage: null,
        sourceProvider: 'test',
      );

      expect(imageUrls.hasCoverImage, isFalse);
    });

    test('hasBannerImage should return true for non-empty banner', () {
      final imageUrls = ImageUrls(
        coverImage: null,
        bannerImage: 'https://example.com/banner.jpg',
        sourceProvider: 'test',
      );

      expect(imageUrls.hasBannerImage, isTrue);
    });

    test('hasBannerImage should return false for empty string', () {
      final imageUrls = ImageUrls(
        coverImage: null,
        bannerImage: '',
        sourceProvider: 'test',
      );

      expect(imageUrls.hasBannerImage, isFalse);
    });
  });

  group('DataAggregator - mergeCharacters', () {
    late DataAggregator aggregator;

    setUp(() {
      aggregator = DataAggregator(
        priorityConfig: ProviderPriorityConfig.defaultConfig(),
      );
    });

    test('should return empty list when no character lists provided', () {
      // Act
      final result = aggregator.mergeCharacters([]);

      // Assert
      expect(result, isEmpty);
    });

    test('should return empty list when all character lists are empty', () {
      // Act
      final result = aggregator.mergeCharacters([[], [], []]);

      // Assert
      expect(result, isEmpty);
    });

    test('should return single character list unchanged', () {
      // Arrange
      final characters = [
        CharacterEntity(
          id: '1',
          name: 'Naruto Uzumaki',
          role: 'Main',
          image: 'https://example.com/naruto.jpg',
        ),
        CharacterEntity(id: '2', name: 'Sasuke Uchiha', role: 'Main'),
      ];

      // Act
      final result = aggregator.mergeCharacters([characters]);

      // Assert
      expect(result.length, equals(2));
      expect(result[0].name, equals('Naruto Uzumaki'));
      expect(result[1].name, equals('Sasuke Uchiha'));
    });

    test('should deduplicate characters with same name (case-insensitive)', () {
      // Arrange
      final list1 = [
        CharacterEntity(
          id: '1',
          name: 'Naruto Uzumaki',
          role: 'Main',
          image: 'https://example.com/naruto.jpg',
        ),
      ];
      final list2 = [
        CharacterEntity(id: '2', name: 'naruto uzumaki', role: 'Protagonist'),
      ];

      // Act
      final result = aggregator.mergeCharacters([list1, list2]);

      // Assert
      expect(result.length, equals(1));
      expect(result[0].name, equals('Naruto Uzumaki'));
    });

    test(
      'should keep character with more complete information when deduplicating',
      () {
        // Arrange
        final list1 = [
          CharacterEntity(id: '1', name: 'Naruto Uzumaki', role: 'Main'),
        ];
        final list2 = [
          CharacterEntity(
            id: '2',
            name: 'Naruto Uzumaki',
            role: 'Main',
            image: 'https://example.com/naruto.jpg',
            nativeName: 'うずまきナルト',
          ),
        ];

        // Act
        final result = aggregator.mergeCharacters([list1, list2]);

        // Assert
        expect(result.length, equals(1));
        expect(result[0].image, equals('https://example.com/naruto.jpg'));
        expect(result[0].nativeName, equals('うずまきナルト'));
      },
    );

    test('should merge multiple character lists with mixed duplicates', () {
      // Arrange
      final list1 = [
        CharacterEntity(id: '1', name: 'Naruto Uzumaki', role: 'Main'),
        CharacterEntity(id: '2', name: 'Sasuke Uchiha', role: 'Main'),
      ];
      final list2 = [
        CharacterEntity(id: '3', name: 'Naruto Uzumaki', role: 'Protagonist'),
        CharacterEntity(id: '4', name: 'Sakura Haruno', role: 'Main'),
      ];
      final list3 = [
        CharacterEntity(id: '5', name: 'Kakashi Hatake', role: 'Supporting'),
      ];

      // Act
      final result = aggregator.mergeCharacters([list1, list2, list3]);

      // Assert
      expect(result.length, equals(4));
      final names = result.map((c) => c.name).toSet();
      expect(names, contains('Naruto Uzumaki'));
      expect(names, contains('Sasuke Uchiha'));
      expect(names, contains('Sakura Haruno'));
      expect(names, contains('Kakashi Hatake'));
    });

    test('should handle characters with extra whitespace in names', () {
      // Arrange
      final list1 = [
        CharacterEntity(id: '1', name: 'Naruto  Uzumaki', role: 'Main'),
      ];
      final list2 = [
        CharacterEntity(id: '2', name: 'Naruto Uzumaki', role: 'Main'),
      ];

      // Act
      final result = aggregator.mergeCharacters([list1, list2]);

      // Assert
      expect(result.length, equals(1));
    });
  });

  group('DataAggregator - mergeStaff', () {
    late DataAggregator aggregator;

    setUp(() {
      aggregator = DataAggregator(
        priorityConfig: ProviderPriorityConfig.defaultConfig(),
      );
    });

    test('should return empty list when no staff lists provided', () {
      // Act
      final result = aggregator.mergeStaff([]);

      // Assert
      expect(result, isEmpty);
    });

    test('should return empty list when all staff lists are empty', () {
      // Act
      final result = aggregator.mergeStaff([[], [], []]);

      // Assert
      expect(result, isEmpty);
    });

    test('should return single staff list unchanged', () {
      // Arrange
      final staff = [
        StaffEntity(
          id: '1',
          name: 'Masashi Kishimoto',
          role: 'Original Creator',
          image: 'https://example.com/kishimoto.jpg',
        ),
        StaffEntity(id: '2', name: 'Hayato Date', role: 'Director'),
      ];

      // Act
      final result = aggregator.mergeStaff([staff]);

      // Assert
      expect(result.length, equals(2));
      expect(result[0].name, equals('Masashi Kishimoto'));
      expect(result[1].name, equals('Hayato Date'));
    });

    test('should deduplicate staff with same name (case-insensitive)', () {
      // Arrange
      final list1 = [
        StaffEntity(
          id: '1',
          name: 'Masashi Kishimoto',
          role: 'Original Creator',
          image: 'https://example.com/kishimoto.jpg',
        ),
      ];
      final list2 = [
        StaffEntity(id: '2', name: 'masashi kishimoto', role: 'Author'),
      ];

      // Act
      final result = aggregator.mergeStaff([list1, list2]);

      // Assert
      expect(result.length, equals(1));
      expect(result[0].name, equals('Masashi Kishimoto'));
    });

    test(
      'should keep staff with more complete information when deduplicating',
      () {
        // Arrange
        final list1 = [
          StaffEntity(id: '1', name: 'Masashi Kishimoto', role: 'Creator'),
        ];
        final list2 = [
          StaffEntity(
            id: '2',
            name: 'Masashi Kishimoto',
            role: 'Original Creator',
            image: 'https://example.com/kishimoto.jpg',
            nativeName: '岸本斉史',
          ),
        ];

        // Act
        final result = aggregator.mergeStaff([list1, list2]);

        // Assert
        expect(result.length, equals(1));
        expect(result[0].image, equals('https://example.com/kishimoto.jpg'));
        expect(result[0].nativeName, equals('岸本斉史'));
      },
    );

    test('should merge multiple staff lists with mixed duplicates', () {
      // Arrange
      final list1 = [
        StaffEntity(id: '1', name: 'Masashi Kishimoto', role: 'Creator'),
        StaffEntity(id: '2', name: 'Hayato Date', role: 'Director'),
      ];
      final list2 = [
        StaffEntity(id: '3', name: 'Masashi Kishimoto', role: 'Author'),
        StaffEntity(id: '4', name: 'Toshio Masuda', role: 'Music'),
      ];
      final list3 = [
        StaffEntity(id: '5', name: 'Tetsuya Nishio', role: 'Character Design'),
      ];

      // Act
      final result = aggregator.mergeStaff([list1, list2, list3]);

      // Assert
      expect(result.length, equals(4));
      final names = result.map((s) => s.name).toSet();
      expect(names, contains('Masashi Kishimoto'));
      expect(names, contains('Hayato Date'));
      expect(names, contains('Toshio Masuda'));
      expect(names, contains('Tetsuya Nishio'));
    });
  });

  group('DataAggregator - mergeRecommendations', () {
    late DataAggregator aggregator;

    setUp(() {
      aggregator = DataAggregator(
        priorityConfig: ProviderPriorityConfig.defaultConfig(),
      );
    });

    test('should return empty list when no recommendation lists provided', () {
      // Act
      final result = aggregator.mergeRecommendations([]);

      // Assert
      expect(result, isEmpty);
    });

    test(
      'should return empty list when all recommendation lists are empty',
      () {
        // Act
        final result = aggregator.mergeRecommendations([[], [], []]);

        // Assert
        expect(result, isEmpty);
      },
    );

    test('should return single recommendation list unchanged', () {
      // Arrange
      final recommendations = [
        RecommendationEntity(
          id: '1',
          title: 'Bleach',
          coverImage: 'https://example.com/bleach.jpg',
          rating: 85,
        ),
        RecommendationEntity(
          id: '2',
          title: 'One Piece',
          coverImage: 'https://example.com/onepiece.jpg',
          rating: 90,
        ),
      ];

      // Act
      final result = aggregator.mergeRecommendations([recommendations]);

      // Assert
      expect(result.length, equals(2));
      expect(result[0].title, equals('Bleach'));
      expect(result[1].title, equals('One Piece'));
    });

    test(
      'should deduplicate recommendations with same title (case-insensitive)',
      () {
        // Arrange
        final list1 = [
          RecommendationEntity(
            id: '1',
            title: 'Bleach',
            coverImage: 'https://example.com/bleach.jpg',
            rating: 85,
          ),
        ];
        final list2 = [
          RecommendationEntity(
            id: '2',
            title: 'bleach',
            coverImage: 'https://example.com/bleach2.jpg',
            rating: 80,
          ),
        ];

        // Act
        final result = aggregator.mergeRecommendations([list1, list2]);

        // Assert
        expect(result.length, equals(1));
        expect(result[0].title, equals('Bleach'));
      },
    );

    test(
      'should keep recommendation with higher rating when deduplicating',
      () {
        // Arrange
        final list1 = [
          RecommendationEntity(
            id: '1',
            title: 'Bleach',
            coverImage: 'https://example.com/bleach.jpg',
            rating: 85,
          ),
        ];
        final list2 = [
          RecommendationEntity(
            id: '2',
            title: 'Bleach',
            coverImage: 'https://example.com/bleach2.jpg',
            rating: 90,
          ),
        ];

        // Act
        final result = aggregator.mergeRecommendations([list1, list2]);

        // Assert
        expect(result.length, equals(1));
        expect(result[0].rating, equals(90));
      },
    );

    test(
      'should merge multiple recommendation lists with mixed duplicates',
      () {
        // Arrange
        final list1 = [
          RecommendationEntity(
            id: '1',
            title: 'Bleach',
            coverImage: 'https://example.com/bleach.jpg',
            rating: 85,
          ),
          RecommendationEntity(
            id: '2',
            title: 'One Piece',
            coverImage: 'https://example.com/onepiece.jpg',
            rating: 90,
          ),
        ];
        final list2 = [
          RecommendationEntity(
            id: '3',
            title: 'Bleach',
            coverImage: 'https://example.com/bleach2.jpg',
            rating: 80,
          ),
          RecommendationEntity(
            id: '4',
            title: 'Dragon Ball Z',
            coverImage: 'https://example.com/dbz.jpg',
            rating: 88,
          ),
        ];
        final list3 = [
          RecommendationEntity(
            id: '5',
            title: 'Hunter x Hunter',
            coverImage: 'https://example.com/hxh.jpg',
            rating: 92,
          ),
        ];

        // Act
        final result = aggregator.mergeRecommendations([list1, list2, list3]);

        // Assert
        expect(result.length, equals(4));
        final titles = result.map((r) => r.title).toSet();
        expect(titles, contains('Bleach'));
        expect(titles, contains('One Piece'));
        expect(titles, contains('Dragon Ball Z'));
        expect(titles, contains('Hunter x Hunter'));
      },
    );
  });
}
