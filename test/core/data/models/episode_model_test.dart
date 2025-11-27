import 'package:flutter_test/flutter_test.dart';
import 'package:aniya/core/data/models/episode_model.dart';
import 'package:aniya/core/domain/entities/episode_entity.dart';

void main() {
  group('EpisodeModel', () {
    final tEpisodeModel = EpisodeModel(
      id: 'ep1',
      mediaId: 'media1',
      title: 'Episode 1',
      number: 1,
      thumbnail: 'https://example.com/thumb.jpg',
      duration: 1440,
      releaseDate: DateTime(2024, 1, 1),
    );

    test('should be a subclass of EpisodeEntity', () {
      expect(tEpisodeModel, isA<EpisodeEntity>());
    });

    test('toJson should return a valid JSON map', () {
      final result = tEpisodeModel.toJson();

      expect(result['id'], 'ep1');
      expect(result['mediaId'], 'media1');
      expect(result['title'], 'Episode 1');
      expect(result['number'], 1);
      expect(result['thumbnail'], 'https://example.com/thumb.jpg');
      expect(result['duration'], 1440);
    });

    test('fromJson should return a valid EpisodeModel', () {
      final json = {
        'id': 'ep1',
        'mediaId': 'media1',
        'title': 'Episode 1',
        'number': 1,
        'thumbnail': 'https://example.com/thumb.jpg',
        'duration': 1440,
        'releaseDate': '2024-01-01T00:00:00.000',
      };

      final result = EpisodeModel.fromJson(json);

      expect(result.id, 'ep1');
      expect(result.mediaId, 'media1');
      expect(result.title, 'Episode 1');
      expect(result.number, 1);
    });

    test('toEntity should return a valid EpisodeEntity', () {
      final result = tEpisodeModel.toEntity();

      expect(result, isA<EpisodeEntity>());
      expect(result.id, tEpisodeModel.id);
      expect(result.title, tEpisodeModel.title);
      expect(result.number, tEpisodeModel.number);
    });

    test('should handle sourceProvider field', () {
      final episodeWithProvider = EpisodeModel(
        id: 'ep1',
        mediaId: 'media1',
        title: 'Episode 1',
        number: 1,
        sourceProvider: 'kitsu',
      );

      expect(episodeWithProvider.sourceProvider, 'kitsu');

      final json = episodeWithProvider.toJson();
      expect(json['sourceProvider'], 'kitsu');

      final fromJson = EpisodeModel.fromJson(json);
      expect(fromJson.sourceProvider, 'kitsu');
    });

    test('should handle alternativeData field', () {
      final alternativeData = {
        'anilist': EpisodeData(
          title: 'Alternative Title',
          thumbnail: 'https://example.com/alt-thumb.jpg',
          description: 'Alternative description',
          airDate: DateTime(2024, 1, 2),
        ),
      };

      final episodeWithAltData = EpisodeModel(
        id: 'ep1',
        mediaId: 'media1',
        title: 'Episode 1',
        number: 1,
        alternativeData: alternativeData,
      );

      expect(episodeWithAltData.alternativeData, isNotNull);
      expect(
        episodeWithAltData.alternativeData!['anilist']?.title,
        'Alternative Title',
      );

      final json = episodeWithAltData.toJson();
      expect(json['alternativeData'], isNotNull);
      expect(json['alternativeData']['anilist']['title'], 'Alternative Title');

      final fromJson = EpisodeModel.fromJson(json);
      expect(fromJson.alternativeData, isNotNull);
      expect(fromJson.alternativeData!['anilist']?.title, 'Alternative Title');
      expect(
        fromJson.alternativeData!['anilist']?.thumbnail,
        'https://example.com/alt-thumb.jpg',
      );
    });

    test('copyWith should update fields correctly', () {
      final updated = tEpisodeModel.copyWith(
        sourceProvider: 'tmdb',
        alternativeData: {'jikan': EpisodeData(title: 'Jikan Title')},
      );

      expect(updated.id, tEpisodeModel.id);
      expect(updated.sourceProvider, 'tmdb');
      expect(updated.alternativeData!['jikan']?.title, 'Jikan Title');
    });
  });
}
