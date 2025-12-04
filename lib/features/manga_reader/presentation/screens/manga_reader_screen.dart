import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/domain/entities/chapter_entity.dart';
import '../../../../core/domain/entities/media_entity.dart';
import '../../../../core/domain/entities/source_entity.dart';
import '../../../../core/domain/usecases/get_chapter_pages_usecase.dart';
import '../../../../core/domain/usecases/save_reading_position_usecase.dart';
import '../../../../core/domain/usecases/get_reading_position_usecase.dart';
import '../../../../core/services/watch_history_controller.dart';
import '../viewmodels/manga_reader_viewmodel.dart';

/// Manga reader screen for reading manga chapters
///
/// This screen provides:
/// - Vertical scroll mode for continuous reading
/// - Horizontal paging mode for page-by-page reading
/// - Zoom and pan functionality for each page
/// - Reading progress saving with auto-save on page change
/// - Resume from saved position
/// - Page indicator and navigation controls
class MangaReaderScreen extends StatefulWidget {
  final ChapterEntity chapter;
  final String sourceId;
  final String itemId;

  /// Optional media info for watch history tracking
  final MediaEntity? media;
  final SourceEntity? source;
  final String? chapterNumber; // Add chapter number field

  const MangaReaderScreen({
    super.key,
    required this.chapter,
    required this.sourceId,
    required this.itemId,
    this.media,
    this.source,
    this.resumeFromSavedPage = true,
    this.chapterNumber, // Add chapter number parameter
  });

  final bool resumeFromSavedPage;

  @override
  State<MangaReaderScreen> createState() => _MangaReaderScreenState();
}

class _MangaReaderScreenState extends State<MangaReaderScreen> {
  late MangaReaderViewModel _viewModel;
  late PageController _pageController;
  late ScrollController _scrollController;
  WatchHistoryController? _watchHistoryController;
  bool _showControls = true;
  bool _isInitialized = false;
  bool _shouldResumeFromSavedPage = false;
  bool _isProgrammaticallyScrolling = false;
  bool _isResuming = false;

  @override
  void initState() {
    super.initState();
    // Try to get ViewModel from DI, or create a new instance
    try {
      _viewModel = sl<MangaReaderViewModel>();
    } catch (e) {
      // If not registered, create manually
      // This is a fallback - in production, should be registered in DI
      _viewModel = MangaReaderViewModel(
        getChapterPages: sl<GetChapterPagesUseCase>(),
        saveReadingPosition: sl<SaveReadingPositionUseCase>(),
        getReadingPosition: sl<GetReadingPositionUseCase>(),
      );
    }

    // Initialize WatchHistoryController if available
    if (sl.isRegistered<WatchHistoryController>()) {
      _watchHistoryController = sl<WatchHistoryController>();
    }

    _pageController = PageController();
    _scrollController = ScrollController();
    _scrollController.addListener(_handleVerticalScroll);

    // Add listener to ViewModel to detect when loading completes
    _viewModel.addListener(_onViewModelChanged);

    _initializeReader();
  }

  void _onViewModelChanged() {
    debugPrint(
      'DEBUG: _onViewModelChanged called, isLoading=${_viewModel.isLoading}, error=${_viewModel.error}',
    );
    if (!_isInitialized &&
        mounted &&
        !_viewModel.isLoading &&
        _viewModel.error == null) {
      setState(() {
        _isInitialized = true;
      });
      debugPrint(
        'DEBUG: State updated in listener, _isInitialized=$_isInitialized',
      );

      _applySavedPagePosition();

      // Initialize history with first page
      _updateWatchHistory(0);

      debugPrint(
        'DEBUG: About to call _maybePromptResumeReading from listener',
      );
      _maybePromptResumeReading();
    }
  }

