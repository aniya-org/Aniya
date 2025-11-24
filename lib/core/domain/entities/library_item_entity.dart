import 'package:equatable/equatable.dart';
import 'media_entity.dart';

enum LibraryStatus { watching, completed, onHold, dropped, planToWatch }

class LibraryItemEntity extends Equatable {
  final String id;
  final MediaEntity media;
  final LibraryStatus status;
  final int currentEpisode;
  final int currentChapter;
  final DateTime addedAt;
  final DateTime? lastUpdated;

  const LibraryItemEntity({
    required this.id,
    required this.media,
    required this.status,
    required this.currentEpisode,
    required this.currentChapter,
    required this.addedAt,
    this.lastUpdated,
  });

  @override
  List<Object?> get props => [
    id,
    media,
    status,
    currentEpisode,
    currentChapter,
    addedAt,
    lastUpdated,
  ];
}
