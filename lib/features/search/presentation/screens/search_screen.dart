import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/domain/entities/entities.dart';
import '../../../../core/services/responsive_layout_manager.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../core/widgets/source_selector.dart';
import '../../../../core/widgets/app_settings_menu.dart';
import '../../../../core/navigation/navigation_controller.dart';
import '../../../../core/navigation/app_navigation.dart';
import '../viewmodels/search_viewmodel.dart';

/// Screen for searching media across all extensions
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _selectedSource = 'all';

  @override
  void initState() {
    super.initState();
    // Auto-focus search field when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, screenType) {
        return Scaffold(
          body: Consumer<SearchViewModel>(
            builder: (context, viewModel, child) {
              final padding = ResponsiveLayoutManager.getPadding(
                MediaQuery.of(context).size.width,
              );
              final columnCount = ResponsiveLayoutManager.getGridColumns(
                MediaQuery.of(context).size.width,
              );

              return CustomScrollView(
                slivers: [
                  // Search App Bar
                  SliverAppBar(
                    floating: true,
                    pinned: true,
                    title: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      decoration: InputDecoration(
                        hintText: 'Search anime, manga, movies...',
                        border: InputBorder.none,
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  viewModel.clearResults();
                                },
                              )
                            : null,
                      ),
                      onChanged: (query) {
                        viewModel.search(query);
                      },
                      textInputAction: TextInputAction.search,
                    ),
                    actions: [
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

                  // Source Selector
                  SliverToBoxAdapter(
                    child: SourceSelector(
                      currentSource: _selectedSource,
                      sources: [
                        SourceOption(
                          id: 'all',
                          name: 'All Sources',
                          icon: const Icon(Icons.search, size: 16),
                        ),
                        SourceOption(
                          id: 'tmdb',
                          name: 'TMDB',
                          icon: const Icon(Icons.movie, size: 16),
                        ),
                        SourceOption(
                          id: 'anilist',
                          name: 'AniList',
                          icon: const Icon(Icons.list, size: 16),
                        ),
                        SourceOption(
                          id: 'jikan',
                          name: 'MyAnimeList',
                          icon: const Icon(Icons.list, size: 16),
                        ),
                        SourceOption(
                          id: 'kitsu',
                          name: 'Kitsu',
                          icon: const Icon(Icons.list, size: 16),
                        ),
                        SourceOption(
                          id: 'simkl',
                          name: 'Simkl',
                          icon: const Icon(Icons.list, size: 16),
                        ),
                      ],
                      onSourceChanged: (source) {
                        setState(() {
                          _selectedSource = source;
                          // Update the viewmodel's source filter
                          final viewModel = Provider.of<SearchViewModel>(
                            context,
                            listen: false,
                          );
                          viewModel.setSourceFilter(
                            source == 'all' ? null : source,
                          );
                        });
                      },
                    ),
                  ),

                  // Type Filter Chips
                  SliverToBoxAdapter(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(
                        horizontal: padding.left,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          FilterChip(
                            label: const Text('All'),
                            selected: viewModel.typeFilter == null,
                            onSelected: (selected) {
                              viewModel.setTypeFilter(null);
                            },
                          ),
                          const SizedBox(width: 8),
                          ...MediaType.values.map((type) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(_getTypeLabel(type)),
                                selected: viewModel.typeFilter == type,
                                onSelected: (selected) {
                                  viewModel.setTypeFilter(
                                    selected ? type : null,
                                  );
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),

                  // Loading State
                  if (viewModel.isLoading)
                    SliverPadding(
                      padding: EdgeInsets.all(padding.left),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columnCount,
                          childAspectRatio: 0.7,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => const MediaSkeletonCard(),
                          childCount: 6,
                        ),
                      ),
                    ),

                  // Error State
                  if (viewModel.error != null &&
                      viewModel.searchResults.isEmpty)
                    SliverFillRemaining(
                      child: ErrorView(
                        message: viewModel.error!,
                        onRetry: () => viewModel.search(viewModel.query),
                      ),
                    ),

                  // Search Results
                  if (!viewModel.isLoading &&
                      viewModel.searchResults.isNotEmpty)
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
                          final media = viewModel.searchResults[index];
                          return MediaCard(
                            media: media,
                            onTap: () =>
                                _navigateToMediaDetails(context, media),
                          );
                        }, childCount: viewModel.searchResults.length),
                      ),
                    ),

                  // Empty State - No Query
                  if (viewModel.query.isEmpty && !viewModel.isLoading)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search,
                              size: 64,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Search for content',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Find anime, manga, movies, and TV shows',
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

                  // Empty State - No Results
                  if (viewModel.query.isNotEmpty &&
                      viewModel.searchResults.isEmpty &&
                      !viewModel.isLoading &&
                      viewModel.error == null)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No results found',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try a different search term',
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

  String _getTypeLabel(MediaType type) {
    switch (type) {
      case MediaType.anime:
        return 'Anime';
      case MediaType.manga:
        return 'Manga';
      case MediaType.novel:
        return 'Novels';
      case MediaType.movie:
        return 'Movies';
      case MediaType.tvShow:
        return 'TV Shows';
    }
  }

  void _navigateToMediaDetails(BuildContext context, MediaEntity media) {
    Navigator.pushNamed(context, '/media-details', arguments: media);
  }
}
