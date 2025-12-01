import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/domain/entities/entities.dart';
import '../../../../core/domain/usecases/get_media_details_usecase.dart';
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

                    // Continue Watching Section (from library)
                    if (viewModel.continueWatching.isNotEmpty) ...[
                      _buildSectionHeader(context, 'Continue Watching'),
                      _buildContinueWatchingSection(
                        context,
                        viewModel,
                        screenType,
                      ),
                    ],

                    // Continue Watching Section (from watch history)
                    if (viewModel.continueWatchingHistory.isNotEmpty) ...[
                      _buildSectionHeader(context, 'Recently Watched'),
                      _buildWatchHistorySection(
                        context,
                        viewModel.continueWatchingHistory,
                        screenType,
                      ),
                    ],

                    // Continue Reading Section (from watch history)
                    if (viewModel.continueReadingHistory.isNotEmpty) ...[
                      _buildSectionHeader(context, 'Continue Reading'),
                      _buildWatchHistorySection(
                        context,
                        viewModel.continueReadingHistory,
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

  void _navigateToMediaDetailsFromHistory(WatchHistoryEntry entry) async {
    try {
      // Fetch media details using the mediaId and sourceId from the entry
      final result = await GetIt.instance<GetMediaDetailsUseCase>()(
        GetMediaDetailsParams(id: entry.mediaId, sourceId: entry.sourceId),
      );

      result.fold(
        (failure) {
          // If fetching fails, show error snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unable to load media details: ${failure.message}'),
            ),
          );
        },
        (mediaEntity) {
          // Navigate to media details screen
          Navigator.pushNamed(
            context,
            '/media-details',
            arguments: mediaEntity,
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading media: $e')));
    }
  }

  Widget _buildWatchHistorySection(
    BuildContext context,
    List<WatchHistoryEntry> entries,
    ScreenType screenType,
  ) {
    final padding = ResponsiveLayoutManager.getPadding(
      MediaQuery.of(context).size.width,
    );
    final itemWidth = screenType == ScreenType.mobile ? 140.0 : 180.0;

    return SliverToBoxAdapter(
      child: SizedBox(
        height: screenType == ScreenType.mobile ? 220 : 260,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: padding.left),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            return Container(
              width: itemWidth,
              margin: const EdgeInsets.only(right: 12),
              child: _buildWatchHistoryCard(context, entry),
            );
          },
        ),
      ),
    );
  }

  Widget _buildWatchHistoryCard(BuildContext context, WatchHistoryEntry entry) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          // Navigate to media details screen
          _navigateToMediaDetailsFromHistory(entry);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image with progress overlay
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Cover image
                  if (entry.coverImage != null)
                    Image.network(
                      entry.coverImage!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: colorScheme.surfaceContainerHighest,
                        child: Icon(
                          entry.isVideoEntry ? Icons.movie : Icons.menu_book,
                          size: 48,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    Container(
                      color: colorScheme.surfaceContainerHighest,
                      child: Icon(
                        entry.isVideoEntry ? Icons.movie : Icons.menu_book,
                        size: 48,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),

                  // Progress bar at bottom
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: LinearProgressIndicator(
                      value: entry.progressPercentage,
                      backgroundColor: Colors.black54,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.primary,
                      ),
                      minHeight: 4,
                    ),
                  ),

                  // Resume button overlay
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            entry.isVideoEntry
                                ? Icons.play_arrow
                                : Icons.menu_book,
                            size: 14,
                            color: colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Resume',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Title and progress info
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.progressDisplayString,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
