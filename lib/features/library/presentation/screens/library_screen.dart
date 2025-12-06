import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/domain/entities/entities.dart';
import '../../../../core/services/responsive_layout_manager.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../core/widgets/poster_card.dart';
import '../../../../core/widgets/app_settings_menu.dart';
import '../../../../core/navigation/navigation_controller.dart';
import '../../../../core/navigation/app_navigation.dart';
import '../../../details/presentation/screens/anime_manga_details_screen.dart';
import '../../../details/presentation/screens/tmdb_details_screen.dart';
import '../viewmodels/library_viewmodel.dart';

/// Screen for displaying user's library with filtering and swipe actions
/// Supports filtering by media type (All, Anime, Manga, Movie, TV, etc.)
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Media type tabs - null means "All"
  static const List<MediaType?> _mediaTypeTabs = [
    null, // All
    MediaType.anime,
    MediaType.manga,
    MediaType.novel,
    MediaType.movie,
    MediaType.tvShow,
    MediaType.cartoon,
    MediaType.documentary,
    MediaType.livestream,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _mediaTypeTabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);

    // Load library when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LibraryViewModel>().loadLibrary();
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      final selectedType = _mediaTypeTabs[_tabController.index];
      context.read<LibraryViewModel>().filterByMediaType(selectedType);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, screenType) {
        return Scaffold(
          body: Consumer<LibraryViewModel>(
            builder: (context, viewModel, child) {
              if (viewModel.isLoading && viewModel.libraryItems.isEmpty) {
                return _buildSkeletonScreen(context);
              }

              if (viewModel.error != null && viewModel.libraryItems.isEmpty) {
                return ErrorView(
                  message: viewModel.error!,
                  onRetry: () => viewModel.loadLibrary(),
                );
              }

              return NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  // App Bar with Tab Bar
                  SliverAppBar(
                    title: const Text('Library'),
                    floating: true,
                    pinned: true,
                    forceElevated: innerBoxIsScrolled,
                    actions: [
                      // Sort button
                      PopupMenuButton<LibrarySortOption>(
                        icon: const Icon(Icons.sort),
                        tooltip: 'Sort by',
                        onSelected: (option) => viewModel.sortBy(option),
                        itemBuilder: (context) =>
                            LibrarySortOption.values.map((option) {
                              return PopupMenuItem(
                                value: option,
                                child: Row(
                                  children: [
                                    if (viewModel.sortOption == option)
                                      const Icon(Icons.check, size: 20),
                                    if (viewModel.sortOption == option)
                                      const SizedBox(width: 8),
                                    Text(option.displayName),
                                  ],
                                ),
                              );
                            }).toList(),
                      ),

                      // Filter button for status
                      PopupMenuButton<LibraryStatus?>(
                        icon: Badge(
                          isLabelVisible: viewModel.filterStatus != null,
                          child: const Icon(Icons.filter_list),
                        ),
                        tooltip: 'Filter by status',
                        onSelected: (status) =>
                            viewModel.filterByStatus(status),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: null,
                            child: Row(
                              children: [
                                if (viewModel.filterStatus == null)
                                  const Icon(Icons.check, size: 20),
                                if (viewModel.filterStatus == null)
                                  const SizedBox(width: 8),
                                const Text('All Statuses'),
                              ],
                            ),
                          ),
                          ...LibraryStatus.values.map((status) {
                            return PopupMenuItem(
                              value: status,
                              child: Row(
                                children: [
                                  if (viewModel.filterStatus == status)
                                    const Icon(Icons.check, size: 20),
                                  if (viewModel.filterStatus == status)
                                    const SizedBox(width: 8),
                                  Text(_getStatusLabel(status)),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                      AppSettingsMenu(
                        onSettings: () {
                          NavigationController.of(
                            context,
                          ).navigateTo(AppDestination.settings);
                        },
                        onExtensions: () {
                          NavigationController.of(
                            context,
                          ).navigateTo(AppDestination.extensions);
                        },
                        onAccountLink: () {
                          NavigationController.of(
                            context,
                          ).navigateTo(AppDestination.settings);
                        },
                      ),
                    ],
                    bottom: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      tabs: _mediaTypeTabs.map((type) {
                        final count = type == null
                            ? viewModel.totalCount
                            : viewModel.getCountForType(type);
                        return Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (type != null) ...[
                                Icon(_getMediaTypeIcon(type), size: 18),
                                const SizedBox(width: 6),
                              ],
                              Text(type?.displayName ?? 'All'),
                              if (count > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    count.toString(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
                body: CustomScrollView(
                  slivers: [
                    // Quick Filter Chips
                    SliverToBoxAdapter(
                      child: Builder(
                        builder: (context) {
                          final padding = ResponsiveLayoutManager.getPadding(
                            MediaQuery.of(context).size.width,
                          );
                          return Padding(
                            padding: EdgeInsets.fromLTRB(
                              padding.left,
                              12,
                              padding.right,
                              8,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Active filters summary
                                if (viewModel.filterStatus != null ||
                                    viewModel.sortOption !=
                                        LibrarySortOption.dateAddedNewest)
                                  Row(
                                    children: [
                                      Text(
                                        'Active filters:',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (viewModel.filterStatus != null)
                                        Chip(
                                          label: Text(
                                            _getStatusLabel(
                                              viewModel.filterStatus!,
                                            ),
                                          ),
                                          onDeleted: () =>
                                              viewModel.filterByStatus(null),
                                          deleteIcon: const Icon(
                                            Icons.close,
                                            size: 16,
                                          ),
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      if (viewModel.filterStatus != null &&
                                          viewModel.sortOption !=
                                              LibrarySortOption.dateAddedNewest)
                                        const SizedBox(width: 8),
                                      if (viewModel.sortOption !=
                                          LibrarySortOption.dateAddedNewest)
                                        Chip(
                                          label: Text(
                                            viewModel.sortOption.displayName,
                                          ),
                                          onDeleted: () => viewModel.sortBy(
                                            LibrarySortOption.dateAddedNewest,
                                          ),
                                          deleteIcon: const Icon(
                                            Icons.close,
                                            size: 16,
                                          ),
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                    ],
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    // Error message if any
                    if (viewModel.error != null &&
                        viewModel.libraryItems.isNotEmpty)
                      SliverToBoxAdapter(
                        child: ErrorMessage(message: viewModel.error!),
                      ),

                    // Library Items by Category
                    if (viewModel.libraryItems.isNotEmpty)
                      ..._buildLibrarySections(context, viewModel),

                    // Empty state
                    if (viewModel.libraryItems.isEmpty && !viewModel.isLoading)
                      SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.library_books_outlined,
                                size: 64,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Your library is empty',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add content to start building your collection',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  IconData _getMediaTypeIcon(MediaType type) {
    switch (type) {
      case MediaType.anime:
        return Icons.play_circle_outline;
      case MediaType.manga:
        return Icons.menu_book;
      case MediaType.novel:
        return Icons.auto_stories;
      case MediaType.movie:
        return Icons.movie;
      case MediaType.tvShow:
        return Icons.tv;
      case MediaType.cartoon:
        return Icons.animation;
      case MediaType.documentary:
        return Icons.video_library;
      case MediaType.livestream:
        return Icons.live_tv;
      case MediaType.nsfw:
        return Icons.eighteen_up_rating;
    }
  }

  List<Widget> _buildLibrarySections(
    BuildContext context,
    LibraryViewModel viewModel,
  ) {
    final groupedItems = <LibraryStatus, List<LibraryItemEntity>>{};
    for (final item in viewModel.libraryItems) {
      groupedItems.putIfAbsent(item.status, () => []).add(item);
    }

    if (groupedItems.isEmpty) {
      return const [];
    }

    final padding = ResponsiveLayoutManager.getPadding(
      MediaQuery.of(context).size.width,
    );

    final slivers = <Widget>[];
    for (final status in groupedItems.keys) {
      final items = groupedItems[status]!;

      slivers.add(
        SliverPadding(
          padding: EdgeInsets.fromLTRB(padding.left, 24, padding.right, 12),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Text(
                  _getStatusLabel(status),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    items.length.toString(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      slivers.add(
        SliverToBoxAdapter(
          child: SizedBox(
            height: 280, // Fixed height for horizontal scrolling
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: padding.left),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return SizedBox(
                  height: 210,
                  width: 175, // Fixed width for each card
                  child: _buildLibraryItem(context, item, viewModel),
                );
              },
            ),
          ),
        ),
      );
    }

    return slivers;
  }

  Widget _buildLibraryItem(
    BuildContext context,
    LibraryItemEntity item,
    LibraryViewModel viewModel,
  ) {
    return PosterCard(
      media: item.media!,
      libraryStatus: item.status,
      showMoreOptionsIndicator: true,
      onTap: () => _navigateToMediaDetails(context, item.media!),
      onLongPress: () => _showLibraryItemActions(context, item, viewModel),
    );
  }

  void _showLibraryItemActions(
    BuildContext context,
    LibraryItemEntity item,
    LibraryViewModel viewModel,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('View Details'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _navigateToMediaDetails(context, item.media!);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Remove from Library',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showDeleteConfirmation(context, item, viewModel);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    LibraryItemEntity item,
    LibraryViewModel viewModel,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from Library'),
        content: Text(
          'Are you sure you want to remove "${item.media?.title ?? 'Unknown Media'}" from your library?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      viewModel.removeItem(item.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${item.media?.title ?? 'Unknown Media'} removed from library',
            ),
          ),
        );
      }
    }
  }

  void _navigateToMediaDetails(BuildContext context, MediaEntity media) {
    final sourceId = media.sourceId.toLowerCase();

    if (sourceId == 'tmdb') {
      final tmdbData = _buildTmdbSeedData(media);
      final isMovie = media.type == MediaType.movie;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              TmdbDetailsScreen(tmdbData: tmdbData, isMovie: isMovie),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AnimeMangaDetailsScreen(media: media)),
    );
  }

  Map<String, dynamic> _buildTmdbSeedData(MediaEntity media) {
    final id = int.tryParse(media.id);
    final date = media.startDate?.toIso8601String().split('T').first ?? '';

    return {
      'id': id ?? media.id,
      'title': media.title,
      'name': media.title,
      'poster_path': _extractTmdbRelativePath(media.coverImage),
      'backdrop_path': _extractTmdbRelativePath(media.bannerImage),
      'overview': media.description,
      'release_date': media.type == MediaType.movie ? date : null,
      'first_air_date': media.type == MediaType.tvShow ? date : null,
    };
  }

  String? _extractTmdbRelativePath(String? url) {
    if (url == null || url.isEmpty) return null;
    const base = 'https://image.tmdb.org/t/p/';
    final index = url.indexOf(base);
    if (index == -1) return null;
    final path = url.substring(index + base.length);
    final slashIndex = path.indexOf('/');
    if (slashIndex == -1) return '/$path';
    return path.substring(slashIndex).isEmpty
        ? null
        : path.substring(slashIndex);
  }

  String _getStatusLabel(LibraryStatus status) {
    switch (status) {
      case LibraryStatus.currentlyWatching:
        return "Currently Watching";
      case LibraryStatus.watching:
        return 'Watching';
      case LibraryStatus.completed:
        return 'Completed';
      case LibraryStatus.finished:
        return 'Finished';
      case LibraryStatus.onHold:
        return 'On Hold';
      case LibraryStatus.dropped:
        return 'Dropped';
      case LibraryStatus.planToWatch:
        return "Plan to Watch";
      case LibraryStatus.wantToWatch:
        return 'Want to Watch';
      case LibraryStatus.watched:
        return 'Watched';
    }
  }

  Widget _buildSkeletonScreen(BuildContext context) {
    final padding = ResponsiveLayoutManager.getPadding(
      MediaQuery.of(context).size.width,
    );

    return CustomScrollView(
      slivers: [
        // App Bar
        const SliverAppBar(title: Text('Library'), floating: true),
        // Skeleton horizontal list
        SliverPadding(
          padding: EdgeInsets.fromLTRB(padding.left, 24, padding.right, 12),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Text(
                  'Loading...',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '6',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 280,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: padding.left),
              itemCount: 6,
              itemBuilder: (context, index) {
                return Container(
                  width: 140,
                  margin: const EdgeInsets.only(right: 12),
                  child: const MediaSkeletonCard(),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