  Future<void> _initializeReader() async {
    debugPrint('DEBUG: _initializeReader started');
    await _viewModel.loadChapter(
      chapterId: widget.chapter.id,
      sourceId: widget.sourceId,
      itemId: widget.itemId,
      resumeFromSavedPage: widget.resumeFromSavedPage,
      watchHistoryController: _watchHistoryController,
      media: widget.media,
      chapterNumber: widget.chapterNumber, // Pass chapter number to viewmodel
    );

    debugPrint(
      'DEBUG: After loadChapter, mounted=$mounted, isLoading=${_viewModel.isLoading}, error=${_viewModel.error}',
    );

    if (mounted && !_viewModel.isLoading && _viewModel.error == null) {
      setState(() {
        _isInitialized = true;
      });
      debugPrint('DEBUG: State updated, _isInitialized=$_isInitialized');

      _applySavedPagePosition();

      // Initialize history with first page
      _updateWatchHistory(0);

      debugPrint('DEBUG: About to call _maybePromptResumeReading');
      _maybePromptResumeReading();
    } else {
      debugPrint(
        'DEBUG: Not calling _maybePromptResumeReading because mounted=$mounted, isLoading=${_viewModel.isLoading}, error=${_viewModel.error}',
      );
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleVerticalScroll);
    _viewModel.removeListener(_onViewModelChanged);
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleVerticalScroll() {
    if (_isProgrammaticallyScrolling ||
        !_viewModel.isVerticalMode ||
        _viewModel.pages.isEmpty)
      return;

    // Calculate current page based on scroll position
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final progress = maxScroll > 0 ? currentScroll / maxScroll : 0.0;
    final currentPage = (progress * (_viewModel.pages.length - 1))
        .round()
        .clamp(0, _viewModel.pages.length - 1);

    // Update history if page changed
    if (currentPage != _viewModel.currentPage) {
      debugPrint(
        'DEBUG: Vertical scroll detected page change: ${_viewModel.currentPage} -> $currentPage',
      );
      debugPrint(
        'DEBUG: Current scroll: $currentScroll, maxScroll: $maxScroll, progress: $progress',
      );
      _viewModel.setCurrentPage(currentPage, widget.itemId, widget.chapter.id);
      _updateWatchHistory(currentPage);
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  void _toggleReadingMode() {
    _viewModel.toggleReadingMode();
    setState(() {});

    // Switch to appropriate controller
    if (!_viewModel.isVerticalMode) {
      // Switching to horizontal mode
      // Always create the PageController with the current page, regardless of whether we're resuming
      _pageController = PageController(initialPage: _viewModel.currentPage);

      // If we should resume from saved page and have a saved page, jump to it
      if (_shouldResumeFromSavedPage && _viewModel.currentPage > 0) {
        debugPrint(
          'DEBUG: Jumping to saved page ${_viewModel.currentPage} in horizontal mode',
        );
        _pageController.jumpToPage(_viewModel.currentPage);
      }
    }
  }

  /// Update watch history with current reading progress
  Future<void> _updateWatchHistory(int pageNumber) async {
    debugPrint(
      'DEBUG: MangaReader _updateWatchHistory called with pageNumber: $pageNumber',
    );
    debugPrint(
      'DEBUG: _watchHistoryController=${_watchHistoryController != null}',
    );
    debugPrint('DEBUG: widget.media=${widget.media != null}');
    debugPrint('DEBUG: widget.source=${widget.source != null}');

    if (_watchHistoryController == null) {
      debugPrint('DEBUG: WatchHistoryController is null, returning');
      return;
    }
    if (widget.media == null || widget.source == null) {
      debugPrint('DEBUG: media or source is null, returning');
      return;
    }

    await _watchHistoryController!.updateReadingProgress(
      mediaId: widget.media!.id,
      mediaType: widget.media!.type,
      title: widget.media!.title,
      coverImage: widget.media!.coverImage,
      sourceId: widget.source!.id,
      sourceName: widget.source!.name,
      pageNumber: pageNumber,
      totalPages: _viewModel.pages.length,
      chapterNumber: widget.chapter.number.toInt(),
      chapterId: widget.chapter.id,
      chapterTitle: widget.chapter.title,
      normalizedId: null, // MediaEntity doesn't have normalizedId yet
    );
    debugPrint('DEBUG: MangaReader watch history update completed');
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
      'DEBUG: build() called, _showControls=$_showControls, _isInitialized=$_isInitialized',
    );

    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, child) {
        debugPrint(
          'DEBUG: AnimatedBuilder called for entire Scaffold, isLoading=${_viewModel.isLoading}, currentPage=${_viewModel.currentPage}',
        );

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: _showControls
              ? AppBar(
                  backgroundColor: Colors.black.withValues(alpha: 0.7),
                  elevation: 0,
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.chapter.title,
                        style: const TextStyle(fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_isInitialized && _viewModel.pages.isNotEmpty)
                        Text(
                          'Page ${_viewModel.currentPage + 1} of ${_viewModel.pages.length}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                    ],
                  ),
                  actions: [
                    IconButton(
                      icon: Icon(
                        _viewModel.isVerticalMode
                            ? Icons.view_carousel
                            : Icons.view_day,
                      ),
                      onPressed: _toggleReadingMode,
                      tooltip: _viewModel.isVerticalMode
                          ? 'Switch to horizontal paging'
                          : 'Switch to vertical scroll',
                    ),
                  ],
                )
              : null,
          body: SafeArea(
            // Force a background color for the entire body
            child: Column(
              children: [
                Expanded(
                  child: () {
                    if (_viewModel.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (_viewModel.error != null) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _viewModel.error!,
                              style: const TextStyle(color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => _initializeReader(),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    }

                    if (_viewModel.pages.isEmpty) {
                      return const Center(
                        child: Text(
                          'No pages available',
                          style: TextStyle(color: Colors.white),
                        ),
                      );
                    }

                    debugPrint('DEBUG: About to build main content stack');
                    debugPrint(
                      'DEBUG: Pages count: ${_viewModel.pages.length}',
                    );
                    debugPrint(
                      'DEBUG: Is vertical mode: ${_viewModel.isVerticalMode}',
                    );
                    debugPrint('DEBUG: Is initialized: $_isInitialized');

                    return Container(
                      color: Colors.black,
                      child: _viewModel.isVerticalMode
                          ? _buildVerticalReader()
                          : _buildHorizontalReader(),
                    );
                  }(),
                ),
                _buildBottomControls(),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _maybePromptResumeReading() async {
    debugPrint('DEBUG: _maybePromptResumeReading called');
    debugPrint('DEBUG: resumeFromSavedPage=${widget.resumeFromSavedPage}');
    debugPrint('DEBUG: Initial savedPage=${_viewModel.currentPage}');

    if (!widget.resumeFromSavedPage) {
      debugPrint('DEBUG: resumeFromSavedPage is false, returning');
      _shouldResumeFromSavedPage = false;
      return;
    }

    // Check both library and watch history for saved position
    bool hasSavedPosition = _viewModel.currentPage > 0;
    debugPrint(
      'DEBUG: Initial hasSavedPosition (from viewmodel)=$hasSavedPosition',
    );

    if (!hasSavedPosition &&
        _watchHistoryController != null &&
        widget.media != null) {
      try {
        final entry = await _watchHistoryController!.getEntryForMedia(
          widget.media!.id,
          widget.source!.id,
          widget.media!.type,
        );
        hasSavedPosition = entry?.pageNumber != null && entry!.pageNumber! > 0;
        debugPrint('DEBUG: Watch history entry found: $entry');
        debugPrint(
          'DEBUG: After checking watch history, hasSavedPosition=$hasSavedPosition',
        );
        if (hasSavedPosition) {
          debugPrint(
            'DEBUG: Found saved position in watch history: page ${entry.pageNumber}',
          );
          // Update the view model with the position from watch history
          await _viewModel.setCurrentPage(
            entry.pageNumber!,
            widget.itemId,
            widget.chapter.id,
          );
          debugPrint('DEBUG: Updated view model with page ${entry.pageNumber}');
        }
      } catch (e) {
        debugPrint('Error checking watch history: $e');
      }
    }

    debugPrint('DEBUG: Final hasSavedPosition=$hasSavedPosition');
    debugPrint(
      'DEBUG: _viewModel.currentPage=${_viewModel.currentPage} (before dialog)',
    );

    if (!hasSavedPosition) {
      debugPrint('DEBUG: No saved position found, no prompt needed');
      _shouldResumeFromSavedPage = false;
      return;
    }

    if (!mounted) {
      debugPrint('DEBUG: Not mounted, returning');
      return;
    }

    // Store the saved page to prevent it from getting reset
    final savedPageToResume = _viewModel.currentPage;
    debugPrint('DEBUG: Stored savedPageToResume=$savedPageToResume');

    debugPrint('DEBUG: About to show resume dialog');
    final shouldResume = await _showResumeReadingDialog(
      savedPageToResume,
      _viewModel.pages.length,
    );
    debugPrint('DEBUG: shouldResume=$shouldResume');

    if (!mounted) {
      debugPrint('DEBUG: Not mounted after dialog, returning');
      return;
    }

    if (!shouldResume) {
      debugPrint('DEBUG: ===== USER CHOSE START OVER =====');
      debugPrint('DEBUG: User chose to start over');
      await _viewModel.setCurrentPage(0, widget.itemId, widget.chapter.id);
      _shouldResumeFromSavedPage = false;
      if (_viewModel.isVerticalMode) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.jumpTo(0);
            }
          });
        }
      } else {
        _pageController.jumpToPage(0);
      }
    } else {
      debugPrint('DEBUG: ===== ENTERING RESUME BRANCH =====');
      debugPrint('DEBUG: === SIMPLE RESUME TEST ===');
      debugPrint('DEBUG: User chose to resume');
      debugPrint('DEBUG: savedPageToResume: $savedPageToResume');

      try {
        _shouldResumeFromSavedPage = true;

        debugPrint('DEBUG: About to test direct page jump');
        if (_pageController.hasClients) {
          debugPrint(
            'DEBUG: PageController has clients, jumping to page $savedPageToResume',
          );
          _pageController.jumpToPage(savedPageToResume);
          debugPrint('DEBUG: jumpToPage completed');
        } else {
          debugPrint('DEBUG: PageController has no clients');
        }

        debugPrint('DEBUG: Resume test completed');
      } catch (e) {
        debugPrint('DEBUG: Exception in resume logic: $e');
      }

      debugPrint('DEBUG: === END SIMPLE RESUME TEST ===');
    }
  }

  Future<bool> _showResumeReadingDialog(int pageIndex, int totalPages) async {
    debugPrint(
      'DEBUG: _showResumeReadingDialog called with pageIndex=$pageIndex, totalPages=$totalPages',
    );
    final pageLabel = pageIndex + 1;
    debugPrint(
      'DEBUG: About to show dialog for page $pageLabel of $totalPages',
    );
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        debugPrint('DEBUG: Building dialog');
        return AlertDialog(
          title: const Text('Resume reading?'),
          content: Text(
            'Continue from page $pageLabel of $totalPages or start over?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                debugPrint('DEBUG: Start Over pressed');
                Navigator.of(ctx).pop(false);
              },
              child: const Text('Start Over'),
            ),
            FilledButton(
              onPressed: () {
                debugPrint('DEBUG: Resume pressed');
                _applySavedPagePosition();
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Resume'),
            ),
          ],
        );
      },
    );
    debugPrint('DEBUG: Dialog result: $result');
    return result ?? false;
  }

  void _applySavedPagePosition() {
    debugPrint(
      'DEBUG: _applySavedPagePosition called, _shouldResumeFromSavedPage=$_shouldResumeFromSavedPage, savedPage=${_viewModel.currentPage}',
    );
    if (!_shouldResumeFromSavedPage) {
      debugPrint('DEBUG: _shouldResumeFromSavedPage is false, returning');
      return;
    }
    final savedPage = _viewModel.currentPage;
    if (savedPage <= 0) {
      debugPrint('DEBUG: savedPage <= 0, returning');
      return;
    }

    debugPrint(
      'DEBUG: Applying saved page position: $savedPage, isVerticalMode=${_viewModel.isVerticalMode}',
    );

    // Ensure pages are loaded before applying position
    if (_viewModel.pages.isEmpty) {
      debugPrint('DEBUG: Pages not loaded yet, cannot apply position');
      return;
    }

    if (_viewModel.isVerticalMode) {
      _jumpToVerticalPage(savedPage);
    } else {
      // For horizontal mode, we need to ensure the page controller is properly initialized
      if (_pageController.hasClients) {
        debugPrint('DEBUG: Jumping to page $savedPage in horizontal mode');
        _pageController.jumpToPage(savedPage);
      } else {
        debugPrint('DEBUG: Page controller not ready, will try again');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) {
            debugPrint(
              'DEBUG: Jumping to page $savedPage in horizontal mode (post frame)',
            );
            _pageController.jumpToPage(savedPage);
          } else {
            debugPrint(
              'DEBUG: Page controller still not ready, trying again with delay',
            );
            // Try again with a longer delay
            Future.delayed(const Duration(milliseconds: 100), () {
              if (_pageController.hasClients && mounted) {
                debugPrint(
                  'DEBUG: Jumping to page $savedPage in horizontal mode (delayed)',
                );
                _pageController.jumpToPage(savedPage);
              }
            });
          }
        });
      }
    }
  }

  void _jumpToVerticalPage(int pageIndex) {
    if (!_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _jumpToVerticalPage(pageIndex),
      );
      return;
    }
    final totalPages = _viewModel.pages.length;
    if (totalPages <= 1) return;
    final ratio = (pageIndex / (totalPages - 1)).clamp(0.0, 1.0);
    final targetOffset = _scrollController.position.maxScrollExtent * ratio;
    debugPrint(
      'DEBUG: _jumpToVerticalPage to page $pageIndex (ratio: $ratio, offset: $targetOffset)',
    );

    _isProgrammaticallyScrolling = true;
    _scrollController.jumpTo(targetOffset);

    // Reset the flag after a short delay to allow the scroll to complete
    Future.delayed(const Duration(milliseconds: 100), () {
      _isProgrammaticallyScrolling = false;
    });
  }

  Widget _buildVerticalReader() {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _viewModel.pages.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: _toggleControls,
          child: _buildVerticalPage(index),
        );
      },
    );
  }

  Widget _buildHorizontalReader() {
    debugPrint(
      'DEBUG: _buildHorizontalReader called with ${_viewModel.pages.length} pages',
    );
    debugPrint(
      'DEBUG: _buildHorizontalReader PageController initialPage: ${_pageController.initialPage}',
    );
    debugPrint(
      'DEBUG: _buildHorizontalReader PageController hasClients: ${_pageController.hasClients}',
    );

    if (_viewModel.pages.isEmpty) {
      debugPrint('DEBUG: No pages available, showing empty state');
      return const Center(
        child: Text(
          'No pages to display',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return PhotoViewGallery.builder(
      scrollDirection: Axis.horizontal,
      reverse: false,
      pageController: _pageController,
      onPageChanged: (index) {
        debugPrint('DEBUG: PhotoViewGallery page changed to $index');
        _viewModel.setCurrentPage(index, widget.itemId, widget.chapter.id);
        _updateWatchHistory(index);
      },
      itemCount: _viewModel.pages.length,
      builder: (context, index) {
        return PhotoViewGalleryPageOptions(
          imageProvider: NetworkImage(
            _viewModel.pages[index],
            headers: const {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            },
          ),
          initialScale: PhotoViewComputedScale.contained,
          heroAttributes: PhotoViewHeroAttributes(tag: _viewModel.pages[index]),
          minScale: PhotoViewComputedScale.contained * 0.5,
          maxScale: PhotoViewComputedScale.covered * 4.0,
          errorBuilder: (context, error, stackTrace) {
            debugPrint(
              'DEBUG: PhotoView image load error for page ${index + 1}: $error',
            );
            debugPrint('DEBUG: Failed URL: ${_viewModel.pages[index]}');
            return Container(
              color: Colors.black,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: 48,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Failed to load page ${index + 1}',
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'URL: ${_viewModel.pages[index].length > 50 ? '${_viewModel.pages[index].substring(0, 50)}...' : _viewModel.pages[index]}',
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          },
        );
      },
      backgroundDecoration: const BoxDecoration(color: Colors.black),
      enableRotation: false,
      scrollPhysics: const BouncingScrollPhysics(),
    );
  }

  Widget _buildVerticalPage(int index) {
    final imageUrl = _viewModel.pages[index];
    // Debug: Log each vertical page being built
    if (index < 5) {
      // Only log first 5 to avoid spam
      debugPrint('DEBUG: Building vertical page $index with URL: $imageUrl');
    }
    debugPrint('DEBUG: Creating vertical Image.network for URL: $imageUrl');

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: constraints.maxWidth,
          color: Colors.black,
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 3,
            clipBehavior: Clip.none,
            child: Image.network(
              imageUrl,
              width: constraints.maxWidth,
              fit: BoxFit.fitWidth,
              alignment: Alignment.topCenter,
              headers: const {
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  debugPrint('DEBUG: Vertical page $index loaded successfully');
                  return child;
                }

                final expectedBytes = loadingProgress.expectedTotalBytes;
                final loadedBytes = loadingProgress.cumulativeBytesLoaded;
                debugPrint(
                  'DEBUG: Vertical page $index loading progress: $loadedBytes/$expectedBytes',
                );

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(
                      value: expectedBytes != null
                          ? loadedBytes / expectedBytes
                          : null,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                // Debug: Log image loading errors
                debugPrint(
                  'DEBUG: Image load error for page ${index + 1}: $error',
                );
                debugPrint('DEBUG: Image URL that failed: $imageUrl');
                debugPrint('DEBUG: Stack trace: $stackTrace');

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 48,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Failed to load page ${index + 1}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'URL: ${imageUrl.length > 50 ? '${imageUrl.substring(0, 50)}...' : imageUrl}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        error.toString(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomControls() {
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: _viewModel.currentPage > 0
                ? () {
                    if (_viewModel.isVerticalMode) {
                      final newPage = _viewModel.currentPage - 1;
                      debugPrint(
                        'DEBUG: Previous button clicked, going to page $newPage',
                      );
                      _viewModel.previousPage(widget.itemId, widget.chapter.id);
                      _updateWatchHistory(_viewModel.currentPage);
                      // Scroll to the new position
                      _jumpToVerticalPage(newPage);
                    } else {
                      // Check if PageController has clients before using it
                      if (_pageController.hasClients) {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    }
                  }
                : null,
          ),
          Expanded(
            child: Slider(
              value: _viewModel.currentPage.toDouble(),
              min: 0,
              max: (_viewModel.pages.length - 1).toDouble().clamp(
                0.0,
                double.infinity,
              ),
              divisions: _viewModel.pages.length > 1
                  ? _viewModel.pages.length - 1
                  : 1,
              label: 'Page ${_viewModel.currentPage + 1}',
              onChanged: (value) {
                // Ignore slider changes while resuming to prevent interference
                if (_isResuming) {
                  debugPrint('DEBUG: Ignoring slider change during resume');
                  return;
                }

                final page = value.toInt();
                debugPrint(
                  'DEBUG: Slider changed to page $page, current ViewModel page: ${_viewModel.currentPage}',
                );
                if (_viewModel.isVerticalMode) {
                  _viewModel.setCurrentPage(
                    page,
                    widget.itemId,
                    widget.chapter.id,
                  );
                  _updateWatchHistory(page);
                  // Scroll to correct position using same calculation as _handleVerticalScroll
                  if (_scrollController.hasClients &&
                      _viewModel.pages.length > 1) {
                    final ratio = (page / (_viewModel.pages.length - 1)).clamp(
                      0.0,
                      1.0,
                    );
                    final scrollPosition =
                        ratio * _scrollController.position.maxScrollExtent;
                    debugPrint(
                      'DEBUG: Slider scrolling to position: $scrollPosition (ratio: $ratio)',
                    );
                    _isProgrammaticallyScrolling = true;
                    _scrollController
                        .animateTo(
                          scrollPosition,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        )
                        .then((_) {
                          _isProgrammaticallyScrolling = false;
                        });
                  }
                } else {
                  // Check if PageController has clients before using it
                  if (_pageController.hasClients) {
                    _pageController.animateToPage(
                      page,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                }
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
            onPressed: _viewModel.currentPage < _viewModel.pages.length - 1
                ? () {
                    if (_viewModel.isVerticalMode) {
                      final newPage = _viewModel.currentPage + 1;
                      debugPrint(
                        'DEBUG: Next button clicked, going to page $newPage',
                      );
                      _viewModel.nextPage(widget.itemId, widget.chapter.id);
                      _updateWatchHistory(_viewModel.currentPage);
                      // Scroll to the new position
                      _jumpToVerticalPage(newPage);
                    } else {
                      // Check if PageController has clients before using it
                      if (_pageController.hasClients) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    }
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
