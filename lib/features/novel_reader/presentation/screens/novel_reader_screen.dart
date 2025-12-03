import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/domain/entities/chapter_entity.dart';
import '../../../../core/domain/entities/media_entity.dart';
import '../../../../core/domain/entities/source_entity.dart';
import '../../../../core/domain/usecases/get_chapters_usecase.dart';
import '../../../../core/domain/usecases/get_novel_chapter_content_usecase.dart';
import '../../../../core/domain/usecases/get_reading_position_usecase.dart';
import '../../../../core/domain/usecases/save_reading_position_usecase.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/watch_history_controller.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/error_message_mapper.dart';
import '../../../../core/utils/logger.dart';
import '../../../../features/media_details/presentation/widgets/empty_state_widgets.dart';
import '../widgets/novel_markdown_renderer.dart';
import '../../../media_details/presentation/models/source_selection_result.dart';

/// Novel reader screen for reading light novel chapters
///
/// This screen provides:
/// - Clean, distraction-free reading experience
/// - Adjustable font size and theme
/// - Reading progress tracking
/// - Chapter navigation
class NovelReaderScreen extends StatefulWidget {
  final ChapterEntity chapter;
  final MediaEntity media;
  final List<ChapterEntity>? allChapters;
  final String? chapterContent;
  final SourceEntity? source;
  final SourceSelectionResult? sourceSelection;

  const NovelReaderScreen({
    super.key,
    required this.chapter,
    required this.media,
    this.allChapters,
    this.chapterContent,
    this.source,
    this.sourceSelection,
    this.resumeFromSavedPosition = true,
  });

  final bool resumeFromSavedPosition;

  @override
  State<NovelReaderScreen> createState() => _NovelReaderScreenState();
}

class _NovelReaderScreenState extends State<NovelReaderScreen> {
  final ScrollController _scrollController = ScrollController();
  static const double _scrollUnitExtent = 200.0;
  bool _showControls = true;
  double _fontSize = 16.0;
  bool _isDarkMode = true;
  String _fontFamily = 'Roboto';
  double _lineHeight = 1.6;
  bool _isLoading = false;
  String? _content;
  String? _error;
  bool _toggleInProgress = false;
  ChapterEntity? _currentChapter;
  int? _currentChapterIndex;
  String? _selectedSourceId;
  bool _initialContentConsumed = false;
  SourceSelectionResult? _sourceSelection;
  List<ChapterEntity>? _extensionChapters;
  bool _isLoadingExtensionChapters = false;
  late final GetNovelChapterContentUseCase _getChapterContent;
  late final GetChaptersUseCase _getChapters;
  late final SaveReadingPositionUseCase _saveReadingPosition;
  late final GetReadingPositionUseCase _getReadingPosition;
  WatchHistoryController? _watchHistoryController;
  int? _savedReadingUnits;
  bool _resumePromptShown = false;
  Timer? _savePositionDebounce;
  int? _lastSavedUnits;

  // Available font sizes
  static const List<double> _fontSizes = [12, 14, 16, 18, 20, 22, 24];

