import 'package:flutter/foundation.dart';
import '../../../../core/domain/entities/library_item_entity.dart';
import '../../../../core/domain/entities/media_entity.dart';
import '../../../../core/domain/usecases/get_library_items_usecase.dart';
import '../../../../core/domain/usecases/update_library_item_usecase.dart';
import '../../../../core/domain/usecases/remove_from_library_usecase.dart';
import '../../../../core/utils/error_message_mapper.dart';
import '../../../../core/utils/logger.dart';

/// Sorting options for library items
enum LibrarySortOption {
  titleAsc('Title (A-Z)'),
  titleDesc('Title (Z-A)'),
  dateAddedNewest('Recently Added'),
  dateAddedOldest('Oldest Added'),
  lastUpdatedNewest('Recently Updated'),
  lastUpdatedOldest('Oldest Updated'),
  status('By Status');

  const LibrarySortOption(this.displayName);
  final String displayName;
}

class LibraryViewModel extends ChangeNotifier {
  final GetLibraryItemsUseCase getLibraryItems;
  final UpdateLibraryItemUseCase updateLibraryItem;
  final RemoveFromLibraryUseCase removeFromLibrary;

  LibraryViewModel({
    required this.getLibraryItems,
    required this.updateLibraryItem,
    required this.removeFromLibrary,
  });

  List<LibraryItemEntity> _allLibraryItems = [];
  List<LibraryItemEntity> _filteredItems = [];
  LibraryStatus? _filterStatus;
  MediaType? _filterMediaType;
  LibrarySortOption _sortOption = LibrarySortOption.dateAddedNewest;
  bool _isLoading = false;
  String? _error;
  Map<MediaType, int> _countsByType = {};

  /// All library items (unfiltered)
  List<LibraryItemEntity> get allLibraryItems => _allLibraryItems;

  /// Filtered library items based on current filters
  List<LibraryItemEntity> get libraryItems => _filteredItems;

  LibraryStatus? get filterStatus => _filterStatus;
  MediaType? get filterMediaType => _filterMediaType;
  LibrarySortOption get sortOption => _sortOption;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<MediaType, int> get countsByType => _countsByType;

  /// Get items count for a specific media type
  int getCountForType(MediaType type) => _countsByType[type] ?? 0;

  /// Get total items count
  int get totalCount => _allLibraryItems.length;

  Future<void> loadLibrary() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await getLibraryItems(
        GetLibraryItemsParams(status: _filterStatus),
      );

