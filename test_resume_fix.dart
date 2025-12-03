import 'package:flutter/material.dart';
import 'lib/features/video_player/presentation/screens/video_player_screen.dart';
import 'lib/features/manga_reader/presentation/screens/manga_reader_screen.dart';
import 'lib/features/novel_reader/presentation/screens/novel_reader_screen.dart';
import 'lib/core/di/injection_container.dart' as di;
import 'lib/core/domain/entities/media_entity.dart';
import 'lib/core/domain/entities/chapter_entity.dart';
import 'lib/core/domain/entities/source_entity.dart';

/// Test widget to verify resume dialog functionality after fixes
class ResumeFixTestApp extends StatelessWidget {
  const ResumeFixTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Resume Fix Test',
      home: Scaffold(
        appBar: AppBar(title: const Text('Resume Fix Test')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Testing Resume Dialog Fixes',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const VideoPlayerScreen(
                        episodeId: 'test-episode',
                        sourceId: 'test-source',
                        itemId: 'test-anime',
                        episodeNumber: 1,
                        episodeTitle: 'Test Episode',
                        resumeFromSavedPosition: true,
                      ),
                    ),
                  );
                },
                child: const Text('Test Video Player Resume Dialog'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => MangaReaderScreen(
                        chapter: const ChapterEntity(
                          id: 'test-chapter',
                          mediaId: 'test-manga',
                          number: 1.0,
                          title: 'Test Chapter',
                        ),
                        sourceId: 'test-source',
                        itemId: 'test-manga',
                        resumeFromSavedPage: true,
                        media: const MediaEntity(
                          id: 'test-manga',
                          title: 'Test Manga',
                          type: MediaType.manga,
                          coverImage: 'https://example.com/cover.jpg',
                          genres: const [],
                          status: MediaStatus.ongoing,
                          sourceId: 'test-source',
                          sourceName: 'Test Source',
                        ),
                        source: const SourceEntity(
                          id: 'test-source',
                          name: 'Test Source',
                          providerId: 'test-source',
                          sourceLink: 'https://example.com',
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Test Manga Reader Resume Dialog'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => NovelReaderScreen(
                        chapter: const ChapterEntity(
                          id: 'test-chapter',
                          mediaId: 'test-novel',
                          number: 1.0,
                          title: 'Test Chapter',
                        ),
                        media: const MediaEntity(
                          id: 'test-novel',
                          title: 'Test Novel',
                          type: MediaType.novel,
                          coverImage: 'https://example.com/cover.jpg',
                          genres: const [],
                          status: MediaStatus.ongoing,
                          sourceId: 'test-source',
                          sourceName: 'Test Source',
                        ),
                        source: const SourceEntity(
                          id: 'test-source',
                          name: 'Test Source',
                          providerId: 'test-source',
                          sourceLink: 'https://example.com',
                        ),
                        resumeFromSavedPosition: true,
                      ),
                    ),
                  );
                },
                child: const Text('Test Novel Reader Resume Dialog'),
              ),
              const SizedBox(height: 40),
              const Text(
                'Expected behavior after fixes:\n'
                '1. Resume dialogs should appear even when media is not in library\n'
                '2. Positions should be loaded from watch history first\n'
                '3. Library repository should be used as fallback',
                style: TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> main() async {
  // Initialize dependency container
  await di.initializeDependencies();
  runApp(const ResumeFixTestApp());
}
