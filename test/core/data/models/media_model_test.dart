import 'package:flutter_test/flutter_test.dart';
import 'package:aniya/core/data/models/media_model.dart';
import 'package:aniya/core/domain/entities/media_entity.dart';

void main() {
  group('MediaModel', () {
    final tMediaModel = MediaModel(
      id: '1',
      title: 'Test Anime',
      coverImage: 'https://example.com/cover.jpg',
      bannerImage: 'https://example.com/banner.jpg',
      description: 'Test description',
      type: MediaType.anime,
      rating: 8.5,
      genres: ['Action', 'Adventure'],
      status: MediaStatus.ongoing,
      totalEpisodes: 24,
      totalChapters: null,
      sourceId: 'source1',
      sourceName: 'Test Source',
    );

    test('should be a subclass of MediaEntity', () {
      expect(tMediaModel, isA<MediaEntity>());
    });

    test('toJson should return a valid JSON map', () {
      final result = tMediaModel.toJson();

      expect(result, {
        'id': '1',
        'title': 'Test Anime',
        'coverImage': 'https://example.com/cover.jpg',
        'bannerImage': 'https://example.com/banner.jpg',
        'description': 'Test description',
        'type': 'anime',
        'rating': 8.5,
        'genres': ['Action', 'Adventure'],
        'status': 'ongoing',
        'totalEpisodes': 24,
        'totalChapters': null,
        'sourceId': 'source1',
        'sourceName': 'Test Source',
      });
    });

    test('fromJson should return a valid MediaModel', () {
      final json = {
        'id': '1',
        'title': 'Test Anime',
        'coverImage': 'https://example.com/cover.jpg',
        'bannerImage': 'https://example.com/banner.jpg',
        'description': 'Test description',
        'type': 'anime',
        'rating': 8.5,
        'genres': ['Action', 'Adventure'],
        'status': 'ongoing',
        'totalEpisodes': 24,
        'totalChapters': null,
        'sourceId': 'source1',
        'sourceName': 'Test Source',
      };

      final result = MediaModel.fromJson(json);

      expect(result, tMediaModel);
    });

    test('toEntity should return a valid MediaEntity', () {
      final result = tMediaModel.toEntity();

      expect(result, isA<MediaEntity>());
      expect(result.id, tMediaModel.id);
      expect(result.title, tMediaModel.title);
      expect(result.type, tMediaModel.type);
    });
  });
}
