import 'dart:async';
import '../../utils/logger.dart';
import 'tracking_sync_service.dart';

/// Debouncer for tracking sync operations
/// Prevents excessive sync requests and batches them together
class TrackingSyncDebouncer {
  final TrackingSyncService syncService;
  final Duration debounceDelay;

  Timer? _debounceTimer;
  bool _isSyncing = false;

  TrackingSyncDebouncer({
    required this.syncService,
    this.debounceDelay = const Duration(seconds: 5),
  });

  /// Request a sync operation with debouncing
  /// Multiple requests within the debounce window are batched into one
  Future<SyncResult?> requestSync() async {
    // Cancel previous timer if it exists
    _debounceTimer?.cancel();

    // If already syncing, queue another sync after completion
    if (_isSyncing) {
      Logger.debug(
        'TrackingSyncDebouncer: Sync already in progress, will retry after completion',
        tag: 'TrackingSyncDebouncer',
      );
      return null;
    }

    // Create new timer for debounced sync
    final completer = Completer<SyncResult?>();

    _debounceTimer = Timer(debounceDelay, () async {
      try {
        _isSyncing = true;
        Logger.info(
          'TrackingSyncDebouncer: Starting debounced sync',
          tag: 'TrackingSyncDebouncer',
        );

        final result = await syncService.syncAllTrackedItems();

        Logger.info(
          'TrackingSyncDebouncer: Sync complete - $result',
          tag: 'TrackingSyncDebouncer',
        );

        completer.complete(result);
      } catch (e) {
        Logger.error(
          'TrackingSyncDebouncer: Sync failed',
          tag: 'TrackingSyncDebouncer',
          error: e,
        );
        completer.completeError(e);
      } finally {
        _isSyncing = false;
      }
    });

    return completer.future;
  }

  /// Cancel any pending sync operation
  void cancel() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    Logger.debug(
      'TrackingSyncDebouncer: Cancelled pending sync',
      tag: 'TrackingSyncDebouncer',
    );
  }

  /// Dispose resources
  void dispose() {
    cancel();
  }
}
