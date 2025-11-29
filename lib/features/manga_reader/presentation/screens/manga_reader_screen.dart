import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/domain/entities/chapter_entity.dart';
import '../../../../core/domain/usecases/get_chapter_pages_usecase.dart';
import '../../../../core/domain/usecases/save_reading_position_usecase.dart';
import '../../../../core/domain/usecases/get_reading_position_usecase.dart';
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

  const MangaReaderScreen({
    super.key,
    required this.chapter,
    required this.sourceId,
    required this.itemId,
  });

  @override
  State<MangaReaderScreen> createState() => _MangaReaderScreenState();
}

class _MangaReaderScreenState extends State<MangaReaderScreen> {
  late MangaReaderViewModel _viewModel;
  late PageController _pageController;
  late ScrollController _scrollController;
  bool _showControls = true;
  bool _isInitialized = false;

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
    _pageController = PageController();
    _scrollController = ScrollController();
    _initializeReader();
  }

  Future<void> _initializeReader() async {
    await _viewModel.loadChapter(
      chapterId: widget.chapter.id,
      sourceId: widget.sourceId,
      itemId: widget.itemId,
    );

    if (mounted && !_viewModel.isLoading && _viewModel.error == null) {
      setState(() {
        _isInitialized = true;
      });

      // Jump to saved page in horizontal mode
      if (!_viewModel.isVerticalMode && _viewModel.currentPage > 0) {
        _pageController.jumpToPage(_viewModel.currentPage);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
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
    }
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

  Widget _buildVerticalReader() {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _viewModel.pages.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: _toggleControls,
          child: _buildPageWithZoom(index),
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
      },
    );
  }

  Widget _buildPageWithZoom(int index) {
    final screenHeight = MediaQuery.of(context).size.height;
    return SizedBox(
      height: screenHeight,
      child: PhotoView(
        imageProvider: NetworkImage(_viewModel.pages[index]),
        initialScale: PhotoViewComputedScale.contained,
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 3,
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        loadingBuilder: (context, event) => Center(
          child: CircularProgressIndicator(
            value: event == null
                ? 0
                : event.cumulativeBytesLoaded / (event.expectedTotalBytes ?? 1),
          ),
        ),
        errorBuilder: (context, error, stackTrace) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 8),
              Text(
                'Failed to load page ${index + 1}',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
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
