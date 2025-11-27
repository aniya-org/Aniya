import 'package:flutter_test/flutter_test.dart';
import 'package:aniya/core/domain/entities/entities.dart';
import 'package:aniya/core/enums/tracking_service.dart' as ts;

void main() {
  group('Domain Entities', () {
    group('MediaEntity', () {
      test('should create MediaEntity with required fields', () {
        final media = MediaEntity(
          id: '1',
          title: 'Test Anime',
          type: MediaType.anime,
          genres: ['Action', 'Adventure'],
          status: MediaStatus.ongoing,
          sourceId: 'source1',
          sourceName: 'Test Source',
        );

        expect(media.id, '1');
        expect(media.title, 'Test Anime');
        expect(media.type, MediaType.anime);
        expect(media.genres, ['Action', 'Adventure']);
        expect(media.status, MediaStatus.ongoing);
      });

      test('should support equality comparison', () {
        final media1 = MediaEntity(
          id: '1',
          title: 'Test Anime',
          type: MediaType.anime,
          genres: ['Action'],
          status: MediaStatus.ongoing,
          sourceId: 'source1',
          sourceName: 'Test Source',
        );

        final media2 = MediaEntity(
          id: '1',
          title: 'Test Anime',
          type: MediaType.anime,
          genres: ['Action'],
          status: MediaStatus.ongoing,
          sourceId: 'source1',
          sourceName: 'Test Source',
        );

        expect(media1, equals(media2));
      });
    });

    group('EpisodeEntity', () {
      test('should create EpisodeEntity with required fields', () {
        final episode = EpisodeEntity(
          id: 'ep1',
          mediaId: 'media1',
          title: 'Episode 1',
          number: 1,
        );

        expect(episode.id, 'ep1');
        expect(episode.mediaId, 'media1');
        expect(episode.title, 'Episode 1');
        expect(episode.number, 1);
      });

      test('should create EpisodeEntity with sourceProvider', () {
        final episode = EpisodeEntity(
          id: 'ep1',
          mediaId: 'media1',
          title: 'Episode 1',
          number: 1,
          sourceProvider: 'kitsu',
        );

        expect(episode.sourceProvider, 'kitsu');
      });

      test('should create EpisodeEntity with alternativeData', () {
        final alternativeData = {
          'anilist': EpisodeData(
            title: 'Alternative Title',
            thumbnail: 'https://example.com/thumb.jpg',
          ),
        };

        final episode = EpisodeEntity(
          id: 'ep1',
          mediaId: 'media1',
          title: 'Episode 1',
          number: 1,
          alternativeData: alternativeData,
        );

        expect(episode.alternativeData, isNotNull);
        expect(episode.alternativeData!['anilist']?.title, 'Alternative Title');
      });

      test('copyWith should update fields correctly', () {
        final episode = EpisodeEntity(
          id: 'ep1',
          mediaId: 'media1',
          title: 'Episode 1',
          number: 1,
        );

        final updated = episode.copyWith(
          sourceProvider: 'tmdb',
          alternativeData: {'jikan': EpisodeData(title: 'Jikan Title')},
        );

        expect(updated.id, episode.id);
        expect(updated.sourceProvider, 'tmdb');
        expect(updated.alternativeData!['jikan']?.title, 'Jikan Title');
      });
    });

    group('ChapterEntity', () {
      test('should create ChapterEntity with required fields', () {
        final chapter = ChapterEntity(
          id: 'ch1',
          mediaId: 'media1',
          title: 'Chapter 1',
          number: 1.0,
        );

        expect(chapter.id, 'ch1');
        expect(chapter.mediaId, 'media1');
        expect(chapter.title, 'Chapter 1');
        expect(chapter.number, 1.0);
      });
    });

    group('ExtensionEntity', () {
      test('should create ExtensionEntity with required fields', () {
        final extension = ExtensionEntity(
          id: 'ext1',
          name: 'Test Extension',
          version: '1.0.0',
          type: ExtensionType.cloudstream,
          language: 'en',
          isInstalled: false,
          isNsfw: false,
        );

        expect(extension.id, 'ext1');
        expect(extension.name, 'Test Extension');
        expect(extension.version, '1.0.0');
        expect(extension.type, ExtensionType.cloudstream);
        expect(extension.isInstalled, false);
      });
    });

    group('LibraryItemEntity', () {
      test('should create LibraryItemEntity with required fields', () {
        final media = MediaEntity(
          id: '1',
          title: 'Test Anime',
          type: MediaType.anime,
          genres: ['Action'],
          status: MediaStatus.ongoing,
          sourceId: 'source1',
          sourceName: 'Test Source',
        );

        final libraryItem = LibraryItemEntity(
          id: 'lib1',
          mediaId: '1',
          userService: ts.TrackingService.anilist,
          media: media,
          status: LibraryStatus.watching,
          progress: const WatchProgress(currentEpisode: 5, currentChapter: 0),
          addedAt: DateTime(2024, 1, 1),
        );

        expect(libraryItem.id, 'lib1');
        expect(libraryItem.media, media);
        expect(libraryItem.status, LibraryStatus.watching);
        expect(libraryItem.currentEpisode, 5);
      });
    });

    group('UserEntity', () {
      test('should create UserEntity with required fields', () {
        final user = UserEntity(
          id: 'user1',
          username: 'testuser',
          service: TrackingService.anilist,
        );

        expect(user.id, 'user1');
        expect(user.username, 'testuser');
        expect(user.service, TrackingService.anilist);
      });
    });

    group('VideoSource', () {
      test('should create VideoSource with required fields', () {
        final source = VideoSource(
          id: 'src1',
          name: 'Test Source',
          url: 'https://example.com/video.mp4',
          quality: '1080p',
          server: 'Server 1',
        );

        expect(source.id, 'src1');
        expect(source.name, 'Test Source');
        expect(source.url, 'https://example.com/video.mp4');
        expect(source.quality, '1080p');
        expect(source.server, 'Server 1');
      });
    });
  });
}
