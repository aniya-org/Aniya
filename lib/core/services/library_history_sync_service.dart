import 'package:flutter/foundation.dart';
import '../domain/entities/library_item_entity.dart';
import '../domain/entities/media_entity.dart';
import '../domain/entities/watch_history_entry.dart';
import '../domain/repositories/library_repository.dart';
import '../domain/repositories/watch_history_repository.dart';
import '../enums/tracking_service.dart';
import '../utils/logger.dart';

/// Service to synchronize library status with watch history completion
/// Automatically updates library items when history entries are marked as completed
class LibraryHistorySyncService extends ChangeNotifier {
  final LibraryRepository libraryRepository;
  final WatchHistoryRepository watchHistoryRepository;

  LibraryHistorySyncService({
    required this.libraryRepository,
    required this.watchHistoryRepository,
  });

  /// Sync library status when a history entry is completed
  Future<void> syncOnHistoryCompletion(WatchHistoryEntry historyEntry) async {
    if (historyEntry.completedAt == null) return;

    try {
      // Check if media exists in library
      final libraryResult = await libraryRepository.getLibraryItem(historyEntry.mediaId);
      libraryResult.fold(
        (failure) {
          // Item not in library, nothing to sync
          Logger.debug(
            'Media ${historyEntry.mediaId} not in library, skipping sync',
            tag: 'LibraryHistorySyncService',
          );
        },
        (libraryItem) async {
          // Determine new status based on media type and completion
          LibraryStatus newStatus = _determineCompletedStatus(historyEntry, libraryItem);

          // Only update if status is changing
          if (libraryItem.status != newStatus) {
            Logger.info(
              'Updating library status for ${historyEntry.title} from ${libraryItem.status} to $newStatus',
              tag: 'LibraryHistorySyncService',
            );

            // Create updated progress
            final updatedProgress = WatchProgress(
              currentEpisode: historyEntry.isVideoEntry
                  ? historyEntry.episodeNumber
                  : libraryItem.progress?.currentEpisode,
              currentChapter: historyEntry.isReadingEntry
                  ? historyEntry.chapterNumber
                  : libraryItem.progress?.currentChapter,
              updatedAt: DateTime.now(),
            );

            // Create updated library item
            final updatedItem = libraryItem.copyWith(
              status: newStatus,
              progress: updatedProgress,
            );

            final updateResult = await libraryRepository.updateLibraryItem(updatedItem);

            updateResult.fold(
              (failure) => Logger.error(
                'Failed to update library status',
                tag: 'LibraryHistorySyncService',
                error: failure,
              ),
              (success) {
                Logger.info(
                  'Successfully updated library status for ${historyEntry.title}',
                  tag: 'LibraryHistorySyncService',
                );
                notifyListeners();
              },
            );
          }
        },
      );
    } catch (e, stackTrace) {
      Logger.error(
        'Error syncing history completion to library',
        tag: 'LibraryHistorySyncService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Determine the appropriate completed status based on media type
  LibraryStatus _determineCompletedStatus(
    WatchHistoryEntry historyEntry,
    LibraryItemEntity libraryItem,
  ) {
    // Check current status to maintain similar category
    switch (libraryItem.status) {
      case LibraryStatus.currentlyWatching:
      case LibraryStatus.watching:
      case LibraryStatus.planToWatch:
      case LibraryStatus.wantToWatch:
        return historyEntry.isReadingEntry
            ? (historyEntry.mediaType == MediaType.novel
                ? LibraryStatus.finished
                : LibraryStatus.finished)
            : LibraryStatus.completed;

      case LibraryStatus.onHold:
      case LibraryStatus.dropped:
        // Keep these statuses even if completed, user might have set them intentionally
        return libraryItem.status;

      case LibraryStatus.completed:
      case LibraryStatus.finished:
      case LibraryStatus.watched:
        // Already in a completed state
        return libraryItem.status;

      // No default needed as all cases are covered
    }
  }

  /// Add media to library when history entry is created and media is not in library
  Future<void> addMediaToLibraryFromHistory(WatchHistoryEntry historyEntry) async {
    try {
      // Check if already in library
      final existsResult = await libraryRepository.getLibraryItem(historyEntry.mediaId);
      final exists = existsResult.fold((failure) => false, (item) => true);

      if (exists) return;

      // Add to library with appropriate status
      final status = _determineInitialStatus(historyEntry);

      Logger.info(
        'Adding ${historyEntry.title} to library with status $status',
        tag: 'LibraryHistorySyncService',
      );

      // Create progress object
      final progress = WatchProgress(
        currentEpisode: historyEntry.isVideoEntry
            ? historyEntry.episodeNumber
            : null,
        currentChapter: historyEntry.isReadingEntry
            ? historyEntry.chapterNumber
            : null,
        startedAt: DateTime.now(),
      );

      // Create library item entity
      final libraryItem = LibraryItemEntity(
        id: '${historyEntry.mediaId}_local', // Use media ID + service as library item ID
        mediaId: historyEntry.mediaId,
        userService: TrackingService.local,
        mediaType: historyEntry.mediaType,
        status: status,
        sourceId: historyEntry.sourceId,
        sourceName: historyEntry.sourceName,
        addedAt: DateTime.now(),
        progress: progress,
      );

      final addResult = await libraryRepository.addToLibrary(libraryItem);

      addResult.fold(
        (failure) => Logger.error(
          'Failed to add media to library',
          tag: 'LibraryHistorySyncService',
          error: failure,
        ),
        (success) {
          Logger.info(
            'Successfully added ${historyEntry.title} to library',
            tag: 'LibraryHistorySyncService',
          );
          notifyListeners();
        },
      );
    } catch (e, stackTrace) {
      Logger.error(
        'Error adding media to library from history',
        tag: 'LibraryHistorySyncService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Determine initial status when adding from history
  LibraryStatus _determineInitialStatus(WatchHistoryEntry historyEntry) {
    if (historyEntry.completedAt != null) {
      return historyEntry.isReadingEntry
          ? LibraryStatus.finished
          : LibraryStatus.completed;
    }

    // Check progress to determine status
    if (historyEntry.isVideoEntry) {
      if (historyEntry.episodeNumber != null && historyEntry.episodeNumber! > 1) {
        return LibraryStatus.watching;
      }
      return LibraryStatus.watching;
    } else {
      if (historyEntry.chapterNumber != null && historyEntry.chapterNumber! > 1) {
        return historyEntry.mediaType == MediaType.novel
            ? LibraryStatus.watching // Using watching as reading equivalent
            : LibraryStatus.watching;
      }
      return LibraryStatus.watching;
    }
  }

  /// Batch sync recently completed items
  Future<void> syncRecentlyCompleted() async {
    try {
      // Get all entries and filter for completed ones
      final result = await watchHistoryRepository.getAllEntries();

      result.fold(
        (failure) => Logger.error(
          'Failed to get all entries',
          tag: 'LibraryHistorySyncService',
          error: failure,
        ),
        (entries) async {
          // Filter for entries completed in the last 7 days
          final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
          final recentlyCompleted = entries.where((entry) {
            return entry.completedAt != null &&
                   entry.completedAt!.isAfter(sevenDaysAgo);
          }).toList();

          Logger.info(
            'Syncing ${recentlyCompleted.length} recently completed items',
            tag: 'LibraryHistorySyncService',
          );

          for (final entry in recentlyCompleted) {
            await syncOnHistoryCompletion(entry);
          }
        },
      );
    } catch (e, stackTrace) {
      Logger.error(
        'Error in batch sync',
        tag: 'LibraryHistorySyncService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}