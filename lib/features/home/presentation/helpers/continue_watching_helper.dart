import '../../../../core/domain/entities/library_item_entity.dart';
import '../../../../core/domain/entities/media_entity.dart';
import '../../../../core/domain/entities/watch_history_entry.dart';

/// Combined data structure for continue watching/reading items
/// Merges watch history data with library information
class ContinueWatchingItem {
  final WatchHistoryEntry historyEntry;
  final LibraryItemEntity? libraryItem;
  final MediaEntity media;

  ContinueWatchingItem({
    required this.historyEntry,
    this.libraryItem,
    required this.media,
  });

  /// Getters for easy access to commonly used properties
  String get title => historyEntry.title;
  String? get coverImage => historyEntry.coverImage;
  MediaType get mediaType => historyEntry.mediaType;
  String get sourceId => historyEntry.sourceId;
  String get sourceName => historyEntry.sourceName;

  /// Type checking
  bool get isVideo => historyEntry.isVideoEntry;
  bool get isReading => historyEntry.isReadingEntry;

  /// Library status if available
  LibraryStatus? get libraryStatus => libraryItem?.status;

  /// Progress information
  double? get progress => historyEntry.progressPercentage * 100;
  int? get episodeNumber => historyEntry.episodeNumber;
  int? get chapterNumber => historyEntry.chapterNumber;
  int? get pageNumber => historyEntry.pageNumber;
  DateTime get lastWatchedAt => historyEntry.lastPlayedAt;

  /// Completion status
  bool get isCompleted => historyEntry.completedAt != null;

  /// Check if this item should be shown in continue section
  bool get shouldShow => !isCompleted;

  /// Sorting key - more recent items first
  DateTime get sortKey => historyEntry.lastPlayedAt;
}

/// Helper class to combine watch history with library data
class ContinueWatchingHelper {
  /// Combine watch history entries with library items
  static List<ContinueWatchingItem> combineHistoryAndLibrary(
    List<WatchHistoryEntry> historyEntries,
    List<LibraryItemEntity> libraryItems,
  ) {
    // Create a map of library items by media ID for quick lookup
    final libraryMap = <String, LibraryItemEntity>{};
    for (final item in libraryItems) {
      libraryMap[item.mediaId] = item;
    }

    // Combine entries
    final combinedItems = <ContinueWatchingItem>[];
    final seenMediaIds = <String>{};

    for (final entry in historyEntries) {
      // Skip if we've already added this media (show only most recent entry)
      if (seenMediaIds.contains(entry.mediaId)) continue;

      // Skip completed items
      if (entry.completedAt != null) continue;

      final libraryItem = libraryMap[entry.mediaId];

      // Create media entity from history entry
      final media = _createMediaFromHistory(entry);

      combinedItems.add(ContinueWatchingItem(
        historyEntry: entry,
        libraryItem: libraryItem,
        media: media,
      ));

      seenMediaIds.add(entry.mediaId);
    }

    // Sort by last watched (most recent first)
    combinedItems.sort((a, b) => b.sortKey.compareTo(a.sortKey));

    return combinedItems;
  }

  /// Create a MediaEntity from a WatchHistoryEntry
  static MediaEntity _createMediaFromHistory(WatchHistoryEntry entry) {
    return MediaEntity(
      id: entry.mediaId,
      title: entry.title,
      coverImage: entry.coverImage,
      bannerImage: entry.coverImage,
      description: null,
      type: entry.mediaType,
      rating: null,
      genres: const [],
      status: MediaStatus.ongoing,
      totalEpisodes: entry.episodeNumber,
      totalChapters: entry.chapterNumber,
      startDate: null,
      sourceId: entry.sourceId,
      sourceName: entry.sourceName,
      sourceType: entry.mediaType,
    );
  }

  /// Get a label for the media type
  static String getMediaTypeLabel(MediaType type, bool isVideo, bool isReading) {
    if (isVideo) {
      switch (type) {
        case MediaType.anime:
          return 'Anime';
        case MediaType.movie:
          return 'Movie';
        case MediaType.tvShow:
          return 'TV Show';
        case MediaType.cartoon:
          return 'Cartoon';
        case MediaType.documentary:
          return 'Documentary';
        default:
          return 'Video';
      }
    } else if (isReading) {
      switch (type) {
        case MediaType.manga:
          return 'Manga';
        case MediaType.novel:
          return 'Novel';
        default:
          return 'Reading';
      }
    }
    return type.displayName;
  }

  /// Get progress text for display
  static String getProgressText(ContinueWatchingItem item) {
    if (item.isVideo) {
      if (item.episodeNumber != null) {
        return 'Episode ${item.episodeNumber}';
      }
      return 'Continue Watching';
    } else if (item.isReading) {
      if (item.chapterNumber != null) {
        return 'Chapter ${item.chapterNumber}';
      }
      return 'Continue Reading';
    }
    return 'Continue';
  }

  /// Get library status label
  static String? getLibraryStatusLabel(LibraryStatus? status) {
    if (status == null) return null;
    switch (status) {
      case LibraryStatus.currentlyWatching:
      case LibraryStatus.watching:
        return 'Watching';
      case LibraryStatus.completed:
      case LibraryStatus.finished:
        return 'Completed';
      case LibraryStatus.onHold:
        return 'On Hold';
      case LibraryStatus.dropped:
        return 'Dropped';
      case LibraryStatus.planToWatch:
      case LibraryStatus.wantToWatch:
        return 'Plan to Watch';
      case LibraryStatus.watched:
        return 'Watched';
    }
  }
}