import 'package:flutter/foundation.dart';
import '../../../../core/domain/entities/library_item_entity.dart';
import '../../../../core/domain/usecases/get_library_items_usecase.dart';
import '../../../../core/domain/usecases/update_library_item_usecase.dart';
import '../../../../core/domain/usecases/remove_from_library_usecase.dart';
import '../../../../core/utils/error_message_mapper.dart';
import '../../../../core/utils/logger.dart';

class LibraryViewModel extends ChangeNotifier {
  final GetLibraryItemsUseCase getLibraryItems;
  final UpdateLibraryItemUseCase updateLibraryItem;
  final RemoveFromLibraryUseCase removeFromLibrary;

  LibraryViewModel({
    required this.getLibraryItems,
    required this.updateLibraryItem,
    required this.removeFromLibrary,
  });

  List<LibraryItemEntity> _libraryItems = [];
  LibraryStatus? _filterStatus;
  bool _isLoading = false;
  String? _error;

  List<LibraryItemEntity> get libraryItems => _libraryItems;
  LibraryStatus? get filterStatus => _filterStatus;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadLibrary() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await getLibraryItems(
        GetLibraryItemsParams(status: _filterStatus),
      );

      result.fold((failure) {
        _error = ErrorMessageMapper.mapFailureToMessage(failure);
        Logger.error(
          'Failed to load library',
          tag: 'LibraryViewModel',
          error: failure,
        );
      }, (items) => _libraryItems = items);
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

  Future<void> filterByStatus(LibraryStatus? status) async {
    _filterStatus = status;
    await loadLibrary();
  }

  Future<void> updateStatus(String itemId, LibraryStatus status) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Find the item to update
      final itemIndex = _libraryItems.indexWhere((item) => item.id == itemId);
      if (itemIndex == -1) {
        _error = 'Library item not found';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final item = _libraryItems[itemIndex];
      final updatedItem = LibraryItemEntity(
        id: item.id,
        mediaId: item.mediaId,
        userService: item.userService,
        media: item.media,
        status: status,
        progress: item.progress,
        score: item.score,
        notes: item.notes,
        addedAt: item.addedAt,
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
          // Remove item from local list
          _libraryItems.removeWhere((item) => item.id == itemId);
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
}
