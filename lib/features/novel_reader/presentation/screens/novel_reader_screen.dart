import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/domain/entities/chapter_entity.dart';
import '../../../../core/domain/entities/media_entity.dart';
import '../../../../core/domain/entities/source_entity.dart';
import '../../../../core/domain/usecases/get_novel_chapter_content_usecase.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/error_message_mapper.dart';
import '../../../../core/utils/logger.dart';
import '../../../../features/media_details/presentation/widgets/empty_state_widgets.dart';
import '../widgets/novel_markdown_renderer.dart';

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

  const NovelReaderScreen({
    super.key,
    required this.chapter,
    required this.media,
    this.allChapters,
    this.chapterContent,
    this.source,
  });

  @override
  State<NovelReaderScreen> createState() => _NovelReaderScreenState();
}

class _NovelReaderScreenState extends State<NovelReaderScreen> {
  final ScrollController _scrollController = ScrollController();
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
  late final GetNovelChapterContentUseCase _getChapterContent;

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
    _selectedSourceId =
        widget.source?.providerId ?? widget.chapter.sourceProvider;
    _currentChapter = widget.chapter.copyWith(
      sourceProvider: _selectedSourceId ?? widget.chapter.sourceProvider,
    );
    _currentChapterIndex = _findChapterIndex(widget.chapter);
    _loadChapterContent();
    // Hide system UI for immersive reading
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
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

  int? _ensureCurrentIndex() {
    final chapters = widget.allChapters;
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
    final chapters = widget.allChapters;
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
    final chapters = widget.allChapters;
    if (chapters == null) return null;
    final index = _ensureCurrentIndex();
    if (index != null && index > 0) {
      return chapters[index - 1];
    }
    return null;
  }

  ChapterEntity? get _nextChapter {
    final chapters = widget.allChapters;
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
