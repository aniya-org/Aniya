import 'package:flutter/material.dart';
import 'package:aniya/core/domain/entities/extension_entity.dart';
import 'package:aniya/core/domain/entities/media_entity.dart';

/// Widget for searching media within an extension with pagination support
///
/// Displays a search input field, paginated search results, and handles
/// loading states. Shows "No results" message when search returns empty.
///
/// Requirements: 3.1, 3.3, 3.4, 2.4
class MediaSearchWidget extends StatefulWidget {
  /// The currently selected extension
  final ExtensionEntity extension;

  /// List of search results
  final List<MediaEntity> results;

  /// Whether a search is currently in progress
  final bool isSearching;

  /// Whether more results can be loaded
  final bool canLoadMore;

  /// Whether more results are being loaded
  final bool isLoadingMore;

  /// Callback when search is submitted
  final Function(String) onSearch;

  /// Callback to load more results
  final Function() onLoadMore;

  /// Callback when a media item is selected
  final Function(MediaEntity) onMediaSelected;

  /// Initial search query (optional)
  final String? initialQuery;

  const MediaSearchWidget({
    required this.extension,
    required this.results,
    required this.isSearching,
    required this.canLoadMore,
    required this.isLoadingMore,
    required this.onSearch,
    required this.onLoadMore,
    required this.onMediaSelected,
    this.initialQuery,
    super.key,
  });

  @override
  State<MediaSearchWidget> createState() => _MediaSearchWidgetState();
}

class _MediaSearchWidgetState extends State<MediaSearchWidget> {
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery ?? '');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search input field
        Padding(
          padding: const EdgeInsets.all(16),
          child: SearchBar(
            controller: _searchController,
            hintText: 'Search in ${widget.extension.name}',
            leading: const Icon(Icons.search),
            trailing: [
              if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                ),
            ],
            onSubmitted: (query) {
              if (query.trim().isNotEmpty) {
                widget.onSearch(query);
              }
            },
            onChanged: (query) {
              setState(() {});
            },
          ),
        ),

        // Search results or empty state
        Expanded(child: _buildResultsView()),
      ],
    );
  }

  /// Build the results view based on current state
  Widget _buildResultsView() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Show loading state
    if (widget.isSearching && widget.results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Searching...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    // Show empty state if no results
    if (widget.results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Searching...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    // Show empty state if no results
    if (widget.results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search query',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Show results list with pagination
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: widget.results.length + (widget.canLoadMore ? 1 : 0),
      itemBuilder: (context, index) {
        // Load more button at the end
        if (index == widget.results.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: widget.isLoadingMore
                  ? CircularProgressIndicator(color: colorScheme.primary)
                  : FilledButton.tonal(
                      onPressed: widget.onLoadMore,
                      child: const Text('Load More'),
                    ),
            ),
          );
        }

        final media = widget.results[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildMediaResultCard(context, media),
        );
      },
    );
  }

  /// Build a media result card
  Widget _buildMediaResultCard(BuildContext context, MediaEntity media) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => widget.onMediaSelected(media),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Cover image
              Container(
                width: 80,
                height: 120,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: media.coverImage != null
                    ? Image.network(
                        media.coverImage!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Icon(
                              Icons.image_not_supported,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          );
                        },
                      )
                    : Center(
                        child: Icon(
                          Icons.image,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
              ),

              const SizedBox(width: 12),

              // Media info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      media.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getMediaTypeLabel(media.type),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (media.rating != null)
                          Row(
                            children: [
                              Icon(
                                Icons.star,
                                size: 14,
                                color: colorScheme.tertiary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                media.rating!.toStringAsFixed(1),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    if (media.genres.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        media.genres.take(2).join(', '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Selection indicator
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  /// Get display label for media type
  String _getMediaTypeLabel(MediaType type) {
    switch (type) {
      case MediaType.anime:
        return 'Anime';
      case MediaType.manga:
        return 'Manga';
      case MediaType.novel:
        return 'Novel';
      case MediaType.movie:
        return 'Movie';
      case MediaType.tvShow:
        return 'TV Show';
    }
  }
}
