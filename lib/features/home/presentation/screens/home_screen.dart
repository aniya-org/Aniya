import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/domain/entities/entities.dart';
import '../../../../core/services/responsive_layout_manager.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../core/widgets/source_selector.dart';
import '../../../../core/widgets/app_settings_menu.dart';
import 'package:get_it/get_it.dart';
import '../../../search/presentation/screens/search_screen.dart';
import '../../../search/presentation/viewmodels/search_viewmodel.dart';
import '../../../../core/navigation/navigation_controller.dart';
import '../../../../core/navigation/app_navigation.dart';
import '../viewmodels/home_viewmodel.dart';

import 'home_screen_tmdb_methods.dart';

/// Home screen displaying trending content and continue watching
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with HomeScreenTmdbMethods {
  String _selectedSource = 'tmdb';

  @override
  void initState() {
    super.initState();
    // Load home data when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeViewModel>().loadHomeData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, screenType) {
        return Scaffold(
          body: Consumer<HomeViewModel>(
            builder: (context, viewModel, child) {
              if (viewModel.isLoading && viewModel.trendingAnime.isEmpty) {
                return _buildSkeletonScreen(context, screenType);
              }

              if (viewModel.error != null && viewModel.trendingAnime.isEmpty) {
                return ErrorView(
                  message: viewModel.error!,
                  onRetry: () => viewModel.loadHomeData(),
                );
              }

              return RefreshIndicator(
                onRefresh: () => viewModel.refresh(),
                child: CustomScrollView(
                  slivers: [
                    // App Bar
                    SliverAppBar(
                      title: const Text('Aniya'),
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
                            // Navigate to settings where account linking is handled
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
                            id: 'tmdb',
                            name: 'TMDB',
                            icon: const Icon(Icons.movie, size: 16),
                          ),
                        ],
                        onSourceChanged: (source) {
                          setState(() => _selectedSource = source);
                        },
                      ),
                    ),

                    // Error message if any (but content is still shown)
                    if (viewModel.error != null)
                      SliverToBoxAdapter(
                        child: ErrorMessage(
                          message: viewModel.error!,
                          onDismiss: () {
                            // Clear error would need to be added to viewmodel
                          },
                        ),
                      ),

                    // Continue Watching Section
                    if (viewModel.continueWatching.isNotEmpty) ...[
                      _buildSectionHeader(context, 'Continue Watching'),
                      _buildContinueWatchingSection(
                        context,
                        viewModel,
                        screenType,
                      ),
                    ],

                    // Trending Anime Section
                    if (viewModel.trendingAnime.isNotEmpty) ...[
                      _buildSectionHeader(context, 'Trending Anime'),
                      _buildMediaGrid(
                        context,
                        viewModel.trendingAnime,
                        screenType,
                      ),
                    ],

                    // Trending Manga Section
                    if (viewModel.trendingManga.isNotEmpty) ...[
                      _buildSectionHeader(context, 'Trending Manga'),
                      _buildMediaGrid(
                        context,
                        viewModel.trendingManga,
                        screenType,
                      ),
                    ],

                    // Trending Movies Section (TMDB)
                    if (viewModel.trendingMovies.isNotEmpty) ...[
                      _buildSectionHeader(context, 'Trending Movies'),
                      buildTmdbHorizontalList(
                        context,
                        viewModel.trendingMovies,
                        screenType,
                        isMovie: true,
                      ),
                    ],

                    // Trending TV Shows Section (TMDB)
                    if (viewModel.trendingTVShows.isNotEmpty) ...[
                      _buildSectionHeader(context, 'Trending TV Shows'),
                      buildTmdbHorizontalList(
                        context,
                        viewModel.trendingTVShows,
                        screenType,
                        isMovie: false,
                      ),
                    ],

                    // Popular Movies Section (TMDB)
                    if (viewModel.popularMovies.isNotEmpty) ...[
                      _buildSectionHeader(context, 'Popular Movies'),
                      buildTmdbHorizontalList(
                        context,
                        viewModel.popularMovies,
                        screenType,
                        isMovie: true,
                      ),
                    ],

                    // Popular TV Shows Section (TMDB)
                    if (viewModel.popularTVShows.isNotEmpty) ...[
                      _buildSectionHeader(context, 'Popular TV Shows'),
                      buildTmdbHorizontalList(
                        context,
                        viewModel.popularTVShows,
                        screenType,
                        isMovie: false,
                      ),
                    ],

                    // Empty state
                    if (viewModel.trendingAnime.isEmpty &&
                        viewModel.trendingManga.isEmpty &&
                        viewModel.continueWatching.isEmpty &&
                        viewModel.trendingMovies.isEmpty &&
                        viewModel.trendingTVShows.isEmpty &&
                        viewModel.popularMovies.isEmpty &&
                        viewModel.popularTVShows.isEmpty &&
                        !viewModel.isLoading)
                      SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.explore_outlined,
                                size: 64,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No content available',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Install extensions to start browsing',
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

                    // Bottom padding
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final padding = ResponsiveLayoutManager.getPadding(
      MediaQuery.of(context).size.width,
    );

    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(padding.left, 24, padding.right, 12),
        child: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildContinueWatchingSection(
    BuildContext context,
    HomeViewModel viewModel,
    ScreenType screenType,
  ) {
    final padding = ResponsiveLayoutManager.getPadding(
      MediaQuery.of(context).size.width,
    );
    final itemWidth = screenType == ScreenType.mobile ? 140.0 : 180.0;

    // Filter out items where media is null
    final validItems = viewModel.continueWatching
        .where((item) => item.media != null)
        .toList();

    return SliverToBoxAdapter(
      child: SizedBox(
        height: screenType == ScreenType.mobile ? 200 : 240,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: padding.left),
          itemCount: validItems.length,
          itemBuilder: (context, index) {
            final item = validItems[index];
            return Container(
              width: itemWidth,
              margin: const EdgeInsets.only(right: 12),
              child: MediaCard(
                media: item.media!,
                onTap: () => _navigateToMediaDetails(context, item.media!),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMediaGrid(
    BuildContext context,
    List<MediaEntity> mediaList,
    ScreenType screenType,
  ) {
    final padding = ResponsiveLayoutManager.getPadding(
      MediaQuery.of(context).size.width,
    );
    final columnCount = ResponsiveLayoutManager.getGridColumns(
      MediaQuery.of(context).size.width,
    );

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: padding.left),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columnCount,
          childAspectRatio: 0.7,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: 300,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final media = mediaList[index];
          return MediaCard(
            media: media,
            onTap: () => _navigateToMediaDetails(context, media),
          );
        }, childCount: mediaList.length),
      ),
    );
  }

  void _navigateToMediaDetails(BuildContext context, MediaEntity media) {
    // Navigation will be implemented when MediaDetailsScreen is created
    Navigator.pushNamed(context, '/media-details', arguments: media);
  }

  Widget _buildSkeletonScreen(BuildContext context, ScreenType screenType) {
    final columnCount = ResponsiveLayoutManager.getGridColumns(
      MediaQuery.of(context).size.width,
    );

    return CustomScrollView(
      slivers: [
        // App Bar
        SliverAppBar.large(title: const Text('Aniya'), floating: true),
        // Skeleton grid
        SliverPadding(
          padding: const EdgeInsets.all(16),
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
      ],
    );
  }
}
