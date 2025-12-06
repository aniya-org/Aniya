import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/domain/entities/entities.dart';
import '../../../../core/services/responsive_layout_manager.dart';
import 'package:get_it/get_it.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../core/widgets/poster_card.dart';
import '../../../../core/widgets/source_selector.dart';
import '../../../../core/widgets/app_settings_menu.dart';
import '../../../search/presentation/screens/search_screen.dart';
import '../../../search/presentation/viewmodels/search_viewmodel.dart';
import '../../../../core/navigation/navigation_controller.dart';
import '../../../../core/navigation/app_navigation.dart';
import '../../../details/presentation/screens/anime_manga_details_screen.dart';
import '../viewmodels/browse_viewmodel.dart';

/// Screen for browsing novel/light novel content from extensions
class NovelScreen extends StatefulWidget {
  const NovelScreen({super.key});

  @override
  State<NovelScreen> createState() => _NovelScreenState();
}

class _NovelScreenState extends State<NovelScreen> {
  final ScrollController _scrollController = ScrollController();
  String _selectedSource = 'anilist';

  @override
  void initState() {
    super.initState();
    // Load novel content when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = context.read<BrowseViewModel>();
      viewModel.setMediaTypeAndSource(
        type: MediaType.novel,
        sourceId: 'anilist',
        force: true,
      );
      viewModel.loadMedia();
    });

    // Setup infinite scroll
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      // Load more when 80% scrolled
      context.read<BrowseViewModel>().loadMedia(loadMore: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, screenType) {
        return Scaffold(
          body: Consumer<BrowseViewModel>(
            builder: (context, viewModel, child) {
              final padding = ResponsiveLayoutManager.getPadding(
                MediaQuery.of(context).size.width,
              );
              final columnCount = ResponsiveLayoutManager.getGridColumns(
                MediaQuery.of(context).size.width,
              );

              if (viewModel.isLoading && viewModel.mediaList.isEmpty) {
                // Show skeleton grid while loading
                return CustomScrollView(
                  slivers: [
                    // App Bar
                    SliverAppBar(title: const Text('Novels'), floating: true),
                    // Skeleton Grid
                    SliverPadding(
                      padding: EdgeInsets.all(padding.left),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columnCount,
                          childAspectRatio: 0.7,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          mainAxisExtent: 300,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => const MediaSkeletonCard(),
                          childCount: 12, // Show 12 skeleton cards
                        ),
                      ),
                    ),
                  ],
                );
              }

              if (viewModel.error != null && viewModel.mediaList.isEmpty) {
                return ErrorView(
                  message: viewModel.error!,
                  onRetry: () => viewModel.loadMedia(),
                );
              }

              return CustomScrollView(
                controller: _scrollController,
                slivers: [
                  // App Bar with filters
                  SliverAppBar(
                    title: const Text('Novels'),
                    floating: true,
                    actions: [
                      // Search button
                      IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ChangeNotifierProvider.value(
                                    value: GetIt.instance<SearchViewModel>(),
                                    child: const SearchScreen(),
                                  ),
                            ),
                          );
                        },
                      ),
                      // Sort button
                      PopupMenuButton<SortOption>(
                        icon: const Icon(Icons.sort),
                        onSelected: (option) => viewModel.setSortOption(option),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: SortOption.popularity,
                            child: Row(
                              children: [
                                if (viewModel.sortOption ==
                                    SortOption.popularity)
                                  const Icon(Icons.check, size: 20),
                                if (viewModel.sortOption ==
                                    SortOption.popularity)
                                  const SizedBox(width: 8),
                                const Text('Popularity'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: SortOption.rating,
                            child: Row(
                              children: [
                                if (viewModel.sortOption == SortOption.rating)
                                  const Icon(Icons.check, size: 20),
                                if (viewModel.sortOption == SortOption.rating)
                                  const SizedBox(width: 8),
                                const Text('Rating'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      // Filter button
                      IconButton(
                        icon: Badge(
                          isLabelVisible:
                              viewModel.genreFilters.isNotEmpty ||
                              viewModel.statusFilter != null,
                          child: const Icon(Icons.filter_list),
                        ),
                        onPressed: () => _showFilterDialog(context, viewModel),
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
                  ),

                  // Source Selector - Only AniList supports novels properly
                  SliverToBoxAdapter(
                    child: SourceSelector(
                      currentSource: _selectedSource,
                      sources: [
                        SourceOption(
                          id: 'anilist',
                          name: 'AniList',
                          icon: const Icon(Icons.explore, size: 16),
                        ),
                      ],
                      onSourceChanged: (source) {
                        setState(() => _selectedSource = source);
                        context.read<BrowseViewModel>().setSourceId(source);
                      },
                    ),
                  ),

                  // Error message if any (but content is still shown)
                  if (viewModel.error != null && viewModel.mediaList.isNotEmpty)
                    SliverToBoxAdapter(
                      child: ErrorMessage(message: viewModel.error!),
                    ),

                  // Media Grid
                  if (viewModel.mediaList.isNotEmpty)
                    SliverPadding(
                      padding: EdgeInsets.all(padding.left),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columnCount,
                          childAspectRatio: 0.7,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          mainAxisExtent: 300,
                        ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final media = viewModel.mediaList[index];
                          return PosterCard(
                            media: media,
                            onTap: () =>
                                _navigateToMediaDetails(context, media),
                          );
                        }, childCount: viewModel.mediaList.length),
                      ),
                    ),

                  // Loading indicator for pagination
                  if (viewModel.isLoading && viewModel.mediaList.isNotEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),

                  // Empty state
                  if (viewModel.mediaList.isEmpty && !viewModel.isLoading)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.auto_stories_outlined,
                              size: 64,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No novels found',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try adjusting your filters or source',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _showFilterDialog(BuildContext context, BrowseViewModel viewModel) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _FilterBottomSheet(viewModel: viewModel),
    );
  }

  void _navigateToMediaDetails(BuildContext context, MediaEntity media) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnimeMangaDetailsScreen(media: media),
      ),
    );
  }
}

class _FilterBottomSheet extends StatefulWidget {
  final BrowseViewModel viewModel;

  const _FilterBottomSheet({required this.viewModel});

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late MediaStatus? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.viewModel.statusFilter;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filters',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Status Filter
          Text('Status', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('All'),
                selected: _selectedStatus == null,
                onSelected: (selected) {
                  setState(() => _selectedStatus = null);
                },
              ),
              ...MediaStatus.values.map((status) {
                return FilterChip(
                  label: Text(_getStatusLabel(status)),
                  selected: _selectedStatus == status,
                  onSelected: (selected) {
                    setState(() => _selectedStatus = selected ? status : null);
                  },
                );
              }),
            ],
          ),

          const SizedBox(height: 24),

          // Apply button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                widget.viewModel.setStatusFilter(_selectedStatus);
                Navigator.pop(context);
              },
              child: const Text('Apply Filters'),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusLabel(MediaStatus status) {
    switch (status) {
      case MediaStatus.ongoing:
        return 'Ongoing';
      case MediaStatus.completed:
        return 'Completed';
      case MediaStatus.upcoming:
        return 'Upcoming';
    }
  }
}