  @override
  void initState() {
    super.initState();
    try {
      _getChapterContent = sl<GetNovelChapterContentUseCase>();
    } catch (_) {
      _getChapterContent = GetNovelChapterContentUseCase(sl());
    }
    try {
      _getChapters = sl<GetChaptersUseCase>();
    } catch (_) {
      _getChapters = GetChaptersUseCase(sl());
    }
    try {
      _saveReadingPosition = sl<SaveReadingPositionUseCase>();
    } catch (_) {
      _saveReadingPosition = SaveReadingPositionUseCase(sl());
    }
    try {
      _getReadingPosition = sl<GetReadingPositionUseCase>();
    } catch (_) {
      _getReadingPosition = GetReadingPositionUseCase(sl());
    }
    _selectedSourceId =
        widget.source?.providerId ?? widget.chapter.sourceProvider;
    _currentChapter = widget.chapter.copyWith(
      sourceProvider: _selectedSourceId ?? widget.chapter.sourceProvider,
    );
    _sourceSelection = widget.sourceSelection;
    _currentChapterIndex = _findChapterIndex(widget.chapter);
    _scrollController.addListener(_handleScrollPosition);
    debugPrint('DEBUG: Scroll controller listener added');

    // Initialize WatchHistoryController if available
    if (sl.isRegistered<WatchHistoryController>()) {
      _watchHistoryController = sl<WatchHistoryController>();
    }

    _loadChapterContent();
    _loadExtensionChaptersIfNeeded();
    // Hide system UI for immersive reading
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _savePositionDebounce?.cancel();
    _scrollController.removeListener(_handleScrollPosition);
    if (_scrollController.hasClients) {
      _persistReadingPosition(_scrollController.position.pixels);
    }
    _scrollController.dispose();
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  ChapterEntity get _activeChapter => _currentChapter ?? widget.chapter;

  bool _chapterSupportsSelectedSource(ChapterEntity chapter) {
    if (_selectedSourceId == null || _selectedSourceId!.isEmpty) {
      return true;
    }
    if (chapter.sourceProvider == _selectedSourceId) {
      return true;
    }
    final id = chapter.id;
    if (id.startsWith('http://') || id.startsWith('https://')) {
      return true;
    }
    return false;
  }

  void _showSourceUnavailableMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'This chapter hasn\'t been linked to the selected source yet. '
          'Return to the details screen and open it from the source list to continue.',
        ),
      ),
    );
  }

  List<ChapterEntity>? get _availableChapters {
    if (_extensionChapters != null && _extensionChapters!.isNotEmpty) {
      return _extensionChapters;
    }
    return widget.allChapters;
  }

  int? _ensureCurrentIndex() {
    final chapters = _availableChapters;
    if (chapters == null || chapters.isEmpty) return null;
    final currentIndex = _currentChapterIndex;
    final isValidIndex =
        currentIndex != null &&
        currentIndex >= 0 &&
        currentIndex < chapters.length;
    if (isValidIndex) {
      return currentIndex;
    }

    final resolved = _findChapterIndex(_activeChapter);
    if (resolved != null) {
      _currentChapterIndex = resolved;
    }
    return resolved;
  }

  int? _findChapterIndex(ChapterEntity chapter) {
    final chapters = _availableChapters;
    if (chapters == null || chapters.isEmpty) return null;

    final idMatch = chapters.indexWhere((c) => c.id == chapter.id);
    if (idMatch != -1) return idMatch;

    final numberTitleMatch = chapters.indexWhere(
      (c) => c.number == chapter.number && c.title == chapter.title,
    );
    if (numberTitleMatch != -1) return numberTitleMatch;

    final numberMatch = chapters.indexWhere((c) => c.number == chapter.number);
    if (numberMatch != -1) return numberMatch;

    return null;
  }

  Future<void> _loadChapterContent({
    bool useInitialChapterContent = true,
  }) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final currentChapter = _activeChapter;
      debugPrint(
        'DEBUG: About to load saved reading position for chapter: ${currentChapter.id}',
      );
      await _loadSavedReadingPosition(currentChapter);
      debugPrint(
        'DEBUG: Finished loading saved reading position, _savedReadingUnits: $_savedReadingUnits',
      );
      _resumePromptShown = false;

      // If content was passed directly for the initial chapter, use it once
      if (useInitialChapterContent &&
          !_initialContentConsumed &&
          widget.chapterContent != null &&
          currentChapter.id == widget.chapter.id) {
        setState(() {
          _content = _normalizeContent(widget.chapterContent!);
          _isLoading = false;
          _initialContentConsumed = true;
        });
        return;
      }

      String? sourceProvider =
          _selectedSourceId ?? currentChapter.sourceProvider;
      sourceProvider ??=
          widget.source?.providerId ?? widget.chapter.sourceProvider;

      _selectedSourceId ??= sourceProvider;

      if (sourceProvider == null || sourceProvider.isEmpty) {
        throw const ValidationFailure(
          'Missing source information for this chapter.',
        );
      }

      final result = await _getChapterContent(
        GetNovelChapterContentParams(
          chapterId: currentChapter.id,
          chapterTitle: currentChapter.title,
          sourceId: sourceProvider,
        ),
      );

      result.fold(
        (failure) {
          throw failure;
        },
        (content) {
          setState(() {
            _content = _normalizeContent(content);
            _isLoading = false;
          });
          _scheduleResumePrompt();
          debugPrint('DEBUG: Content loaded, resume prompt scheduled');
        },
      );
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to load chapter content',
        error: e,
        stackTrace: stackTrace,
      );
      setState(() {
        if (e is Failure) {
          _error = ErrorMessageMapper.mapFailureToMessage(e);
        } else {
          _error = 'Failed to load chapter content. Please try again.';
        }
        _isLoading = false;
      });
      _savedReadingUnits = null;
    }
  }

  Future<void> _loadExtensionChaptersIfNeeded() async {
    if (_sourceSelection == null) return;
    if (_isLoadingExtensionChapters) return;
    if (_extensionChapters != null && _extensionChapters!.isNotEmpty) return;
    if (widget.allChapters != null && widget.allChapters!.isNotEmpty) return;

    final mediaId = _sourceSelection!.selectedMedia.id;
    final sourceId = _sourceSelection!.source.providerId;

    if (mediaId.isEmpty || sourceId.isEmpty) {
      Logger.warning(
        'Skipping extension chapter load due to missing media/source information',
        tag: 'NovelReaderScreen',
      );
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingExtensionChapters = true;
      });
    }

    try {
      final result = await _getChapters(
        GetChaptersParams(mediaId: mediaId, sourceId: sourceId),
      );

      result.fold(
        (failure) {
          Logger.error(
            'Failed to load extension chapters',
            tag: 'NovelReaderScreen',
            error: failure,
          );
        },
        (chapters) {
          if (!mounted || chapters.isEmpty) return;
          setState(() {
            _extensionChapters = chapters;
            _currentChapterIndex = _findChapterIndex(_activeChapter);
          });
        },
      );
    } catch (e, stackTrace) {
      Logger.error(
        'Unexpected error while loading extension chapters',
        tag: 'NovelReaderScreen',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoadingExtensionChapters = false;
      });
    }
  }

  String _normalizeContent(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return 'No content was returned for this chapter.';
    }

    final leadingAndTrailingQuotesAndWhitespaceRemoved = RegExp(
      r'''^["'\u201c\u201d\u00b4\u2019]*|["'\u201c\u201d\u00b4\u2019]*$''',
    );
    final normalized = trimmed.replaceAll(
      leadingAndTrailingQuotesAndWhitespaceRemoved,
      '',
    );

    const htmlPattern = r'<[^>]+>';
    final htmlRegex = RegExp(htmlPattern, multiLine: true);
    if (htmlRegex.hasMatch(normalized)) {
      return normalized;
    }

    final paragraphs = trimmed
        .replaceAll('\r', '')
        .split('\n')
        .map((line) => line.trim())
        .toList();

    final buffer = StringBuffer();
    for (final line in paragraphs) {
      if (line.isEmpty) {
        buffer.writeln();
        continue;
      }
      buffer.writeln(line);
    }

    return buffer.toString().trim();
  }

  void _toggleControls() {
    if (_toggleInProgress) return;
    _toggleInProgress = true;
    setState(() {
      _showControls = !_showControls;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _toggleInProgress = false;
    });
  }

  void _goToChapter(ChapterEntity chapter, {int? chapterIndex}) {
    if (_activeChapter.id == chapter.id) return;
    if (!_chapterSupportsSelectedSource(chapter)) {
      _showSourceUnavailableMessage();
      return;
    }
    setState(() {
      _currentChapter = chapter.copyWith(
        sourceProvider: _selectedSourceId ?? chapter.sourceProvider,
      );
      _currentChapterIndex = chapterIndex ?? _findChapterIndex(chapter);
      _content = null;
      _error = null;
    });
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
    _loadChapterContent(useInitialChapterContent: false);
  }

  void _handleScrollPosition() {
    if (_content == null || !_scrollController.hasClients) return;

    // Cancel previous timer to avoid multiple simultaneous calls
    _savePositionDebounce?.cancel();

    // Only save position if it has changed significantly (to reduce excessive calls)
    final currentOffset = _scrollController.position.pixels;
    final currentUnits = _scrollOffsetToUnits(currentOffset);

    // Only proceed if position changed by at least 1 unit or if this is the first call
    if (_lastSavedUnits == null ||
        (currentUnits - _lastSavedUnits!).abs() >= 1) {
      debugPrint(
        'DEBUG: _handleScrollPosition called - position changed significantly',
      );
      _savePositionDebounce = Timer(const Duration(milliseconds: 600), () {
        debugPrint(
          'DEBUG: Persisting reading position at offset: $currentOffset',
        );
        _persistReadingPosition(currentOffset);
        _lastSavedUnits = currentUnits;
      });
    }
  }

  Future<void> _loadSavedReadingPosition(ChapterEntity chapter) async {
    if (!widget.resumeFromSavedPosition) {
      _savedReadingUnits = null;
      return;
    }

    // First try watch history (doesn't require library membership)
    if (_watchHistoryController != null) {
      try {
        final entry = await _watchHistoryController!.getEntryForMedia(
          widget.media.id,
          widget.source?.id ?? _selectedSourceId ?? '',
          widget.media.type,
        );

        final positionMs = entry?.playbackPositionMs;
        if (positionMs != null && positionMs > 0) {
          // Convert milliseconds back to reading units
          _savedReadingUnits = (positionMs / (_scrollUnitExtent * 1000))
              .round();
          Logger.info(
            'Loaded saved position from watch history: $_savedReadingUnits units (${(positionMs / 1000).round()}ms)',
            tag: 'NovelReaderScreen',
          );
          return; // Return early if found in watch history
        }
      } catch (e) {
        Logger.error(
          'Error loading watch history position: $e',
          tag: 'NovelReaderScreen',
        );
      }
    }

    // Fall back to library repository only if watch history didn't work
    try {
      final result = await _getReadingPosition(
        GetReadingPositionParams(
          itemId: widget.media.id,
          chapterId: chapter.id,
        ),
      );

      result.fold((failure) {
        Logger.error(
          'Failed to load reading position from library: ${failure.message}',
          tag: 'NovelReaderScreen',
        );
      }, (page) => _savedReadingUnits = page > 0 ? page : null);
    } catch (e) {
      Logger.error(
        'Unexpected error loading reading position',
        tag: 'NovelReaderScreen',
        error: e,
      );
    }
  }

  void _scheduleResumePrompt() {
    debugPrint('DEBUG: _scheduleResumePrompt called');
    debugPrint(
      'DEBUG: resumeFromSavedPosition=${widget.resumeFromSavedPosition}',
    );
    debugPrint('DEBUG: _savedReadingUnits=$_savedReadingUnits');

    if (!widget.resumeFromSavedPosition) {
      debugPrint('DEBUG: resumeFromSavedPosition is false, returning');
      return;
    }
    if (_savedReadingUnits == null) {
      debugPrint('DEBUG: _savedReadingUnits is null, returning');
      return;
    }
    if (_resumePromptShown) {
      debugPrint('DEBUG: _resumePromptShown is true, returning');
      return;
    }

    _resumePromptShown = true;
    debugPrint('DEBUG: Setting _resumePromptShown to true, scheduling prompt');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint(
        'DEBUG: In post frame callback, scheduling resume prompt with delay',
      );
      // Add a small delay to ensure UI is fully rendered
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          debugPrint(
            'DEBUG: In delayed callback, calling _promptResumeIfNeeded',
          );
          _promptResumeIfNeeded();
        }
      });
    });
  }

  Future<void> _promptResumeIfNeeded() async {
    debugPrint('DEBUG: _promptResumeIfNeeded called');
    debugPrint('DEBUG: mounted=$mounted');
    debugPrint('DEBUG: _savedReadingUnits=$_savedReadingUnits');

    if (!mounted) {
      debugPrint('DEBUG: Not mounted, returning');
      return;
    }
    if (_savedReadingUnits == null) {
      debugPrint('DEBUG: _savedReadingUnits is null, returning');
      return;
    }

    final shouldResume = await _showResumeDialog();
    debugPrint('DEBUG: shouldResume=$shouldResume');

    if (!mounted) {
      debugPrint('DEBUG: Not mounted after dialog, returning');
      return;
    }

    if (shouldResume) {
      debugPrint('DEBUG: Jumping to saved offset ${_savedReadingUnits}');
      _jumpToSavedOffset(_savedReadingUnits!);
    } else {
      debugPrint('DEBUG: Starting from beginning');
      _persistReadingPosition(0);
    }

    _savedReadingUnits = null;
    debugPrint('DEBUG: _promptResumeIfNeeded completed');
  }

  Future<bool> _showResumeDialog() async {
    debugPrint('DEBUG: _showResumeDialog called');
    // Calculate scroll percentage if we have scroll controller info
    String resumeInfo = 'Continue where you left off?';
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final savedOffset = _savedReadingUnits! * _scrollUnitExtent;
      if (maxScroll > 0) {
        final percentage = (savedOffset / maxScroll * 100).clamp(0.0, 100.0);
        resumeInfo =
            'Continue from ${percentage.toStringAsFixed(1)}% of chapter?';
      }
    }

    debugPrint('DEBUG: Showing resume dialog with info: $resumeInfo');
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Resume reading?'),
            content: Text(resumeInfo),
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

  void _jumpToSavedOffset(int units) {
    final targetOffset = units * _scrollUnitExtent;
    if (!_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _jumpToSavedOffset(units),
      );
      return;
    }

    final maxOffset = _scrollController.position.maxScrollExtent;
    _scrollController.jumpTo(targetOffset.clamp(0.0, maxOffset));
  }

  Future<void> _persistReadingPosition(double offset) async {
    debugPrint('DEBUG: _persistReadingPosition called with offset: $offset');
    debugPrint(
      'DEBUG: resumeFromSavedPosition=${widget.resumeFromSavedPosition}',
    );

    if (!widget.resumeFromSavedPosition) return;
    final units = _scrollOffsetToUnits(offset);
    debugPrint('DEBUG: Converting offset $offset to units: $units');

    try {
      await _saveReadingPosition(
        SaveReadingPositionParams(
          itemId: widget.media.id,
          chapterId: _activeChapter.id,
          page: units,
        ),
      );
      debugPrint('DEBUG: Saved reading position successfully');

      // Also update watch history
      await _updateWatchHistory(units);
      debugPrint('DEBUG: Updated watch history successfully');
    } catch (e) {
      Logger.error(
        'Failed to save reading position',
        tag: 'NovelReaderScreen',
        error: e,
      );
    }
  }

  int _scrollOffsetToUnits(double offset) {
    return (offset / _scrollUnitExtent).round();
  }

  /// Update watch history with current reading progress
  Future<void> _updateWatchHistory(int readingUnits) async {
    debugPrint(
      'DEBUG: _updateWatchHistory called with readingUnits: $readingUnits',
    );
    debugPrint(
      'DEBUG: _watchHistoryController=${_watchHistoryController != null}',
    );

    if (_watchHistoryController == null) {
      debugPrint('DEBUG: WatchHistoryController is null, returning');
      return;
    }

    await _watchHistoryController!.updateReadingProgress(
      mediaId: widget.media.id,
      mediaType: widget.media.type,
      title: widget.media.title,
      coverImage: widget.media.coverImage,
      sourceId: widget.source?.id ?? _selectedSourceId ?? '',
      sourceName: widget.source?.name ?? 'Unknown Source',
      pageNumber: readingUnits,
      totalPages: null, // We don't know total pages for novel content
      chapterNumber: _activeChapter.number.toInt(),
      chapterId: _activeChapter.id,
      chapterTitle: _activeChapter.title,
      normalizedId: null, // MediaEntity doesn't have normalizedId yet
    );
    debugPrint('DEBUG: Watch history update completed');
  }

  void _increaseFontSize() {
    final currentIndex = _fontSizes.indexOf(_fontSize);
    if (currentIndex < _fontSizes.length - 1) {
      setState(() {
        _fontSize = _fontSizes[currentIndex + 1];
      });
    }
  }

  void _decreaseFontSize() {
    final currentIndex = _fontSizes.indexOf(_fontSize);
    if (currentIndex > 0) {
      setState(() {
        _fontSize = _fontSizes[currentIndex - 1];
      });
    }
  }

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  ChapterEntity? get _previousChapter {
    final chapters = _availableChapters;
    if (chapters == null) return null;
    final index = _ensureCurrentIndex();
    if (index != null && index > 0) {
      return chapters[index - 1];
    }
    return null;
  }

  ChapterEntity? get _nextChapter {
    final chapters = _availableChapters;
    if (chapters == null) return null;
    final index = _ensureCurrentIndex();
    if (index != null && index >= 0 && index < chapters.length - 1) {
      return chapters[index + 1];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _isDarkMode
        ? const Color(0xFF1A1A1A)
        : Colors.white;
    final controlsColor = _isDarkMode ? Colors.white : Colors.black;

    return Theme(
      data: _isDarkMode ? ThemeData.dark() : ThemeData.light(),
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: GestureDetector(
          onTap: _toggleControls,
          child: Stack(
            children: [
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: ErrorStateWidget(
                    message: 'Failed to load chapter',
                    description: _error,
                    onRetry: _loadChapterContent,
                  ),
                )
              else
                SingleChildScrollView(
                  controller: _scrollController,
                  padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: _showControls ? 100 : 48,
                    bottom: _showControls ? 120 : 48,
                  ),
                  child: NovelMarkdownRenderer(
                    content: _content ?? '',
                    isDarkMode: _isDarkMode,
                    fontSize: _fontSize,
                    lineHeight: _lineHeight,
                    fontFamily: _fontFamily,
                    onTap: _toggleControls,
                  ),
                ),

              // Top controls
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                top: _showControls ? 0 : -100,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [backgroundColor, backgroundColor.withOpacity(0)],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.arrow_back, color: controlsColor),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.media.title,
                                  style: TextStyle(
                                    color: controlsColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  _activeChapter.title,
                                  style: TextStyle(
                                    color: controlsColor.withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              _isDarkMode ? Icons.light_mode : Icons.dark_mode,
                              color: controlsColor,
                            ),
                            onPressed: _toggleTheme,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom controls
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                bottom: _showControls ? 0 : -120,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [backgroundColor, backgroundColor.withOpacity(0)],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Font size controls
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.text_decrease,
                                  color: controlsColor,
                                ),
                                onPressed: _decreaseFontSize,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: controlsColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${_fontSize.toInt()}',
                                  style: TextStyle(
                                    color: controlsColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.text_increase,
                                  color: controlsColor,
                                ),
                                onPressed: _increaseFontSize,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Chapter navigation
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              TextButton.icon(
                                onPressed:
                                    _previousChapter != null &&
                                        _chapterSupportsSelectedSource(
                                          _previousChapter!,
                                        )
                                    ? () => _goToChapter(_previousChapter!)
                                    : (_previousChapter != null
                                          ? _showSourceUnavailableMessage
                                          : null),
                                icon: Icon(
                                  Icons.chevron_left,
                                  color: _previousChapter != null
                                      ? controlsColor
                                      : controlsColor.withOpacity(0.3),
                                ),
                                label: Text(
                                  'Previous',
                                  style: TextStyle(
                                    color: _previousChapter != null
                                        ? controlsColor
                                        : controlsColor.withOpacity(0.3),
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed:
                                    _nextChapter != null &&
                                        _chapterSupportsSelectedSource(
                                          _nextChapter!,
                                        )
                                    ? () => _goToChapter(_nextChapter!)
                                    : (_nextChapter != null
                                          ? _showSourceUnavailableMessage
                                          : null),
                                icon: Icon(
                                  Icons.chevron_right,
                                  color: _nextChapter != null
                                      ? controlsColor
                                      : controlsColor.withOpacity(0.3),
                                ),
                                label: Text(
                                  'Next',
                                  style: TextStyle(
                                    color: _nextChapter != null
                                        ? controlsColor
                                        : controlsColor.withOpacity(0.3),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
