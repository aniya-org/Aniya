import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';

import '../../../../core/domain/entities/entities.dart';
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
import '../helpers/continue_watching_helper.dart';

import 'home_screen_tmdb_methods.dart';

/// Widget for displaying images with placeholder
Widget imageWithPlaceholder({
  required String imageUrl,
  required double width,
  required double height,
  BoxFit fit = BoxFit.cover,
}) {
  if (imageUrl.isEmpty) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[300],
      child: Icon(Icons.image, size: width * 0.3, color: Colors.grey[600]),
    );
  }

  return Image.network(
    imageUrl,
    width: width,
    height: height,
    fit: fit,
    errorBuilder: (context, error, stackTrace) {
      return Container(
        width: width,
        height: height,
        color: Colors.grey[300],
        child: Icon(
          Icons.image_not_supported,
          size: width * 0.3,
          color: Colors.grey[600],
        ),
      );
    },
    loadingBuilder: (context, child, loadingProgress) {
      if (loadingProgress == null) return child;
      return Container(
        width: width,
        height: height,
        color: Colors.grey[200],
        child: Center(
          child: CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                : null,
          ),
        ),
      );
    },
  );
}

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

                    // Unified Continue Watching/Reading Section
                    if (viewModel.continueWatchingAll.isNotEmpty) ...[
                      _buildSectionHeader(context, 'Continue Watching/Reading'),
                      _buildContinueWatchingAllSection(
                        context,
                        viewModel.continueWatchingAll,
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
                        viewModel.continueWatchingAll.isEmpty &&
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
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Remove from History',
                  style: TextStyle(color: Colors.red),
                ),
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

    try {
      await _watchHistoryController!.removeEntry(
        mediaId: entry.mediaId,
        mediaType: entry.mediaType,
        sourceId: entry.sourceId,
      );
      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Removed from history'),
          duration: Duration(seconds: 2),
        ),
      );

      // The WatchHistoryController already calls notifyListeners() in removeEntry
      // but we need to refresh the HomeViewModel since it has its own data
      await context.read<HomeViewModel>().refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove from history: $e')),
      );
    }
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

  Widget _buildContinueWatchingAllSection(
    BuildContext context,
    List<ContinueWatchingItem> items,
    ScreenType screenType,
  ) {
    final padding = ResponsiveLayoutManager.getPadding(
      MediaQuery.of(context).size.width,
    );
    final itemWidth = screenType == ScreenType.mobile ? 140.0 : 180.0;

    return SliverToBoxAdapter(
      child: SizedBox(
        height: screenType == ScreenType.mobile ? 240 : 280,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: padding.left),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return Container(
              width: itemWidth,
              margin: const EdgeInsets.only(right: 12),
              child: Tooltip(
                message: 'Tap to resume • Long press for options',
                child: InkWell(
                  onTap: () => _resumeHistoryEntry(item.historyEntry),
                  onLongPress: () =>
                      _showHistoryEntryActions(item.historyEntry),
                  borderRadius: BorderRadius.circular(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        // Cover image
                        Positioned.fill(
                          child: imageWithPlaceholder(
                            imageUrl: item.coverImage ?? '',
                            width: itemWidth,
                            height: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),

                        // Gradient overlay
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.7),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Media type badge
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              ContinueWatchingHelper.getMediaTypeLabel(
                                item.mediaType,
                                item.isVideo,
                                item.isReading,
                              ),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                        ),

                        // Library status badge (if available)
                        if (item.libraryStatus != null)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                ContinueWatchingHelper.getLibraryStatusLabel(
                                  item.libraryStatus,
                                )!,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSecondaryContainer,
                                      fontSize: 10,
                                    ),
                              ),
                            ),
                          ),

                        // More options indicator
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.more_vert,
                              size: 14,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ),

                        // Progress indicator (for video)
                        if (item.isVideo &&
                            item.progress != null &&
                            item.progress! > 0)
                          Positioned(
                            bottom: 60,
                            left: 8,
                            right: 8,
                            child: LinearProgressIndicator(
                              value: item.progress! / 100,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.3,
                              ),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),

                        // Title and info
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  ContinueWatchingHelper.getProgressText(item),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Colors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
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