      result.fold(
        (failure) {
          _error = ErrorMessageMapper.mapFailureToMessage(failure);
          Logger.error(
            'Failed to load library',
            tag: 'LibraryViewModel',
            error: failure,
          );
        },
        (items) {
          _allLibraryItems = items;
          _updateCountsByType();
          _applyFilters();
        },
      );
    } catch (e, stackTrace) {
      _error = 'An unexpected error occurred. Please try again.';
      Logger.error(
        'Unexpected error in loadLibrary',
        tag: 'LibraryViewModel',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Filter by library status (Watching, Completed, etc.)
  Future<void> filterByStatus(LibraryStatus? status) async {
    _filterStatus = status;
    _applyFilters();
    notifyListeners();
  }

  /// Filter by media type (Anime, Manga, Movie, etc.)
  void filterByMediaType(MediaType? type) {
    _filterMediaType = type;
    _applyFilters();
    notifyListeners();
  }

  /// Sort library items by the specified option
  void sortBy(LibrarySortOption option) {
    _sortOption = option;
    _applyFilters();
    notifyListeners();
  }

  /// Clear all filters
  void clearFilters() {
    _filterStatus = null;
    _filterMediaType = null;
    _applyFilters();
    notifyListeners();
  }

  /// Apply current filters to the library items
  void _applyFilters() {
    var items = List<LibraryItemEntity>.from(_allLibraryItems);

    // Apply status filter
    if (_filterStatus != null) {
      items = items.where((item) => item.status == _filterStatus).toList();
    }

    // Apply media type filter
    if (_filterMediaType != null) {
      items = items
          .where((item) => item.effectiveMediaType == _filterMediaType)
          .toList();
    }

    // Apply sorting
    items = _sortItems(items);

    _filteredItems = items;
  }

  /// Update counts by media type
  void _updateCountsByType() {
    _countsByType = {};
    for (final item in _allLibraryItems) {
      final type = item.effectiveMediaType;
      _countsByType[type] = (_countsByType[type] ?? 0) + 1;
    }
  }

  /// Sort items based on current sort option
  List<LibraryItemEntity> _sortItems(List<LibraryItemEntity> items) {
    switch (_sortOption) {
      case LibrarySortOption.titleAsc:
        return items..sort((a, b) {
          final titleA = a.media?.title ?? '';
          final titleB = b.media?.title ?? '';
          return titleA.compareTo(titleB);
        });
      case LibrarySortOption.titleDesc:
        return items..sort((a, b) {
          final titleA = a.media?.title ?? '';
          final titleB = b.media?.title ?? '';
          return titleB.compareTo(titleA);
        });
      case LibrarySortOption.dateAddedNewest:
        return items..sort((a, b) {
          // Handle null dates by putting them at the end
          if (a.addedAt == null && b.addedAt == null) return 0;
          if (a.addedAt == null) return 1;
          if (b.addedAt == null) return -1;
          return b.addedAt!.compareTo(a.addedAt!);
        });
      case LibrarySortOption.dateAddedOldest:
        return items..sort((a, b) {
          if (a.addedAt == null && b.addedAt == null) return 0;
          if (a.addedAt == null) return 1;
          if (b.addedAt == null) return -1;
          return a.addedAt!.compareTo(b.addedAt!);
        });
      case LibrarySortOption.lastUpdatedNewest:
        return items..sort((a, b) {
          if (a.lastUpdated == null && b.lastUpdated == null) return 0;
          if (a.lastUpdated == null) return 1;
          if (b.lastUpdated == null) return -1;
          return b.lastUpdated!.compareTo(a.lastUpdated!);
        });
      case LibrarySortOption.lastUpdatedOldest:
        return items..sort((a, b) {
          if (a.lastUpdated == null && b.lastUpdated == null) return 0;
          if (a.lastUpdated == null) return 1;
          if (b.lastUpdated == null) return -1;
          return a.lastUpdated!.compareTo(b.lastUpdated!);
        });
      case LibrarySortOption.status:
        return items..sort((a, b) {
          final statusComparison = a.status.index.compareTo(b.status.index);
          if (statusComparison != 0) return statusComparison;
          final titleA = a.media?.title ?? '';
          final titleB = b.media?.title ?? '';
          return titleA.compareTo(titleB);
        });
    }
  }

  /// Get items grouped by status
  Map<LibraryStatus, List<LibraryItemEntity>> get itemsByStatus {
    final grouped = <LibraryStatus, List<LibraryItemEntity>>{};
    for (final item in _filteredItems) {
      grouped.putIfAbsent(item.status, () => []).add(item);
    }
    return grouped;
  }

  /// Get items grouped by media type
  Map<MediaType, List<LibraryItemEntity>> get itemsByMediaType {
    final grouped = <MediaType, List<LibraryItemEntity>>{};
    for (final item in _filteredItems) {
      grouped.putIfAbsent(item.effectiveMediaType, () => []).add(item);
    }
    return grouped;
  }

  /// Get video-type items (Continue Watching candidates)
  List<LibraryItemEntity> get videoItems =>
      _filteredItems.where((item) => item.isVideoType).toList();

  /// Get reading-type items (Continue Reading candidates)
  List<LibraryItemEntity> get readingItems =>
      _filteredItems.where((item) => item.isReadingType).toList();

  Future<void> updateStatus(String itemId, LibraryStatus status) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Find the item to update
      final itemIndex = _allLibraryItems.indexWhere(
        (item) => item.id == itemId,
      );
      if (itemIndex == -1) {
        _error = 'Library item not found';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final item = _allLibraryItems[itemIndex];
      final updatedItem = item.copyWith(
        status: status,
        lastUpdated: DateTime.now(),
      );

      final result = await updateLibraryItem(
        UpdateLibraryItemParams(item: updatedItem),
      );

      result.fold(
        (failure) {
          _error = ErrorMessageMapper.mapFailureToMessage(failure);
          Logger.error(
            'Failed to update library item status',
            tag: 'LibraryViewModel',
            error: failure,
          );
        },
        (_) {
          // Reload library to get updated data
          loadLibrary();
        },
      );
    } catch (e, stackTrace) {
      _error = 'An unexpected error occurred. Please try again.';
      Logger.error(
        'Unexpected error updating library item status',
        tag: 'LibraryViewModel',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> removeItem(String itemId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await removeFromLibrary(
        RemoveFromLibraryParams(itemId: itemId),
      );

      result.fold(
        (failure) {
          _error = ErrorMessageMapper.mapFailureToMessage(failure);
          Logger.error(
            'Failed to remove library item',
            tag: 'LibraryViewModel',
            error: failure,
          );
        },
        (_) {
          // Remove item from local lists
          _allLibraryItems.removeWhere((item) => item.id == itemId);
          _updateCountsByType();
          _applyFilters();
        },
      );
    } catch (e, stackTrace) {
      _error = 'An unexpected error occurred. Please try again.';
      Logger.error(
        'Unexpected error removing library item',
        tag: 'LibraryViewModel',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Toggle an item in the library (add if not present, update if present)
  Future<void> toggleEntry(LibraryItemEntity item) async {
    final existingIndex = _allLibraryItems.indexWhere((i) => i.id == item.id);
    if (existingIndex >= 0) {
      // Item exists, update it
      await updateStatus(item.id, item.status);
    } else {
      // Item doesn't exist, would need addToLibrary use case
      // For now, just reload
      await loadLibrary();
    }
  }
}
