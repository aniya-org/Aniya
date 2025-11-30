import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/domain/entities/extension_entity.dart';
import '../../../../core/domain/entities/media_entity.dart';
import '../../../../core/domain/entities/episode_entity.dart';
import '../../../../core/domain/entities/source_entity.dart';
import '../../../../core/enums/episode_source_selection_step.dart';
import '../../../../core/utils/logger.dart';
import '../models/source_selection_result.dart';
import '../viewmodels/episode_source_selection_viewmodel.dart';
import '../widgets/extension_list_widget.dart';
import '../widgets/media_search_widget.dart';
import '../widgets/source_list_widget.dart';
import '../widgets/empty_state_widgets.dart';

/// Bottom sheet widget for episode/chapter source selection
///
/// Provides a multi-step workflow for users to:
/// 1. Select an extension
/// 2. Search for media within that extension
/// 3. Select a source to watch/read from
///
/// Requirements: 1.1, 1.2
class EpisodeSourceSelectionSheet extends StatefulWidget {
  /// The media item (anime, manga, movie, TV show)
  final MediaEntity media;

  /// The episode or chapter to select a source for
  final EpisodeEntity episode;

  /// Whether this is for a chapter (true) or episode (false)
  final bool isChapter;

  /// Callback when a source is selected and navigation should occur
  /// Receives the selection context with source, all sources, media, extension
  final Function(SourceSelectionResult result) onSourceSelected;

  const EpisodeSourceSelectionSheet({
    required this.media,
    required this.episode,
    required this.isChapter,
    required this.onSourceSelected,
    super.key,
  });

  @override
  State<EpisodeSourceSelectionSheet> createState() =>
      _EpisodeSourceSelectionSheetState();
}

