import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/domain/entities/entities.dart';
import '../../../../core/services/responsive_layout_manager.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../core/widgets/source_selector.dart';
import '../../../../core/widgets/app_settings_menu.dart';
import '../../../../core/navigation/navigation_controller.dart';
import '../../../../core/navigation/app_navigation.dart';
import '../../../../core/data/datasources/external_remote_data_source.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/logger.dart';
import '../../../details/presentation/screens/tmdb_details_screen.dart';
import '../../../details/presentation/screens/anime_manga_details_screen.dart';
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
                      onSubmitted: (query) {
                        final trimmed = query.trim();
                        if (trimmed.isEmpty) {
                          viewModel.clearResults();
                          return;
                        }
                        viewModel.search(trimmed);
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
                      currentSource: viewModel.sourceFilter ?? 'all',
                      sources: _buildSourceOptions(),
                      onSourceChanged: (source) {
                        context.read<SearchViewModel>().setSourceFilter(
                          source == 'all' ? null : source,
                        );
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
                  // if (viewModel.isLoading)
                  //   SliverPadding(
                  //     padding: EdgeInsets.all(padding.left),
                  //     sliver: SliverGrid(
                  //       gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  //         crossAxisCount: columnCount,
                  //         childAspectRatio: 0.7,
                  //         crossAxisSpacing: 12,
                  //         mainAxisSpacing: 12,
                  //       ),
                  //       delegate: SliverChildBuilderDelegate(
                  //         (context, index) => const MediaSkeletonCard(),
                  //         childCount: 6,
                  //       ),
                  //     ),
                  //   ),

                  // Error State
                  if (viewModel.error != null &&
                      viewModel.searchResults.isEmpty)
                    SliverFillRemaining(
                      child: ErrorView(
                        message: viewModel.error!,
                        onRetry: () => viewModel.search(viewModel.query),
                      ),
                    ),

                  // Search Results grouped by source
                  if (viewModel.sourceGroups.isNotEmpty)
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final groups = viewModel.sourceGroups;
                        if (index >= groups.length) return null;
                        final group = groups[index];
                        return Padding(
                          padding: EdgeInsets.only(
                            left: padding.left,
                            right: padding.left,
                            top: index == 0 ? padding.top : 16,
                            bottom: 16,
                          ),
                          child: SourceSection(
                            group: group,
                            onMediaTap: (media) =>
                                _handleMediaTap(context, media),
                          ),
                        );
                      }),
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
                      viewModel.sourceGroups.isEmpty &&
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
      case MediaType.cartoon:
        return 'Cartoons';
      case MediaType.documentary:
        return 'Documentaries';
      case MediaType.livestream:
        return 'Livestreams';
      case MediaType.nsfw:
        return 'NSFW';
    }
  }

  List<SourceOption> _buildSourceOptions() {
    return [
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
        icon: const Icon(Icons.animation, size: 16),
      ),
      SourceOption(
        id: 'jikan',
        name: 'MyAnimeList',
        icon: const Icon(Icons.list, size: 16),
      ),
      SourceOption(
        id: 'kitsu',
        name: 'Kitsu',
        icon: const Icon(Icons.book, size: 16),
      ),
      SourceOption(
        id: 'simkl',
        name: 'Simkl',
        icon: const Icon(Icons.tv, size: 16),
      ),
    ];
  }

  Future<void> _handleMediaTap(BuildContext context, MediaEntity media) async {
    await _navigateToMediaDetails(context, media);
  }

  Future<void> _navigateToMediaDetails(
    BuildContext context,
    MediaEntity media,
  ) async {
    final sourceId = media.sourceId.toLowerCase();

    if (sourceId == 'tmdb') {
      final tmdbSeed = _buildTmdbSeedData(media);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TmdbDetailsScreen(
            tmdbData: tmdbSeed,
            isMovie: media.type == MediaType.movie,
          ),
        ),
      );
      return;
    }

    if (_isAnimeMangaSource(media)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AnimeMangaDetailsScreen(media: media),
        ),
      );
      return;
    }

    if (_isMovieOrTv(media)) {
      final tmdbData = await _ensureTmdbData(context, media);
      if (tmdbData == null || !context.mounted) {
        _showResolutionError(
          context,
          'Unable to open TMDB details for this item.',
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TmdbDetailsScreen(
            tmdbData: tmdbData,
            isMovie: media.type == MediaType.movie,
          ),
        ),
      );
      return;
    }

    if (_isAnimeOrManga(media.type)) {
      final resolvedMedia = await _ensureAnimeMedia(context, media);
      if (resolvedMedia == null || !context.mounted) {
        _showResolutionError(
          context,
          'Unable to open anime/manga details for this item.',
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AnimeMangaDetailsScreen(media: resolvedMedia),
        ),
      );
      return;
    }

    Navigator.pushNamed(context, '/media-details', arguments: media);
  }

  bool _isTmdbSource(String sourceId) => sourceId == 'tmdb';

  bool _isAnimeMangaSource(MediaEntity media) {
    if (media.type != MediaType.anime && media.type != MediaType.manga) {
      return false;
    }

    const animeSources = {'anilist', 'jikan', 'myanimelist', 'mal', 'kitsu'};

    return animeSources.contains(media.sourceId.toLowerCase());
  }

  bool _isMovieOrTv(MediaEntity media) {
    return media.type == MediaType.movie || media.type == MediaType.tvShow;
  }

  bool _isAnimeOrManga(MediaType type) {
    return type == MediaType.anime ||
        type == MediaType.manga ||
        type == MediaType.novel;
  }

  Future<Map<String, dynamic>?> _ensureTmdbData(
    BuildContext context,
    MediaEntity media,
  ) async {
    final sourceId = media.sourceId.toLowerCase();
    if (_isTmdbSource(sourceId)) {
      return {
        'id': int.tryParse(media.id) ?? media.id,
        'title': media.title,
        'name': media.title,
        'overview': media.description,
      };
    }

    return _withLoadingOverlay(context, () async {
      try {
        final dataSource = sl<ExternalRemoteDataSource>();
        final effectiveType = media.type == MediaType.movie
            ? MediaType.movie
            : MediaType.tvShow;
        final results = await dataSource.searchMedia(
          media.title,
          'tmdb',
          effectiveType,
          year: media.startDate?.year,
        );
        if (results.isEmpty) return null;
        final match = results.first;
        return {
          'id': int.tryParse(match.id) ?? match.id,
          'title': match.title,
          'name': match.title,
          'overview': match.description,
        };
      } catch (e, stackTrace) {
        Logger.error(
          'Failed to resolve TMDB data for ${media.title}',
          error: e,
          stackTrace: stackTrace,
        );
        return null;
      }
    });
  }

  Future<MediaEntity?> _ensureAnimeMedia(
    BuildContext context,
    MediaEntity media,
  ) async {
    if (_isAnimeMangaSource(media)) {
      return media;
    }

    return _withLoadingOverlay(context, () async {
      final providerOrder =
          media.type == MediaType.manga || media.type == MediaType.novel
          ? ['kitsu', 'anilist']
          : ['anilist', 'kitsu', 'jikan'];
      final dataSource = sl<ExternalRemoteDataSource>();

      for (final providerId in providerOrder) {
        try {
          final results = await dataSource.searchMedia(
            media.title,
            providerId,
            media.type,
            year: media.startDate?.year,
          );
          if (results.isNotEmpty) {
            return results.first;
          }
        } catch (e, stackTrace) {
          Logger.warning(
            'Provider $providerId resolution failed for ${media.title}',
          );
          Logger.error(
            'Resolution failure details',
            tag: 'SearchScreen',
            error: e,
            stackTrace: stackTrace,
          );
          continue;
        }
      }

      return null;
    });
  }

  Future<T?> _withLoadingOverlay<T>(
    BuildContext context,
    Future<T?> Function() task,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      return await task();
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  void _showResolutionError(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Map<String, dynamic> _buildTmdbSeedData(MediaEntity media) {
    final releaseDate = media.startDate?.toIso8601String().split('T').first;
    return {
      'id': int.tryParse(media.id) ?? media.id,
      'title': media.title,
      'name': media.title,
      'poster_path': _extractTmdbRelativePath(media.coverImage),
      'backdrop_path': _extractTmdbRelativePath(media.bannerImage),
      'overview': media.description,
      'release_date': media.type == MediaType.movie ? releaseDate : null,
      'first_air_date': media.type == MediaType.tvShow ? releaseDate : null,
      'genres': media.genres.map((g) => {'name': g}).toList(),
      'status': media.status?.name,
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
    final tail = path.substring(slashIndex);
    return tail.isEmpty ? null : tail;
  }
}

class SourceSection extends StatelessWidget {
  final SourceResultGroup group;
  final ValueChanged<MediaEntity> onMediaTap;

  const SourceSection({required this.group, required this.onMediaTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                group.displayName,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (group.isLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            if (group.hasError)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(
                  Icons.error_outline,
                  color: theme.colorScheme.error,
                  size: 18,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 300,
          child: group.items.isEmpty
              ? ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: group.isLoading ? 4 : 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, __) =>
                      const SizedBox(width: 190, child: MediaSkeletonCard()),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (context, index) {
                    final media = group.items[index];
                    return SizedBox(
                      width: 190,
                      child: MediaCard(
                        media: media,
                        onTap: () => onMediaTap(media),
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemCount: group.items.length,
                ),
        ),
        if (group.hasError && (group.errorMessage?.isNotEmpty ?? false))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              group.errorMessage!,
              style: textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}
