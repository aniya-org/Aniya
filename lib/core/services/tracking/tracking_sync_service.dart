import '../../domain/entities/watch_history_entry.dart';
import '../../domain/entities/media_entity.dart';
import '../../domain/repositories/watch_history_repository.dart';
import '../../enums/tracking_service.dart';
import '../../utils/logger.dart';
import 'service_id_mapper.dart';
import 'tracking_service_interface.dart';

/// Result of a sync operation
class SyncResult {
  int totalProcessed;
  int updated;
  int skipped;
  List<String> errors;

  SyncResult({
    required this.totalProcessed,
    required this.updated,
    required this.skipped,
    this.errors = const [],
  });

  @override
  String toString() =>
      'SyncResult(processed: $totalProcessed, updated: $updated, skipped: $skipped, errors: ${errors.length})';
}

/// Service for syncing watch history with remote tracking services
/// Handles batch pull-sync with max progress merging
class TrackingSyncService {
  final WatchHistoryRepository repository;
  final List<TrackingServiceInterface> availableServices;

  TrackingSyncService({
    required this.repository,
    required this.availableServices,
  });

  /// Perform a full batch sync of all tracked items
  /// Fetches remote progress for each service and merges into local watch history
  /// Returns sync result with counts and any errors
  Future<SyncResult> syncAllTrackedItems() async {
    Logger.info(
      'TrackingSyncService: Starting batch sync',
      tag: 'TrackingSyncService',
    );

    final result = SyncResult(
      totalProcessed: 0,
      updated: 0,
      skipped: 0,
      errors: [],
    );

    try {
      // Get all local watch history entries
      final allEntriesResult = await repository.getAllEntries();

      allEntriesResult.fold(
        (failure) {
          Logger.error(
            'TrackingSyncService: Failed to load watch history: ${failure.message}',
            tag: 'TrackingSyncService',
          );
          result.errors.add('Failed to load watch history: ${failure.message}');
        },
        (entries) async {
          result.totalProcessed = entries.length;

          // Filter to entries that have service IDs resolved (tracked items)
          final trackedEntries = entries.where((e) {
            // An entry is considered tracked if it has a normalized ID
            // (which indicates it's been matched to tracking services)
            return e.normalizedId != null;
          }).toList();

          Logger.info(
            'TrackingSyncService: Found ${trackedEntries.length} tracked items out of ${entries.length} total',
            tag: 'TrackingSyncService',
          );

          // Sync each tracked item with all authenticated services
          for (final entry in trackedEntries) {
            try {
              final synced = await _syncEntryWithServices(entry);
              if (synced) {
                result.updated++;
              } else {
                result.skipped++;
              }
            } catch (e) {
              Logger.error(
                'TrackingSyncService: Error syncing "${entry.title}": $e',
                tag: 'TrackingSyncService',
                error: e,
              );
              result.errors.add('Error syncing "${entry.title}": $e');
              result.skipped++;
            }
          }
        },
      );
    } catch (e, stackTrace) {
      Logger.error(
        'TrackingSyncService: Unexpected error during sync',
        tag: 'TrackingSyncService',
        error: e,
        stackTrace: stackTrace,
      );
      result.errors.add('Unexpected error: $e');
    }

    Logger.info(
      'TrackingSyncService: Sync complete - $result',
      tag: 'TrackingSyncService',
    );

    return result;
  }

  /// Sync a single entry with all authenticated tracking services
  /// Returns true if entry was updated
  Future<bool> _syncEntryWithServices(WatchHistoryEntry entry) async {
    bool updated = false;

    // Get authenticated services
    final authenticatedServices = availableServices
        .where(
          (s) => s.isAuthenticated && s.serviceType != TrackingService.local,
        )
        .toList();

    if (authenticatedServices.isEmpty) {
      Logger.debug(
        'TrackingSyncService: No authenticated services for "${entry.title}"',
        tag: 'TrackingSyncService',
      );
      return false;
    }

    // Try to sync with each authenticated service
    for (final service in authenticatedServices) {
      try {
        final synced = await _syncEntryWithService(entry, service);
        if (synced) {
          updated = true;
        }
      } catch (e) {
        Logger.warning(
          'TrackingSyncService: Failed to sync "${entry.title}" with ${service.serviceType}: $e',
          tag: 'TrackingSyncService',
        );
      }
    }

    return updated;
  }

