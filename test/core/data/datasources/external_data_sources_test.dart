import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:aniya/core/data/datasources/anilist_external_data_source.dart';
import 'package:aniya/core/data/datasources/jikan_external_data_source.dart';
import 'package:aniya/core/data/datasources/kitsu_external_data_source.dart';
import 'package:aniya/core/data/datasources/simkl_external_data_source.dart';
import 'package:aniya/core/data/datasources/tmdb_external_data_source.dart';
import 'package:aniya/core/domain/entities/media_entity.dart';

void main() {
  setUpAll(() async {
    // Load environment variables
    await dotenv.load(fileName: '.env');
  });

  group('External Data Sources Search Tests', () {
    test('AniList search for anime should return results', () async {
      // Arrange
      final dataSource = AnilistExternalDataSourceImpl();
      const query = 'Naruto';
      const type = MediaType.anime;

      // Act
      final result = await dataSource.searchMedia(query, type, perPage: 5);

      // Assert
      expect(result.items, isNotEmpty);
      expect(result.items.first.title, contains('Naruto'));
      expect(result.items.first.type, MediaType.anime);
      expect(result.items.first.sourceId, 'anilist');
      print('✅ AniList search returned ${result.items.length} results');
      print('   First result: ${result.items.first.title}');
    });

    test('Jikan search for anime should return results', () async {
      // Arrange
      final dataSource = JikanExternalDataSourceImpl();
      const query = 'Naruto';
      const type = MediaType.anime;

      // Act
      final result = await dataSource.searchMedia(query, type, perPage: 5);

      // Assert
      expect(result.items, isNotEmpty);
      expect(result.items.first.type, MediaType.anime);
      expect(result.items.first.sourceId, 'jikan');
      print('✅ Jikan search returned ${result.items.length} results');
      print('   First result: ${result.items.first.title}');
    });

    test('Kitsu search for anime should return results', () async {
      // Arrange
      final dataSource = KitsuExternalDataSourceImpl();
      const query = 'Naruto';
      const type = MediaType.anime;

      // Act
      final result = await dataSource.searchMedia(query, type, perPage: 5);

      // Assert
      expect(result.items, isNotEmpty);
      expect(result.items.first.type, MediaType.anime);
      expect(result.items.first.sourceId, 'kitsu');
      print('✅ Kitsu search returned ${result.items.length} results');
      print('   First result: ${result.items.first.title}');
    });

    test('Simkl search for anime should return results', () async {
      // Arrange
      final dataSource = SimklExternalDataSourceImpl();
      const query = 'Naruto';
      const type = MediaType.anime;

      // Act
      final result = await dataSource.searchMedia(query, type, perPage: 5);

      // Assert
      expect(result.items, isNotEmpty);
      expect(result.items.first.type, MediaType.anime);
      expect(result.items.first.sourceId, 'simkl');
      print('✅ Simkl search returned ${result.items.length} results');
      print('   First result: ${result.items.first.title}');
    });

    test('TMDB search for movies should return results', () async {
      // Arrange
      final dataSource = TmdbExternalDataSourceImpl();
      const query = 'Inception';
      const type = MediaType.movie;

      // Act
      final result = await dataSource.searchMedia(query, type, perPage: 5);

      // Assert
      expect(result.items, isNotEmpty);
      expect(result.items.first.title, contains('Inception'));
      expect(result.items.first.type, MediaType.movie);
      expect(result.items.first.sourceId, 'tmdb');
      print('✅ TMDB search returned ${result.items.length} results');
      print('   First result: ${result.items.first.title}');
    });

    test('AniList search for manga should return results', () async {
      // Arrange
      final dataSource = AnilistExternalDataSourceImpl();
      const query = 'One Piece';
      const type = MediaType.manga;

      // Act
      final result = await dataSource.searchMedia(query, type, perPage: 5);

      // Assert
      expect(result.items, isNotEmpty);
      expect(result.items.first.type, MediaType.manga);
      expect(result.items.first.sourceId, 'anilist');
      print('✅ AniList manga search returned ${result.items.length} results');
      print('   First result: ${result.items.first.title}');
    });
  });
}
