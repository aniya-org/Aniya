import 'package:flutter_test/flutter_test.dart';
import 'package:aniya/core/utils/cross_provider_matcher.dart';
import 'package:aniya/core/domain/entities/media_entity.dart';

void main() {
  late CrossProviderMatcher matcher;

  setUp(() {
    matcher = CrossProviderMatcher();
  });

  group('CrossProviderMatcher', () {
    group('levenshteinDistance', () {
      test('returns 0 for identical strings', () {
        expect(matcher.levenshteinDistance('hello', 'hello'), 0);
      });

      test('returns length for empty string comparison', () {
        expect(matcher.levenshteinDistance('', 'hello'), 5);
        expect(matcher.levenshteinDistance('hello', ''), 5);
      });

      test('calculates correct distance for different strings', () {
        expect(matcher.levenshteinDistance('kitten', 'sitting'), 3);
        expect(matcher.levenshteinDistance('saturday', 'sunday'), 3);
      });

      test('is symmetric', () {
        final d1 = matcher.levenshteinDistance('hello', 'world');
        final d2 = matcher.levenshteinDistance('world', 'hello');
        expect(d1, d2);
      });
    });

    group('normalizeTitle', () {
      test('converts to lowercase', () {
        expect(matcher.normalizeTitle('NARUTO'), 'naruto');
        expect(matcher.normalizeTitle('One Piece'), 'one piece');
      });

      test('removes special characters', () {
        expect(matcher.normalizeTitle('Attack on Titan!'), 'attack on titan');
        expect(matcher.normalizeTitle('Re:Zero'), 'rezero');
        expect(
          matcher.normalizeTitle('Sword Art Online: Alicization'),
          'sword art online alicization',
        );
      });

      test('removes year suffixes', () {
        expect(matcher.normalizeTitle('Naruto (2023)'), 'naruto');
        expect(matcher.normalizeTitle('One Piece - 2023'), 'one piece');
        expect(
          matcher.normalizeTitle('Attack on Titan [2013]'),
          'attack on titan',
        );
      });

      test('removes season indicators', () {
        expect(matcher.normalizeTitle('Naruto Season 2'), 'naruto');
        expect(matcher.normalizeTitle('One Piece S2'), 'one piece');
        expect(
          matcher.normalizeTitle('Attack on Titan 2nd Season'),
          'attack on titan',
        );
      });

      test('collapses multiple spaces', () {
        expect(matcher.normalizeTitle('One    Piece'), 'one piece');
        expect(matcher.normalizeTitle('  Naruto  '), 'naruto');
      });

      test('handles complex titles', () {
        expect(
          matcher.normalizeTitle(
            'Sword Art Online: Alicization - War of Underworld (2020) Season 2',
          ),
          'sword art online alicization war of underworld',
        );
      });
    });

    group('calculateMatchConfidence', () {
      test('returns 1.0 for identical titles', () {
        final confidence = matcher.calculateMatchConfidence(
          sourceTitle: 'Naruto',
          targetTitle: 'Naruto',
        );
        expect(confidence, 0.8); // 0.8 from title similarity only
      });

      test('returns high confidence for similar titles', () {
        final confidence = matcher.calculateMatchConfidence(
          sourceTitle: 'Naruto Shippuden',
          targetTitle: 'Naruto: Shippuden',
        );
        expect(confidence, greaterThan(0.7));
      });

      test('adds year bonus for matching years', () {
        final withYear = matcher.calculateMatchConfidence(
          sourceTitle: 'Naruto',
          targetTitle: 'Naruto',
          sourceYear: 2023,
          targetYear: 2023,
        );
        final withoutYear = matcher.calculateMatchConfidence(
          sourceTitle: 'Naruto',
          targetTitle: 'Naruto',
        );
        expect(withYear, greaterThan(withoutYear));
      });

      test('adds type bonus for matching types', () {
        final withType = matcher.calculateMatchConfidence(
          sourceTitle: 'Naruto',
          targetTitle: 'Naruto',
          sourceType: MediaType.anime,
          targetType: MediaType.anime,
        );
        final withoutType = matcher.calculateMatchConfidence(
          sourceTitle: 'Naruto',
          targetTitle: 'Naruto',
        );
        expect(withType, greaterThan(withoutType));
      });

      test('returns value between 0.0 and 1.0', () {
        final confidence = matcher.calculateMatchConfidence(
          sourceTitle: 'Completely Different Title',
          targetTitle: 'Another Unrelated Show',
        );
        expect(confidence, greaterThanOrEqualTo(0.0));
        expect(confidence, lessThanOrEqualTo(1.0));
      });

      test('uses English titles when available', () {
        final confidence = matcher.calculateMatchConfidence(
          sourceTitle: '進撃の巨人',
          targetTitle: 'Shingeki no Kyojin',
          sourceEnglishTitle: 'Attack on Titan',
          targetEnglishTitle: 'Attack on Titan',
        );
        expect(confidence, greaterThanOrEqualTo(0.8));
      });

      test('uses Romaji titles when available', () {
        final confidence = matcher.calculateMatchConfidence(
          sourceTitle: 'Naruto',
          targetTitle: 'Naruto',
          sourceRomajiTitle: 'Naruto Shippuuden',
          targetRomajiTitle: 'Naruto Shippuden',
        );
        expect(confidence, greaterThan(0.7));
      });
    });

    group('isHighConfidenceMatch', () {
      test('returns true for confidence >= 0.8', () {
        expect(matcher.isHighConfidenceMatch(0.8), true);
        expect(matcher.isHighConfidenceMatch(0.9), true);
        expect(matcher.isHighConfidenceMatch(1.0), true);
      });

      test('returns false for confidence < 0.8', () {
        expect(matcher.isHighConfidenceMatch(0.79), false);
        expect(matcher.isHighConfidenceMatch(0.5), false);
        expect(matcher.isHighConfidenceMatch(0.0), false);
      });
    });

    group('findBestMatch', () {
      test('returns null for empty list', () {
        expect(matcher.findBestMatch([]), null);
      });

      test('returns highest confidence match', () {
        final matches = [
          ProviderMatch(
            providerId: 'provider1',
            providerMediaId: '1',
            confidence: 0.7,
            matchedTitle: 'Title 1',
          ),
          ProviderMatch(
            providerId: 'provider2',
            providerMediaId: '2',
            confidence: 0.9,
            matchedTitle: 'Title 2',
          ),
          ProviderMatch(
            providerId: 'provider3',
            providerMediaId: '3',
            confidence: 0.85,
            matchedTitle: 'Title 3',
          ),
        ];

        final best = matcher.findBestMatch(matches);
        expect(best?.providerId, 'provider2');
        expect(best?.confidence, 0.9);
      });

      test('returns null if best match is below threshold', () {
        final matches = [
          ProviderMatch(
            providerId: 'provider1',
            providerMediaId: '1',
            confidence: 0.7,
            matchedTitle: 'Title 1',
          ),
          ProviderMatch(
            providerId: 'provider2',
            providerMediaId: '2',
            confidence: 0.75,
            matchedTitle: 'Title 2',
          ),
        ];

        final best = matcher.findBestMatch(matches);
        expect(best, null);
      });
    });

    group('findMatches', () {
      test('searches all providers except primary source', () async {
        final searchedProviders = <String>[];

        Future<List<MediaEntity>> mockSearch(
          String query,
          String providerId,
          MediaType type,
        ) async {
          searchedProviders.add(providerId);
          return [];
        }

        await matcher.findMatches(
          title: 'Naruto',
          type: MediaType.anime,
          primarySourceId: 'anilist',
          searchFunction: mockSearch,
        );

        // Should search all providers except anilist
        expect(searchedProviders.contains('anilist'), false);
        expect(searchedProviders.contains('tmdb'), true);
        expect(searchedProviders.contains('jikan'), true);
        expect(searchedProviders.contains('kitsu'), true);
        expect(searchedProviders.contains('simkl'), true);
      });

      test('returns only high-confidence matches', () async {
        Future<List<MediaEntity>> mockSearch(
          String query,
          String providerId,
          MediaType type,
        ) async {
          if (providerId == 'kitsu') {
            // High confidence match
            return [
              const MediaEntity(
                id: '1',
                title: 'Naruto',
                type: MediaType.anime,
                genres: [],
                status: MediaStatus.completed,
                sourceId: 'kitsu',
                sourceName: 'Kitsu',
              ),
            ];
          } else if (providerId == 'jikan') {
            // Low confidence match
            return [
              const MediaEntity(
                id: '2',
                title: 'Completely Different Show',
                type: MediaType.anime,
                genres: [],
                status: MediaStatus.completed,
                sourceId: 'jikan',
                sourceName: 'Jikan',
              ),
            ];
          }
          return [];
        }

        final matches = await matcher.findMatches(
          title: 'Naruto',
          type: MediaType.anime,
          primarySourceId: 'anilist',
          searchFunction: mockSearch,
        );

        // Should only include kitsu (high confidence)
        expect(matches.containsKey('kitsu'), true);
        expect(matches.containsKey('jikan'), false);
      });

      test('handles provider failures gracefully', () async {
        Future<List<MediaEntity>> mockSearch(
          String query,
          String providerId,
          MediaType type,
        ) async {
          if (providerId == 'kitsu') {
            throw Exception('Provider error');
          }
          return [
            MediaEntity(
              id: '1',
              title: 'Naruto',
              type: MediaType.anime,
              genres: const [],
              status: MediaStatus.completed,
              sourceId: providerId,
              sourceName: providerId,
            ),
          ];
        }

        final matches = await matcher.findMatches(
          title: 'Naruto',
          type: MediaType.anime,
          primarySourceId: 'anilist',
          searchFunction: mockSearch,
        );

        // Should have matches from other providers despite kitsu failure
        expect(matches.isNotEmpty, true);
        expect(matches.containsKey('kitsu'), false);
      });

      test('handles timeout gracefully', () async {
        Future<List<MediaEntity>> mockSearch(
          String query,
          String providerId,
          MediaType type,
        ) async {
          if (providerId == 'tmdb') {
            // Simulate timeout
            await Future.delayed(const Duration(seconds: 15));
          }
          return [
            MediaEntity(
              id: '1',
              title: 'Naruto',
              type: MediaType.anime,
              genres: const [],
              status: MediaStatus.completed,
              sourceId: providerId,
              sourceName: providerId,
            ),
          ];
        }

        final matches = await matcher.findMatches(
          title: 'Naruto',
          type: MediaType.anime,
          primarySourceId: 'anilist',
          searchFunction: mockSearch,
        );

        // Should have matches from other providers despite tmdb timeout
        expect(matches.containsKey('tmdb'), false);
      });

      test('filters by confidence threshold (>= 0.8)', () async {
        Future<List<MediaEntity>> mockSearch(
          String query,
          String providerId,
          MediaType type,
        ) async {
          return [
            MediaEntity(
              id: '1',
              title: providerId == 'kitsu' ? 'Naruto' : 'Naruto Shippuden',
              type: MediaType.anime,
              genres: const [],
              status: MediaStatus.completed,
              sourceId: providerId,
              sourceName: providerId,
            ),
          ];
        }

        final matches = await matcher.findMatches(
          title: 'Naruto',
          type: MediaType.anime,
          primarySourceId: 'anilist',
          searchFunction: mockSearch,
        );

        // All matches should have confidence >= 0.8
        for (final match in matches.values) {
          expect(match.confidence, greaterThanOrEqualTo(0.8));
        }
      });

      test('returns empty map when no high-confidence matches found', () async {
        Future<List<MediaEntity>> mockSearch(
          String query,
          String providerId,
          MediaType type,
        ) async {
          return [
            MediaEntity(
              id: '1',
              title: 'Completely Different Show',
              type: MediaType.anime,
              genres: const [],
              status: MediaStatus.completed,
              sourceId: providerId,
              sourceName: providerId,
            ),
          ];
        }

        final matches = await matcher.findMatches(
          title: 'Naruto',
          type: MediaType.anime,
          primarySourceId: 'anilist',
          searchFunction: mockSearch,
        );

        expect(matches.isEmpty, true);
      });
    });
  });
}
