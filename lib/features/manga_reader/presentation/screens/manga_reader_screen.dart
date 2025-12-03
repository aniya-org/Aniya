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

  const MangaReaderScreen({
    super.key,
    required this.chapter,
    required this.sourceId,
    required this.itemId,
    this.media,
    this.source,
    this.resumeFromSavedPage = true,
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
    _initializeReader();
  }

  Future<void> _initializeReader() async {
    await _viewModel.loadChapter(
      chapterId: widget.chapter.id,
      sourceId: widget.sourceId,
      itemId: widget.itemId,
      resumeFromSavedPage: widget.resumeFromSavedPage,
      watchHistoryController: _watchHistoryController,
      media: widget.media,
    );

    if (mounted && !_viewModel.isLoading && _viewModel.error == null) {
      setState(() {
        _isInitialized = true;
      });

      _applySavedPagePosition();

      // Initialize history with first page
      _updateWatchHistory(0);

      // Add a small delay to ensure UI is fully rendered before showing dialog
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _maybePromptResumeReading();
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleVerticalScroll);
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleVerticalScroll() {
    if (!_viewModel.isVerticalMode || _viewModel.pages.isEmpty) return;

    // Calculate current page based on scroll position
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final progress = maxScroll > 0 ? currentScroll / maxScroll : 0.0;
    final currentPage = (progress * (_viewModel.pages.length - 1))
        .round()
        .clamp(0, _viewModel.pages.length - 1);

    // Update history if page changed
    if (currentPage != _viewModel.currentPage) {
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
      _pageController = PageController(initialPage: _viewModel.currentPage);
      if (_shouldResumeFromSavedPage && _viewModel.currentPage > 0) {
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
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _showControls
          ? AppBar(
              backgroundColor: Colors.black.withOpacity(0.7),
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
                        color: Colors.white.withOpacity(0.7),
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
      body: AnimatedBuilder(
        animation: _viewModel,
        builder: (context, child) {
          if (_viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_viewModel.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 64),
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

          return GestureDetector(
            onTap: _toggleControls,
            child: _viewModel.isVerticalMode
                ? _buildVerticalReader()
                : _buildHorizontalReader(),
          );
        },
      ),
      bottomNavigationBar: _showControls && _isInitialized
          ? _buildBottomControls()
          : null,
    );
  }

  Future<void> _maybePromptResumeReading() async {
    debugPrint('DEBUG: _maybePromptResumeReading called');
    debugPrint('DEBUG: resumeFromSavedPage=${widget.resumeFromSavedPage}');
    debugPrint('DEBUG: savedPage=${_viewModel.currentPage}');

    if (!widget.resumeFromSavedPage) {
      debugPrint('DEBUG: resumeFromSavedPage is false, returning');
      _shouldResumeFromSavedPage = false;
      return;
    }

    // Check both library and watch history for saved position
    bool hasSavedPosition = _viewModel.currentPage > 0;

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
        }
      } catch (e) {
        debugPrint('Error checking watch history: $e');
      }
    }

    if (!hasSavedPosition) {
      debugPrint('DEBUG: No saved position found, no prompt needed');
      _shouldResumeFromSavedPage = false;
      return;
    }

    if (!mounted) {
      debugPrint('DEBUG: Not mounted, returning');
      return;
    }

    debugPrint('DEBUG: Showing resume dialog');
    final shouldResume = await _showResumeReadingDialog(
      _viewModel.currentPage,
      _viewModel.pages.length,
    );
    debugPrint('DEBUG: shouldResume=$shouldResume');

    if (!mounted) {
      debugPrint('DEBUG: Not mounted after dialog, returning');
      return;
    }

    if (!shouldResume) {
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
      debugPrint('DEBUG: User chose to resume');
      _shouldResumeFromSavedPage = true;
    }
  }

  Future<bool> _showResumeReadingDialog(int pageIndex, int totalPages) async {
    final pageLabel = pageIndex + 1;
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Resume reading?'),
            content: Text(
              'Continue from page $pageLabel of $totalPages or start over?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Start Over'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Resume'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _applySavedPagePosition() {
    if (!_shouldResumeFromSavedPage) return;
    final savedPage = _viewModel.currentPage;
    if (savedPage <= 0) return;

    if (_viewModel.isVerticalMode) {
      _jumpToVerticalPage(savedPage);
    } else {
      _pageController.jumpToPage(savedPage);
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
    _scrollController.jumpTo(targetOffset);
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
    return PhotoViewGallery.builder(
      scrollPhysics: const BouncingScrollPhysics(),
      builder: (BuildContext context, int index) {
        return PhotoViewGalleryPageOptions(
          imageProvider: NetworkImage(_viewModel.pages[index]),
          initialScale: PhotoViewComputedScale.contained,
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 3,
          heroAttributes: PhotoViewHeroAttributes(tag: 'page_$index'),
        );
      },
      itemCount: _viewModel.pages.length,
      loadingBuilder: (context, event) => Center(
        child: CircularProgressIndicator(
          value: event == null
              ? 0
              : event.cumulativeBytesLoaded / (event.expectedTotalBytes ?? 1),
        ),
      ),
      backgroundDecoration: const BoxDecoration(color: Colors.black),
      pageController: _pageController,
      onPageChanged: (index) {
        _viewModel.setCurrentPage(index, widget.itemId, widget.chapter.id);
        _updateWatchHistory(index);
      },
    );
  }

  Widget _buildVerticalPage(int index) {
    final imageUrl = _viewModel.pages[index];
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
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  return child;
                }

                final expectedBytes = loadingProgress.expectedTotalBytes;
                final loadedBytes = loadingProgress.cumulativeBytesLoaded;

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
              errorBuilder: (context, error, stackTrace) => Padding(
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
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomControls() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: _viewModel.currentPage > 0
                  ? () {
                      if (_viewModel.isVerticalMode) {
                        _viewModel.previousPage(
                          widget.itemId,
                          widget.chapter.id,
                        );
                        _updateWatchHistory(_viewModel.currentPage);
                      } else {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    }
                  : null,
            ),
            Expanded(
              child: Slider(
                value: _viewModel.currentPage.toDouble(),
                min: 0,
                max: (_viewModel.pages.length - 1).toDouble(),
                divisions: _viewModel.pages.length - 1,
                label: 'Page ${_viewModel.currentPage + 1}',
                onChanged: (value) {
                  final page = value.toInt();
                  if (_viewModel.isVerticalMode) {
                    _viewModel.setCurrentPage(
                      page,
                      widget.itemId,
                      widget.chapter.id,
                    );
                    _updateWatchHistory(page);
                    // Scroll to approximate position
                    final scrollPosition =
                        (page / _viewModel.pages.length) *
                        _scrollController.position.maxScrollExtent;
                    _scrollController.animateTo(
                      scrollPosition,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  } else {
                    _pageController.animateToPage(
                      page,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
              onPressed: _viewModel.currentPage < _viewModel.pages.length - 1
                  ? () {
                      if (_viewModel.isVerticalMode) {
                        _viewModel.nextPage(widget.itemId, widget.chapter.id);
                        _updateWatchHistory(_viewModel.currentPage);
                      } else {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
