import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'lib/features/video_player/presentation/screens/video_player_screen.dart';
import 'lib/features/manga_reader/presentation/screens/manga_reader_screen.dart';
import 'lib/features/novel_reader/presentation/screens/novel_reader_screen.dart';
import 'lib/core/di/injection_container.dart' as di;
import 'lib/core/domain/entities/media_entity.dart';
import 'lib/core/domain/entities/chapter_entity.dart';
import 'lib/core/domain/entities/source_entity.dart';
import 'lib/core/services/watch_history_controller.dart';

/// Test widget to verify resume dialog functionality
class ResumeDialogTestApp extends StatelessWidget {
  const ResumeDialogTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Resume Dialog Test',
      home: Scaffold(
        appBar: AppBar(title: const Text('Resume Dialog Test')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
                        ),
                        source: const SourceEntity(
                          id: 'test-source',
                          name: 'Test Source',
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
                          number: 1.0,
                          title: 'Test Chapter',
                        ),
                        media: const MediaEntity(
                          id: 'test-novel',
                          title: 'Test Novel',
                          type: MediaType.novel,
                          coverImage: 'https://example.com/cover.jpg',
                        ),
                        source: const SourceEntity(
                          id: 'test-source',
                          name: 'Test Source',
                        ),
                        resumeFromSavedPosition: true,
                      ),
                    ),
                  );
                },
                child: const Text('Test Novel Reader Resume Dialog'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  // Initialize the dependency container
  di.init();
  runApp(const ResumeDialogTestApp());
}