  /// Sync a single entry with a specific service
  /// Returns true if entry was updated
  Future<bool> _syncEntryWithService(
    WatchHistoryEntry entry,
    TrackingServiceInterface service,
  ) async {
    Logger.debug(
      'TrackingSyncService: Syncing "${entry.title}" with ${service.serviceType}',
      tag: 'TrackingSyncService',
    );

    try {
      // Get service ID for this entry
      final serviceId = await ServiceIdMapper.getServiceId(
        _entryToMediaEntity(entry),
        service.serviceType,
        availableServices: availableServices,
        releaseYear: entry.releaseYear,
      );

      if (serviceId == null) {
        Logger.debug(
          'TrackingSyncService: Could not resolve ${service.serviceType} ID for "${entry.title}"',
          tag: 'TrackingSyncService',
        );
        return false;
      }

      Logger.info(
        'TrackingSyncService: Resolved ${service.serviceType} ID for "${entry.title}": $serviceId',
        tag: 'TrackingSyncService',
      );

      // Get remote progress from service
      final remoteProgress = await service.getProgress(serviceId);

      if (remoteProgress == null) {
        Logger.debug(
          'TrackingSyncService: No progress found on ${service.serviceType} for "${entry.title}"',
          tag: 'TrackingSyncService',
        );
        return false;
      }

      Logger.info(
        'TrackingSyncService: Got remote progress from ${service.serviceType} for "${entry.title}": episode=${remoteProgress.currentEpisode}, chapter=${remoteProgress.currentChapter}, completed=${remoteProgress.completed}',
        tag: 'TrackingSyncService',
      );

      // Merge progress: use max progress and preserve completion
      return await _mergeProgress(entry, remoteProgress, service.serviceType);
    } catch (e) {
      Logger.error(
        'TrackingSyncService: Error syncing with ${service.serviceType}',
        tag: 'TrackingSyncService',
        error: e,
      );
      rethrow;
    }
  }

  /// Merge remote progress into local entry
  /// Uses max progress rule and preserves completion status
  /// Returns true if entry was updated
  Future<bool> _mergeProgress(
    WatchHistoryEntry entry,
    TrackingProgress remoteProgress,
    TrackingService service,
  ) async {
    bool needsUpdate = false;
    WatchHistoryEntry updatedEntry = entry;

    if (entry.isVideoEntry) {
      // For video entries: use max episode number
      final localEpisode = entry.episodeNumber ?? 0;
      final remoteEpisode = remoteProgress.currentEpisode ?? 0;

      if (remoteEpisode > localEpisode) {
        Logger.info(
          'TrackingSyncService: Updating episode for "${entry.title}": $localEpisode -> $remoteEpisode (from ${service.name})',
          tag: 'TrackingSyncService',
        );
        updatedEntry = updatedEntry.copyWith(episodeNumber: remoteEpisode);
        needsUpdate = true;
      }

      // Preserve completion if either side is completed
      if (remoteProgress.completed == true && entry.completedAt == null) {
        Logger.info(
          'TrackingSyncService: Marking "${entry.title}" as completed (from ${service.name})',
          tag: 'TrackingSyncService',
        );
        updatedEntry = updatedEntry.copyWith(completedAt: DateTime.now());
        needsUpdate = true;
      }
    } else if (entry.isReadingEntry) {
      // For reading entries: use max chapter number
      final localChapter = entry.chapterNumber ?? 0;
      final remoteChapter = remoteProgress.currentChapter ?? 0;

      if (remoteChapter > localChapter) {
        Logger.info(
          'TrackingSyncService: Updating chapter for "${entry.title}": $localChapter -> $remoteChapter (from ${service.name})',
          tag: 'TrackingSyncService',
        );
        updatedEntry = updatedEntry.copyWith(chapterNumber: remoteChapter);
        needsUpdate = true;
      }

      // Preserve completion if either side is completed
      if (remoteProgress.completed == true && entry.completedAt == null) {
        Logger.info(
          'TrackingSyncService: Marking "${entry.title}" as completed (from ${service.name})',
          tag: 'TrackingSyncService',
        );
        updatedEntry = updatedEntry.copyWith(completedAt: DateTime.now());
        needsUpdate = true;
      }
    }

    // Update local entry if needed
    if (needsUpdate) {
      final updateResult = await repository.upsertEntry(updatedEntry);
      updateResult.fold(
        (failure) {
          Logger.error(
            'TrackingSyncService: Failed to update entry: ${failure.message}',
            tag: 'TrackingSyncService',
          );
        },
        (_) {
          Logger.info(
            'TrackingSyncService: Updated "${entry.title}" in local history',
            tag: 'TrackingSyncService',
          );
        },
      );
      return true;
    }

    return false;
  }

  /// Convert WatchHistoryEntry to MediaEntity for ID resolution
  MediaEntity _entryToMediaEntity(WatchHistoryEntry entry) {
    return MediaEntity(
      id: entry.mediaId,
      title: entry.title,
      type: entry.mediaType,
      description: null,
      coverImage: entry.coverImage,
      bannerImage: null,
      rating: null,
      genres: [],
      status: MediaStatus.ongoing,
      totalEpisodes: null,
      totalChapters: null,
      startDate: null,
      sourceId: entry.sourceId,
      sourceName: entry.sourceName,
    );
  }
}

/// Extension on TrackingService for display names
extension TrackingServiceDisplay on TrackingService {
  String get name {
    switch (this) {
      case TrackingService.anilist:
        return 'AniList';
      case TrackingService.mal:
        return 'MyAnimeList';
      case TrackingService.simkl:
        return 'Simkl';
      default:
        return toString();
    }
  }
}
