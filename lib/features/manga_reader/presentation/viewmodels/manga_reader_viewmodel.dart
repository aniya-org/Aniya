import 'package:flutter/foundation.dart';
import '../../../../core/domain/usecases/get_chapter_pages_usecase.dart';
import '../../../../core/domain/usecases/save_reading_position_usecase.dart';
import '../../../../core/domain/usecases/get_reading_position_usecase.dart';
import '../../../../core/utils/error_message_mapper.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/domain/entities/media_entity.dart';
import '../../../../core/services/watch_history_controller.dart';

/// ViewModel for manga reader screen
///
/// Manages the state and business logic for reading manga chapters:
/// - Loading chapter pages
/// - Tracking current page
/// - Saving and restoring reading position
/// - Handling reading mode (vertical scroll vs horizontal paging)
class MangaReaderViewModel extends ChangeNotifier {
  final GetChapterPagesUseCase getChapterPages;
  final SaveReadingPositionUseCase saveReadingPosition;
  final GetReadingPositionUseCase getReadingPosition;

  MangaReaderViewModel({
    required this.getChapterPages,
    required this.saveReadingPosition,
    required this.getReadingPosition,
  });

  List<String> _pages = [];
  int _currentPage = 0;
  bool _isLoading = false;
  String? _error;
  bool _isVerticalMode =
      false; // true for vertical scroll, false for horizontal paging

  List<String> get pages => _pages;
  int get currentPage => _currentPage;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isVerticalMode => _isVerticalMode;

  /// Load chapter pages and restore reading position
  Future<void> loadChapter({
    required String chapterId,
    required String sourceId,
    required String itemId,
    bool resumeFromSavedPage = true,
    WatchHistoryController? watchHistoryController,
    MediaEntity? media,
    String? chapterNumber, // Add chapter number parameter
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Fetch chapter pages
      final result = await getChapterPages(
        GetChapterPagesParams(
          chapterId: chapterId,
          sourceId: sourceId,
          chapterNumber: chapterNumber,
        ),
      );

      result.fold(
        (failure) {
          _error = ErrorMessageMapper.mapFailureToMessage(failure);
          Logger.error(
            'Failed to load chapter pages',
            tag: 'MangaReaderViewModel',
            error: failure,
          );
          _isLoading = false;
          notifyListeners();
        },
        (pageUrls) async {
          _pages = pageUrls;

          // Debug: Log the first few page URLs to verify they're valid
          debugPrint('DEBUG: Loaded ${_pages.length} page URLs');
          if (_pages.isNotEmpty) {
            debugPrint('DEBUG: First page URL: ${_pages[0]}');
            if (_pages.length > 1) {
              debugPrint('DEBUG: Second page URL: ${_pages[1]}');
            }
          }

          // Try to restore saved reading position if requested
          if (resumeFromSavedPage) {
            debugPrint(
              'DEBUG: MangaReaderViewModel attempting to load saved position',
            );

            // First try watch history if available (doesn't require library membership)
            if (watchHistoryController != null && media != null) {
              try {
                final entry = await watchHistoryController.getEntryForMedia(
                  media.id,
                  sourceId,
                  media.type,
                );

                final savedPage = entry?.pageNumber;
                if (savedPage != null && savedPage > 0) {
                  _currentPage = savedPage.clamp(0, _pages.length - 1);
                  debugPrint(
                    'DEBUG: MangaReaderViewModel loaded saved page from watch history: $savedPage, clamped to: $_currentPage',
                  );
                  // Don't return early - let method continue to ensure UI state is properly updated
                }
              } catch (e) {
                debugPrint('Error loading watch history position: $e');
              }
            }

            // Fall back to library repository
            final positionResult = await getReadingPosition(
              GetReadingPositionParams(itemId: itemId, chapterId: chapterId),
            );

            positionResult.fold(
              (failure) {
                // No saved position, start from beginning
                _currentPage = 0;
                Logger.info(
                  'No saved reading position found in library',
                  tag: 'MangaReaderViewModel',
                );
                debugPrint(
                  'DEBUG: MangaReaderViewModel no saved position found in library',
                );
              },
              (savedPage) {
                _currentPage = savedPage.clamp(0, _pages.length - 1);
                debugPrint(
                  'DEBUG: MangaReaderViewModel loaded saved page from library: $savedPage, clamped to: $_currentPage',
                );
              },
            );
          } else {
            // Start from beginning
            _currentPage = 0;
            debugPrint(
              'DEBUG: MangaReaderViewModel resumeFromSavedPage is false, starting from page 0',
            );
          }

          _isLoading = false;
          notifyListeners();
        },
      );
    } catch (e, stackTrace) {
      _error = 'An unexpected error occurred. Please try again.';
      Logger.error(
        'Unexpected error loading chapter',
        tag: 'MangaReaderViewModel',
        error: e,
        stackTrace: stackTrace,
      );
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update current page and save position
  Future<void> setCurrentPage(int page, String itemId, String chapterId) async {
    if (page >= 0 && page < _pages.length) {
      _currentPage = page;
      notifyListeners();

      // Save reading position
      await saveReadingPosition(
        SaveReadingPositionParams(
          itemId: itemId,
          chapterId: chapterId,
          page: page,
        ),
      );
    }
  }

  /// Toggle between vertical scroll and horizontal paging mode
  void toggleReadingMode() {
    _isVerticalMode = !_isVerticalMode;
    notifyListeners();
  }

  /// Go to next page
  void nextPage(String itemId, String chapterId) {
    if (_currentPage < _pages.length - 1) {
      setCurrentPage(_currentPage + 1, itemId, chapterId);
    }
  }

  /// Go to previous page
  void previousPage(String itemId, String chapterId) {
    if (_currentPage > 0) {
      setCurrentPage(_currentPage - 1, itemId, chapterId);
    }
  }

  /// Clear error message
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