class _EpisodeSourceSelectionSheetState
    extends State<EpisodeSourceSelectionSheet> {
  late EpisodeSourceSelectionViewModel _viewModel;
  EpisodeSourceSelectionStep _currentStep =
      EpisodeSourceSelectionStep.selectExtension;

  @override
  void initState() {
    super.initState();
    _initializeViewModel();
  }

  /// Initialize the ViewModel with media and episode data
  /// Requirements: 1.1, 1.2
  void _initializeViewModel() {
    _viewModel = sl<EpisodeSourceSelectionViewModel>();

    Logger.info(
      'Initializing EpisodeSourceSelectionSheet for ${widget.media.title}',
      tag: 'EpisodeSourceSelectionSheet',
    );

    _viewModel.initialize(
      media: widget.media,
      episode: widget.episode,
      isChapter: widget.isChapter,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ChangeNotifierProvider<EpisodeSourceSelectionViewModel>.value(
      value: _viewModel,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              children: [
                // Header with title and close button
                _buildHeader(context),

                // Step-based content
                Expanded(
                  child: Consumer<EpisodeSourceSelectionViewModel>(
                    builder: (context, viewModel, _) {
                      return _buildStepContent(context, viewModel);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Build the header with title and close button
  /// Requirements: 9.1, 9.2
  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Source',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.media.title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _handleDismissal(context),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  /// Build the content based on the current step
  /// Requirements: 1.1, 1.2, 3.1, 4.2
  Widget _buildStepContent(
    BuildContext context,
    EpisodeSourceSelectionViewModel viewModel,
  ) {
    // Show error state if there's an error
    if (viewModel.error != null &&
        _currentStep == EpisodeSourceSelectionStep.selectExtension) {
      return ErrorStateWidget(
        message: 'Failed to load extensions',
        description: viewModel.error,
        onRetry: () {
          _viewModel.clearError();
          _initializeViewModel();
        },
      );
    }

    switch (_currentStep) {
      case EpisodeSourceSelectionStep.selectExtension:
        return _buildExtensionSelectionStep(context, viewModel);

      case EpisodeSourceSelectionStep.searchMedia:
        return _buildMediaSearchStep(context, viewModel);

      case EpisodeSourceSelectionStep.selectSource:
        return _buildSourceSelectionStep(context, viewModel);
    }
  }

  /// Build the extension selection step
  /// Requirements: 1.3, 1.4, 8.2
  Widget _buildExtensionSelectionStep(
    BuildContext context,
    EpisodeSourceSelectionViewModel viewModel,
  ) {
    // Show no compatible extensions message
    if (!viewModel.hasCompatibleExtensions && !viewModel.isLoadingExtensions) {
      return const NoCompatibleExtensionsWidget();
    }

    return ExtensionListWidget(
      extensions: viewModel.compatibleExtensions,
      recentExtensions: viewModel.recentExtensions,
      isLoading: viewModel.isLoadingExtensions,
      onExtensionSelected: _handleExtensionSelection,
    );
  }

  /// Build the media search step
  /// Requirements: 3.1, 3.2, 3.3, 3.4
  Widget _buildMediaSearchStep(
    BuildContext context,
    EpisodeSourceSelectionViewModel viewModel,
  ) {
    final theme = Theme.of(context);

    // Show error state
    if (viewModel.error != null) {
      return ErrorStateWidget(
        message: 'Search failed',
        description: viewModel.error,
        onRetry: () {
          _viewModel.clearError();
          if (viewModel.searchQuery != null) {
            _viewModel.searchMedia(viewModel.searchQuery!);
          }
        },
      );
    }

    return Column(
      children: [
        // Back button and step indicator
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _currentStep = EpisodeSourceSelectionStep.selectExtension;
                  });
                },
                tooltip: 'Back',
              ),
              Expanded(
                child: Text(
                  'Search in ${viewModel.selectedExtension?.name ?? "Extension"}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),

        // Media search widget
        Expanded(
          child: MediaSearchWidget(
            extension: viewModel.selectedExtension!,
            results: viewModel.searchResults,
            isSearching: viewModel.isSearchingMedia,
            canLoadMore: viewModel.canLoadMoreResults,
            isLoadingMore: viewModel.isLoadingMoreResults,
            initialQuery: viewModel.searchQuery,
            onSearch: _handleMediaSearch,
            onLoadMore: _handleLoadMore,
            onMediaSelected: _handleMediaSelection,
          ),
        ),
      ],
    );
  }

  /// Build the source selection step
  /// Requirements: 4.2, 4.3, 4.4
  Widget _buildSourceSelectionStep(
    BuildContext context,
    EpisodeSourceSelectionViewModel viewModel,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        // Back button and step indicator
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _currentStep = EpisodeSourceSelectionStep.searchMedia;
                  });
                },
                tooltip: 'Back',
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Source',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      viewModel.selectedMedia?.title ?? 'Unknown',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Source list widget
        Expanded(
          child: SourceListWidget(
            sources: viewModel.availableSources,
            isLoading: viewModel.isLoadingSources,
            error: viewModel.error,
            onSourceSelected: _handleSourceSelection,
            onRetry: () {
              _viewModel.clearError();
              _viewModel.selectMedia(viewModel.selectedMedia!);
            },
          ),
        ),
      ],
    );
  }

  /// Handle extension selection
  /// Requirements: 2.1
  Future<void> _handleExtensionSelection(ExtensionEntity extension) async {
    Logger.info(
      'Extension selected: ${extension.name}',
      tag: 'EpisodeSourceSelectionSheet',
    );

    if (mounted) {
      setState(() {
        _currentStep = EpisodeSourceSelectionStep.searchMedia;
      });
    }

    await _viewModel.selectExtension(extension);
  }

  /// Handle media search
  /// Requirements: 3.2, 3.4
  Future<void> _handleMediaSearch(String query) async {
    Logger.info('Searching for: $query', tag: 'EpisodeSourceSelectionSheet');

    await _viewModel.searchMedia(query);
  }

  /// Handle loading more results
  /// Requirements: 3.4
  Future<void> _handleLoadMore() async {
    Logger.info('Loading more results', tag: 'EpisodeSourceSelectionSheet');

    await _viewModel.searchMedia(_viewModel.searchQuery ?? '', nextPage: true);
  }

  /// Handle media selection
  /// Requirements: 3.5, 4.1
  Future<void> _handleMediaSelection(MediaEntity media) async {
    Logger.info(
      'Media selected: ${media.title}',
      tag: 'EpisodeSourceSelectionSheet',
    );

    if (mounted) {
      setState(() {
        _currentStep = EpisodeSourceSelectionStep.selectSource;
      });
    }

    await _viewModel.selectMedia(media);
  }

  /// Handle source selection
  /// Requirements: 4.5, 5.1, 5.2
  Future<void> _handleSourceSelection(SourceEntity source) async {
    Logger.info(
      'Source selected: ${source.name}',
      tag: 'EpisodeSourceSelectionSheet',
    );

    await _viewModel.selectSource(source);

    if (mounted) {
      // Close the bottom sheet
      Navigator.of(context).pop();

      // Call the callback with the selected source and all available sources
      if (_viewModel.selectedMedia == null ||
          _viewModel.selectedExtension == null) {
        Logger.error(
          'Source selection missing media or extension context',
          tag: 'EpisodeSourceSelectionSheet',
        );
        return;
      }

      widget.onSourceSelected(
        SourceSelectionResult(
          source: source,
          allSources: _viewModel.availableSources,
          selectedMedia: _viewModel.selectedMedia!,
          selectedExtension: _viewModel.selectedExtension!,
        ),
      );
    }
  }

  /// Handle dismissal of the bottom sheet
  /// Requirements: 10.1, 10.2, 10.3, 10.4, 10.5
  void _handleDismissal(BuildContext context) {
    Logger.info(
      'Dismissing EpisodeSourceSelectionSheet',
      tag: 'EpisodeSourceSelectionSheet',
    );

    // Cancel ongoing operations
    _viewModel.clearError();

    // Close the bottom sheet
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    // Clean up resources
    super.dispose();
  }
}
