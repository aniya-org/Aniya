import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:aniya/core/data/datasources/library_local_data_source.dart';
import 'package:aniya/core/data/repositories/library_repository_impl.dart';
import 'package:aniya/core/domain/entities/library_item_entity.dart';
import 'package:aniya/core/domain/entities/media_entity.dart';
import 'package:aniya/core/data/models/library_item_model.dart';

void main() {
  group('Playback Position Saving', () {
    late Box<Map<dynamic, dynamic>> libraryBox;
    late Box<int> playbackBox;
    late Box<int> readingBox;
    late LibraryLocalDataSourceImpl dataSource;
    late LibraryRepositoryImpl repository;

    setUp(() async {
      // Initialize Hive for testing
      Hive.init('./test/hive_test');

      // Open test boxes
      libraryBox = await Hive.openBox<Map<dynamic, dynamic>>('test_library');
      playbackBox = await Hive.openBox<int>('test_playback');
      readingBox = await Hive.openBox<int>('test_reading');

      // Create data source and repository
      dataSource = LibraryLocalDataSourceImpl(
        box: libraryBox,
        playbackBox: playbackBox,
        readingBox: readingBox,
      );
      repository = LibraryRepositoryImpl(localDataSource: dataSource);
    });

    tearDown(() async {
      // Clean up
      await libraryBox.clear();
      await playbackBox.clear();
      await readingBox.clear();
      await libraryBox.close();
      await playbackBox.close();
      await readingBox.close();
      await Hive.deleteFromDisk();
    });

    test('should save and retrieve playback position', () async {
      // Arrange
      final testMedia = MediaEntity(
        id: 'test_media_1',
        title: 'Test Anime',
        type: MediaType.anime,
        sourceId: 'test_source',
        sourceName: 'Test Source',
        genres: [],
        status: MediaStatus.ongoing,
      );

      final libraryItem = LibraryItemEntity(
        id: 'test_item_1',
        media: testMedia,
        status: LibraryStatus.watching,
        currentEpisode: 1,
        currentChapter: 0,
        addedAt: DateTime.now(),
      );

      // Add item to library first
      await dataSource.addToLibrary(
        LibraryItemModel(
          id: libraryItem.id,
          media: libraryItem.media,
          status: libraryItem.status,
          currentEpisode: libraryItem.currentEpisode,
          currentChapter: libraryItem.currentChapter,
          addedAt: libraryItem.addedAt,
        ),
      );

      const testPosition = 120000; // 2 minutes in milliseconds
      const episodeId = 'episode_1';

      // Act - Save playback position
      final saveResult = await repository.savePlaybackPosition(
        libraryItem.id,
        episodeId,
        testPosition,
      );

      // Assert - Save should succeed
      expect(saveResult.isRight(), true);

      // Act - Retrieve playback position
      final getResult = await repository.getPlaybackPosition(
        libraryItem.id,
        episodeId,
      );

      // Assert - Retrieved position should match saved position
      expect(getResult.isRight(), true);
      getResult.fold(
        (failure) => fail('Should not fail: ${failure.message}'),
        (position) => expect(position, testPosition),
      );
    });

    test('should return 0 for non-existent playback position', () async {
      // Arrange
      final testMedia = MediaEntity(
        id: 'test_media_2',
        title: 'Test Anime 2',
        type: MediaType.anime,
        sourceId: 'test_source',
        sourceName: 'Test Source',
        genres: [],
        status: MediaStatus.ongoing,
      );

      final libraryItem = LibraryItemEntity(
        id: 'test_item_2',
        media: testMedia,
        status: LibraryStatus.watching,
        currentEpisode: 1,
        currentChapter: 0,
        addedAt: DateTime.now(),
      );

      // Add item to library
      await dataSource.addToLibrary(
        LibraryItemModel(
          id: libraryItem.id,
          media: libraryItem.media,
          status: libraryItem.status,
          currentEpisode: libraryItem.currentEpisode,
          currentChapter: libraryItem.currentChapter,
          addedAt: libraryItem.addedAt,
        ),
      );

      const episodeId = 'episode_never_watched';

      // Act - Try to get position for episode that was never watched
      final getResult = await repository.getPlaybackPosition(
        libraryItem.id,
        episodeId,
      );

      // Assert - Should return 0 (default position)
      expect(getResult.isRight(), true);
      getResult.fold(
        (failure) => fail('Should not fail: ${failure.message}'),
        (position) => expect(position, 0),
      );
    });

    test('should update playback position when saved multiple times', () async {
      // Arrange
      final testMedia = MediaEntity(
        id: 'test_media_3',
        title: 'Test Anime 3',
        type: MediaType.anime,
        sourceId: 'test_source',
        sourceName: 'Test Source',
        genres: [],
        status: MediaStatus.ongoing,
      );

      final libraryItem = LibraryItemEntity(
        id: 'test_item_3',
        media: testMedia,
        status: LibraryStatus.watching,
        currentEpisode: 1,
        currentChapter: 0,
        addedAt: DateTime.now(),
      );

      // Add item to library
      await dataSource.addToLibrary(
        LibraryItemModel(
          id: libraryItem.id,
          media: libraryItem.media,
          status: libraryItem.status,
          currentEpisode: libraryItem.currentEpisode,
          currentChapter: libraryItem.currentChapter,
          addedAt: libraryItem.addedAt,
        ),
      );

      const episodeId = 'episode_1';
      const firstPosition = 60000; // 1 minute
      const secondPosition = 180000; // 3 minutes

      // Act - Save first position
      await repository.savePlaybackPosition(
        libraryItem.id,
        episodeId,
        firstPosition,
      );

      // Act - Save second position (simulating auto-save)
      await repository.savePlaybackPosition(
        libraryItem.id,
        episodeId,
        secondPosition,
      );

      // Act - Retrieve position
      final getResult = await repository.getPlaybackPosition(
        libraryItem.id,
        episodeId,
      );

      // Assert - Should return the latest position
      expect(getResult.isRight(), true);
      getResult.fold(
        (failure) => fail('Should not fail: ${failure.message}'),
        (position) => expect(position, secondPosition),
      );
    });
  });
}
