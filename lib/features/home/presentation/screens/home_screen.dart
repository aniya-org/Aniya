import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';

import '../../../../core/domain/entities/entities.dart';
import '../../../../core/domain/entities/episode_entity.dart';
import '../../../../core/navigation/app_navigation.dart';
import '../../../../core/navigation/navigation_controller.dart';
import '../../../../core/services/responsive_layout_manager.dart';
import '../../../../core/services/watch_history_controller.dart';
import '../../../../core/widgets/app_settings_menu.dart';
import '../../../../core/widgets/source_selector.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../details/presentation/screens/anime_manga_details_screen.dart';
import '../../../details/presentation/screens/tmdb_details_screen.dart';
import '../../../media_details/presentation/models/source_selection_result.dart';
import '../../../media_details/presentation/screens/episode_source_selection_sheet.dart';
import '../../../manga_reader/presentation/screens/manga_reader_screen.dart';
import '../../../novel_reader/presentation/screens/novel_reader_screen.dart';
import '../../../search/presentation/screens/search_screen.dart';
import '../../../search/presentation/viewmodels/search_viewmodel.dart';
import '../../../video_player/presentation/screens/video_player_screen.dart';
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
  WatchHistoryController? _watchHistoryController;
  static const Set<String> _supportedExternalSources = {
    'tmdb',
    'anilist',
    'simkl',
    'jikan',
    'kitsu',
    'mal',
    'myanimelist',
  };

  @override
  void initState() {
    super.initState();
    if (GetIt.instance.isRegistered<WatchHistoryController>()) {
      _watchHistoryController = GetIt.instance<WatchHistoryController>();
    }

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

  Future<void> _resumeHistoryEntry(WatchHistoryEntry entry) async {
    if (!entry.isVideoEntry && !entry.isReadingEntry) {
      await _navigateToMediaDetailsFromHistory(entry);
      return;
    }

    final media = _buildMediaFromEntry(entry);
    if (!mounted) return;

    final episode = _buildEpisodeFromEntry(entry);
    if (episode == null) {
      await _navigateToMediaDetailsFromHistory(entry);
      return;
    }

    final isChapter = entry.isReadingEntry;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return EpisodeSourceSelectionSheet(
          media: media,
          episode: episode,
          isChapter: isChapter,
          onSourceSelected: (selection) {
            _handleHistorySourceSelection(
              entry: entry,
              media: media,
              selection: selection,
            );
          },
        );
      },
    );
  }

  MediaEntity _buildMediaFromEntry(
    WatchHistoryEntry entry, {
    String? sourceOverride,
  }) {
    final normalizedOverride = sourceOverride;
    final normalizedSourceId = normalizedOverride ?? entry.sourceId;
    final normalizedSourceName = _displayNameForSource(
      normalizedOverride,
      entry.sourceName,
    );

    return MediaEntity(
      id: entry.mediaId,
      title: entry.title,
      coverImage: entry.coverImage,
      bannerImage: entry.coverImage,
      description: null,
      type: entry.mediaType,
      rating: null,
      genres: const [],
      status: MediaStatus.ongoing,
      totalEpisodes: entry.episodeNumber,
      totalChapters: entry.chapterNumber,
      startDate: null,
      sourceId: normalizedSourceId,
      sourceName: normalizedSourceName,
      sourceType: entry.mediaType,
    );
  }

  String _displayNameForSource(String? overrideId, String fallback) {
    if (overrideId == null) return fallback;
    switch (overrideId) {
      case 'tmdb':
        return 'TMDB';
      case 'anilist':
        return 'AniList';
      case 'jikan':
        return 'Jikan';
      case 'kitsu':
        return 'Kitsu';
      case 'simkl':
        return 'Simkl';
      case 'mal':
      case 'myanimelist':
        return 'MyAnimeList';
      default:
        return fallback;
    }
  }

  EpisodeEntity? _buildEpisodeFromEntry(WatchHistoryEntry entry) {
    if (entry.isVideoEntry) {
      return EpisodeEntity(
        id: entry.episodeId ?? '${entry.mediaId}_${entry.episodeNumber ?? 1}',
        mediaId: entry.mediaId,
        title: entry.episodeTitle ?? entry.title,
        number: entry.episodeNumber ?? 1,
        thumbnail: entry.coverImage,
        sourceProvider: entry.sourceId,
      );
    }

    if (entry.isReadingEntry) {
      final chapterId =
          entry.chapterId ?? '${entry.mediaId}_${entry.chapterNumber ?? 0}';
      return EpisodeEntity(
        id: chapterId,
        mediaId: entry.mediaId,
        title: entry.chapterTitle ?? entry.title,
        number: entry.chapterNumber ?? 0,
        thumbnail: entry.coverImage,
        sourceProvider: entry.sourceId,
      );
    }
    return null;
  }

  ChapterEntity _buildChapterFromEntry(WatchHistoryEntry entry) {
    return ChapterEntity(
      id: entry.chapterId ?? '${entry.mediaId}_${entry.chapterNumber ?? 0}',
      mediaId: entry.mediaId,
      title: entry.chapterTitle ?? entry.title,
      number: (entry.chapterNumber ?? 0).toDouble(),
      sourceProvider: entry.sourceId,
    );
  }

  void _handleHistorySourceSelection({
    required WatchHistoryEntry entry,
    required MediaEntity media,
    required SourceSelectionResult selection,
  }) {
    final source = selection.source;
    // Use the original episode ID from the history entry to ensure
    // we can match the saved playback position
    final episode = EpisodeEntity(
      id: entry.episodeId ?? '${entry.mediaId}_${entry.episodeNumber ?? 1}',
      mediaId: media.id,
      title: entry.episodeTitle ?? entry.title,
      number: entry.isReadingEntry
          ? entry.chapterNumber ?? 0
          : entry.episodeNumber ?? 1,
      thumbnail: media.coverImage,
      sourceProvider: source.providerId,
    );

    if (entry.isVideoEntry) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VideoPlayerScreen.fromSourceSelection(
            media: media,
            episode: episode,
            source: source,
            allSources: selection.allSources,
            resumeFromSavedPosition: true,
          ),
        ),
      );
      return;
    }

    final chapter = _buildChapterFromEntry(entry);
    if (media.type == MediaType.novel) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => NovelReaderScreen(
            chapter: chapter,
            media: media,
            source: source,
            sourceSelection: selection,
          ),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MangaReaderScreen(
            chapter: chapter,
            sourceId: source.providerId,
            itemId: media.id,
            media: media,
            source: source,
            resumeFromSavedPage: true,
          ),
        ),
      );
    }
  }

  void _showHistoryEntryActions(WatchHistoryEntry entry) {
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
                  _navigateToMediaDetailsFromHistory(entry);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remove from History'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _removeHistoryEntry(entry);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _removeHistoryEntry(WatchHistoryEntry entry) async {
    if (_watchHistoryController == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('History controller unavailable.')),
      );
      return;
    }

    await _watchHistoryController!.removeEntry(entry.id);
    if (!mounted) return;
    await context.read<HomeViewModel>().refresh();
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

  Future<void> _navigateToMediaDetailsFromHistory(
    WatchHistoryEntry entry,
  ) async {
    if (!mounted) return;

    if (_shouldShowTmdbDetails(entry)) {
      _openTmdbDetails(entry);
      return;
    }

    final overrideSourceId = _determineDetailsSourceOverride(entry);
    final media = _buildMediaFromEntry(entry, sourceOverride: overrideSourceId);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AnimeMangaDetailsScreen(
          media: media,
          initialSourceOverride: overrideSourceId,
        ),
      ),
    );
  }

  bool _shouldShowTmdbDetails(WatchHistoryEntry entry) {
    if (entry.sourceId.toLowerCase() == 'tmdb') return true;
    return entry.mediaType == MediaType.movie ||
        entry.mediaType == MediaType.tvShow;
  }

  void _openTmdbDetails(WatchHistoryEntry entry) {
    final tmdbId = int.tryParse(entry.mediaId);
    if (tmdbId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open TMDB details for this item.'),
        ),
      );
      return;
    }

    final isMovie = entry.mediaType != MediaType.tvShow;
    final tmdbData = <String, dynamic>{
      'id': tmdbId,
      'title': entry.title,
      'name': entry.title,
      'poster_path': entry.coverImage,
      'backdrop_path': entry.coverImage,
    };

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TmdbDetailsScreen(tmdbData: tmdbData, isMovie: isMovie),
      ),
    );
  }

  String? _determineDetailsSourceOverride(WatchHistoryEntry entry) {
    final normalized = entry.sourceId.toLowerCase();
    if (_supportedExternalSources.contains(normalized)) {
      if (normalized == 'mal' || normalized == 'myanimelist') {
        return 'jikan';
      }
      return normalized;
    }

    if (entry.mediaType == MediaType.anime) {
      return 'anilist';
    }

    if (entry.mediaType == MediaType.manga ||
        entry.mediaType == MediaType.novel) {
      return 'anilist';
    }

    return null;
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
        onTap: () => _resumeHistoryEntry(entry),
        onLongPress: () => _showHistoryEntryActions(entry),
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
