import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/data/datasources/external_remote_data_source.dart';
import '../../../../core/data/datasources/tmdb_external_data_source.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/domain/entities/entities.dart';
import '../../../../core/domain/entities/source_entity.dart';
import '../../../../core/domain/entities/library_item_entity.dart';
import '../../../../core/domain/entities/watch_history_entry.dart';
import '../../../../core/domain/repositories/library_repository.dart';
import '../../../../core/domain/usecases/add_to_library_usecase.dart';
import '../../../../core/domain/usecases/remove_from_library_usecase.dart';
import '../../../../core/services/watch_history_controller.dart';
import '../../../../core/enums/tracking_service.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/cross_provider_matcher.dart';
import '../../../../core/utils/data_aggregator.dart';
import '../../../../core/utils/provider_cache.dart';
import '../../../../core/widgets/provider_attribution_dialog.dart';
import '../../../../core/widgets/provider_badge.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../../manga_reader/presentation/screens/manga_reader_screen.dart';
import '../../../novel_reader/presentation/screens/novel_reader_screen.dart';
import '../../../media_details/presentation/models/source_selection_result.dart';
import '../../../media_details/presentation/screens/episode_source_selection_sheet.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../video_player/presentation/screens/video_player_screen.dart';

/// Details screen for Anime and Manga from external sources
class AnimeMangaDetailsScreen extends StatefulWidget {
  final MediaEntity media;
  final String? initialSourceOverride;

  const AnimeMangaDetailsScreen({
    required this.media,
    this.initialSourceOverride,
    super.key,
  });

  @override
  State<AnimeMangaDetailsScreen> createState() =>
      _AnimeMangaDetailsScreenState();
}

class _AnimeMangaDetailsScreenState extends State<AnimeMangaDetailsScreen>
    with SingleTickerProviderStateMixin {
  late final ExternalRemoteDataSource _dataSource;
  late final AuthViewModel _authViewModel;
  late final CrossProviderMatcher _matcher;
  late final DataAggregator _aggregator;
  late final ProviderCache _cache;
  late final AddToLibraryUseCase _addToLibraryUseCase;
  late final RemoveFromLibraryUseCase _removeFromLibraryUseCase;
  late final LibraryRepository _libraryRepository;
  late final WatchHistoryController _watchHistoryController;
  late TabController _tabController;

  MediaDetailsEntity? _fullDetails;
  bool _isLoading = true;
  bool _hasError = false;

  // Provider attribution
  List<String> _contributingProviders = [];
  Map<String, String>? _dataSourceAttribution;
  Map<String, double>? _matchConfidences;

  // Episodes state
  List<EpisodeEntity> _allEpisodes = []; // All episodes from aggregation
  List<EpisodeEntity> _episodes = []; // Currently displayed episodes
  bool _isLoadingEpisodes = false;

  // Season/Page pagination state
  Map<int, List<EpisodeEntity>>?
  _episodesBySeason; // Episodes grouped by season
  List<int>? _seasons; // Available season numbers
  int? _selectedSeason; // Currently selected season
  Map<int, String?>? _seasonNames; // Season number -> season name
  int _currentPage = 1; // Current page (when using page-based pagination)
  static const int _episodesPerPage = 50;

  // Chapters state
  List<ChapterEntity> _chapters = [];
  bool _isLoadingChapters = false;
  LibraryItemEntity? _libraryItem;
  LibraryStatus? _libraryStatus;
  bool _isLibraryActionInProgress = false;

  @override
  void initState() {
    super.initState();
    _dataSource = sl<ExternalRemoteDataSource>();
    _authViewModel = sl<AuthViewModel>();
    _matcher = sl<CrossProviderMatcher>();
    _aggregator = sl<DataAggregator>();
    _cache = sl<ProviderCache>();
    _addToLibraryUseCase = sl<AddToLibraryUseCase>();
    _removeFromLibraryUseCase = sl<RemoveFromLibraryUseCase>();
    _libraryRepository = sl<LibraryRepository>();
    _watchHistoryController = sl<WatchHistoryController>();
    // 3 tabs for Anime/Manga (Overview, Episodes/Chapters, More Info)
    final isAnime = widget.media.type == MediaType.anime;
    _tabController = TabController(length: 3, vsync: this);
    _initializeAttributionFromMedia(widget.media);
    _fetchFullDetails();
    _loadLibraryEntry();
    if (isAnime) {
      _fetchEpisodes();
    } else {
      _fetchChapters();
    }
  }

  String _buildLibraryItemId() {
    return '${widget.media.id}_${TrackingService.local.name}';
  }

  Future<void> _loadLibraryEntry() async {
    final result = await _libraryRepository.getLibraryItem(
      _buildLibraryItemId(),
    );
    if (!mounted) return;
    result.fold(
      (failure) {
        if (failure is! NotFoundFailure) {
          Logger.error(
            'Failed to load library item: ${failure.message}',
            tag: 'AnimeMangaDetailsScreen',
          );
        }
        setState(() {
          _libraryItem = null;
          _libraryStatus = null;
        });
      },
      (item) {
        setState(() {
          _libraryItem = item;
          _libraryStatus = item.status;
        });
      },
    );
  }

  void _showMovieSourceSelection() {
    if (widget.media.type != MediaType.movie) return;

    final media = widget.media;
    final details = _fullDetails;
    final episode = EpisodeEntity(
      id: media.id,
      mediaId: media.id,
      number: 1,
      title: details?.title ?? media.title,
      releaseDate: details?.startDate,
      thumbnail:
          details?.bannerImage ?? details?.coverImage ?? media.coverImage,
      sourceProvider: media.sourceId,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return EpisodeSourceSelectionSheet(
          media: media,
          episode: episode,
          isChapter: false,
          onSourceSelected: (selection) {
            _navigateToVideoPlayer(
              context,
              episode,
              selection.source,
              selection.allSources,
            );
          },
        );
      },
    );
  }

  Widget _buildPlayButton(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: _showMovieSourceSelection,
      icon: const Icon(Icons.play_arrow_rounded),
      label: const Text('Play'),
    );
  }

  void _initializeAttributionFromMedia(MediaEntity media) {
    _contributingProviders = [media.sourceId];
    _dataSourceAttribution = null;
    _matchConfidences = null;
  }

  void _updateProviderAttribution(MediaDetailsEntity details) {
    final providers = details.contributingProviders;
    _contributingProviders = (providers != null && providers.isNotEmpty)
        ? providers
        : [details.sourceId];
    _dataSourceAttribution = details.dataSourceAttribution;
    _matchConfidences = details.matchConfidences;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchFullDetails() async {
    try {
      // First, get primary details
      final primarySourceId =
          widget.initialSourceOverride ?? widget.media.sourceId;

      final primaryDetails = await _dataSource.getMediaDetails(
        widget.media.id,
        primarySourceId,
        widget.media.type,
      );

      // Find matches across all providers
      final matches = await _matcher.findMatches(
        title: widget.media.title,
        type: widget.media.type,
        primarySourceId: primarySourceId,
        englishTitle: primaryDetails.englishTitle,
        romajiTitle: primaryDetails.romajiTitle,
        year: primaryDetails.startDate?.year,
        searchFunction: _searchProvider,
        cache: _cache,
      );

      // Aggregate details from all matched providers
      final aggregatedDetails = await _aggregator.aggregateMediaDetails(
        primaryDetails: primaryDetails,
        matches: matches,
        detailsFetcher: _fetchDetailsFromProvider,
      );

      if (mounted) {
        setState(() {
          _fullDetails = aggregatedDetails;
          _isLoading = false;
          _updateProviderAttribution(aggregatedDetails);
        });
      }
    } catch (e) {
      Logger.error('Error fetching full details', error: e);
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  /// Search a specific provider for matching media
  Future<List<MediaEntity>> _searchProvider(
    String query,
    String providerId,
    MediaType type,
  ) async {
    try {
      // Map media types for cross-provider searching
      // Anime items should search TMDB as TV shows
      MediaType searchType = type;
      if (type == MediaType.anime && providerId.toLowerCase() == 'tmdb') {
        searchType = MediaType.tvShow;
      }

      final results = await _dataSource.searchMedia(
        query,
        providerId,
        searchType,
      );
      return results;
    } catch (e) {
      Logger.error('Error searching provider $providerId', error: e);
      return [];
    }
  }

  /// Fetch media details from a specific provider
  Future<MediaDetailsEntity> _fetchDetailsFromProvider(
    String mediaId,
    String providerId,
  ) async {
    try {
      return await _dataSource.getMediaDetails(
        mediaId,
        providerId,
        widget.media.type,
        includeCharacters: true,
        includeStaff: true,
        includeReviews: false,
      );
    } catch (e) {
      Logger.error(
        'Error fetching details from provider $providerId',
        error: e,
      );
      // Return minimal details entity on error
      return MediaDetailsEntity(
        id: mediaId,
        title: '',
        coverImage: '',
        type: widget.media.type,
        genres: [],
        tags: [],
        sourceId: providerId,
        sourceName: providerId,
      );
    }
  }

  Future<void> _fetchEpisodes() async {
    if (widget.media.type != MediaType.anime) return;

    setState(() {
      _isLoadingEpisodes = true;
    });

    // First, get aggregated episodes to know the total count
    // This ensures we have the full episode list from all providers
    try {
      final aggregatedEpisodes = await _dataSource.getEpisodes(widget.media);
      final aggregatedCount = aggregatedEpisodes.length;

      Logger.info(
        'Aggregated episodes count: $aggregatedCount for ${widget.media.title}',
      );

      // Try to group episodes by season, otherwise use page-based pagination
      final seasonGroups = _groupEpisodesBySeason(aggregatedEpisodes);
      final seasonNames = seasonGroups != null && seasonGroups.isNotEmpty
          ? _getSeasonNames(aggregatedEpisodes)
          : null;

      var groupedEpisodeCount = 0;
      if (seasonGroups != null && seasonGroups.isNotEmpty) {
        for (final group in seasonGroups.values) {
          groupedEpisodeCount += group.length;
        }
      }

      final hasCompleteSeasonData =
          seasonGroups != null &&
          seasonGroups.isNotEmpty &&
          groupedEpisodeCount >= (aggregatedEpisodes.length * 0.9);

      if (mounted) {
        setState(() {
          _allEpisodes = aggregatedEpisodes;
          _isLoadingEpisodes = false;

          if (hasCompleteSeasonData) {
            _episodesBySeason = seasonGroups;
            _seasons = seasonGroups.keys.toList()..sort();
            final firstSeason = _seasons!.first;
            _selectedSeason = firstSeason;
            _episodes = List<EpisodeEntity>.from(
              seasonGroups[_selectedSeason] ?? const [],
            );
            _seasonNames = seasonNames;
          } else {
            _episodesBySeason = null;
            _seasons = null;
            _selectedSeason = null;
            _seasonNames = null;
            _currentPage = 1;
            _updateEpisodesForCurrentPage();
          }
        });
      }
    } catch (e) {
      Logger.error('Error fetching episodes', error: e);
      if (mounted) {
        setState(() {
          _isLoadingEpisodes = false;
        });
      }
    }
  }

  Future<void> _fetchChapters() async {
    if (widget.media.type != MediaType.manga &&
        widget.media.type != MediaType.novel) {
      return;
    }

    setState(() {
      _isLoadingChapters = true;
    });

    try {
      final chapters = await _dataSource.getChapters(widget.media);
      if (!mounted) return;
      setState(() {
        _chapters = chapters;
        _isLoadingChapters = false;
      });
    } on MalAuthRequiredException {
      if (!mounted) return;
      setState(() {
        _isLoadingChapters = false;
      });
      await _promptForTrackingAuth(TrackingService.mal);
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to fetch chapters',
        error: e,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _isLoadingChapters = false;
      });
      if (!(_chapters.isNotEmpty)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load chapters: $e')));
      }
    }
  }

  Future<void> _promptForTrackingAuth(TrackingService service) async {
    final serviceName = _trackingServiceLabel(service);

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('Connect $serviceName?'),
            content: Text(
              '$serviceName access lets us fetch chapter counts when other providers fall short. '
              'Would you like to connect now?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Not now'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text('Connect $serviceName'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(highlightedService: service),
      ),
    );

    if (!mounted) return;

    final token = await _authViewModel.ensureToken(service);
    if (token != null) {
      await _fetchChapters();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connect MyAnimeList to load chapters.')),
      );
    }
  }

  String _trackingServiceLabel(TrackingService service) {
    switch (service) {
      case TrackingService.anilist:
        return 'AniList';
      case TrackingService.mal:
        return 'MyAnimeList';
      case TrackingService.simkl:
        return 'Simkl';
      case TrackingService.jikan:
      case TrackingService.local:
        return 'Jikan';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use full details if available, otherwise fallback to initial data
    final mediaTitle = _fullDetails?.title ?? widget.media.title;
    final bannerImage = _fullDetails?.bannerImage ?? widget.media.bannerImage;
    final coverImage = _fullDetails?.coverImage ?? widget.media.coverImage;
    final description = _fullDetails?.description ?? widget.media.description;
    final rating = _fullDetails?.rating ?? widget.media.rating;
    final status = _fullDetails?.status ?? widget.media.status;
    final genres = _fullDetails?.genres ?? widget.media.genres;

    // Use banner if available, otherwise use cover as fallback
    final backdropImage = bannerImage ?? coverImage;

    final isAnime = widget.media.type == MediaType.anime;

    return Scaffold(
      floatingActionButton: widget.media.type == MediaType.movie
          ? _buildPlayButton(context)
          : null,
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            // 1. Sliver App Bar with Backdrop and Gradient
            SliverAppBar(
              expandedHeight: 400,
              pinned: true,
              stretch: true,
              backgroundColor: Theme.of(context).colorScheme.surface,
              titleSpacing: 0,
              title: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: innerBoxIsScrolled ? 1 : 0,
                child: Text(
                  mediaTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [
                  StretchMode.zoomBackground,
                  StretchMode.blurBackground,
                ],
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Backdrop Image
                    if (backdropImage != null)
                      Image.network(
                        backdropImage,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Container(color: Colors.black),
                      )
                    else
                      Container(color: Colors.black),

                    // Gradient Overlay (Bottom to Top)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.3),
                            Theme.of(context).colorScheme.surface,
                          ],
                          stops: const [0.0, 0.6, 1.0],
                        ),
                      ),
                    ),

                    // Content Overlay (Poster & Title)
                    Positioned(
                      bottom: 20,
                      left: 20,
                      right: 20,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Poster
                          Hero(
                            tag: 'poster_${widget.media.id}',
                            child: Container(
                              width: 120,
                              height: 180,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: coverImage != null
                                    ? Image.network(
                                        coverImage,
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        color: Colors.grey[800],
                                        child: Icon(
                                          isAnime ? Icons.movie : Icons.book,
                                          size: 40,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Title & Basic Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  mediaTitle,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
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
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _getStatusText(status),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      (rating ?? 0.0).toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. Action Buttons
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _isLibraryActionInProgress
                                ? null
                                : (_libraryStatus != null
                                      ? _confirmRemoveFromLibrary
                                      : _showAddToLibraryDialog),
                            icon: Icon(
                              _libraryStatus != null ? Icons.delete : Icons.add,
                            ),
                            label: Text(
                              _libraryStatus != null
                                  ? _getStatusDisplayName(_libraryStatus!)
                                  : 'Add to Library',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _playOrContinue,
                            icon: const Icon(Icons.play_arrow),
                            label: Text(
                              widget.media.type == MediaType.movie
                                  ? 'Play'
                                  : widget.media.type == MediaType.anime
                                  ? 'Play'
                                  : 'Read',
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_contributingProviders.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.outline.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.source,
                                  size: 16,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Data Sources',
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const Spacer(),
                                TextButton.icon(
                                  onPressed: () =>
                                      _showProviderAttributionDialog(context),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.info_outline,
                                    size: 16,
                                  ),
                                  label: const Text('Details'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ProviderBadgeList(
                              providers: _contributingProviders,
                              isSmall: false,
                              onProviderTap: (_) =>
                                  _showProviderAttributionDialog(context),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // 3. Tabs
            SliverPersistentHeader(
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: Theme.of(context).colorScheme.primary,
                  unselectedLabelColor: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant,
                  indicatorColor: Theme.of(context).colorScheme.primary,
                  tabs: [
                    const Tab(text: 'Overview'),
                    Tab(text: isAnime ? 'Episodes' : 'Chapters'),
                    const Tab(text: 'More Info'),
                  ],
                ),
              ),
              pinned: true,
            ),
          ];
        },
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _hasError
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    const Text('Failed to load details'),
                    TextButton(
                      onPressed: _fetchFullDetails,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : TabBarView(
                controller: _tabController,
                children: [
                  // Overview Tab
                  _buildOverviewTab(_fullDetails, genres, description),

                  // Episodes/Chapters Tab
                  if (isAnime)
                    _buildEpisodesTab(_fullDetails)
                  else
                    _buildChaptersTab(_fullDetails),

                  // More Info Tab
                  _buildMoreInfoTab(_fullDetails),
                ],
              ),
      ),
    );
  }

  void _showProviderAttributionDialog(BuildContext context) {
    showProviderAttributionDialog(
      context,
      dataSourceAttribution: _dataSourceAttribution,
      contributingProviders: _contributingProviders,
      matchConfidences: _matchConfidences,
      primaryProvider: widget.media.sourceId,
    );
  }

  Widget _buildOverviewTab(
    MediaDetailsEntity? details,
    List<String> genres,
    String? description,
  ) {
    final recommendations = details?.recommendations ?? [];

    return Builder(
      builder: (context) {
        return CustomScrollView(
          key: const PageStorageKey<String>('overview'),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 64),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats Grid
                    _buildStatsGrid(context, details),
                    const SizedBox(height: 24),

                    // Synopsis
                    Text(
                      'Synopsis',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description ?? 'No description available.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Genres
                    if (genres.isNotEmpty) ...[
                      Text(
                        'Genres',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: genres
                            .map(
                              (genre) => Chip(
                                label: Text(genre),
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                labelStyle: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                                side: BorderSide.none,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Recommendations
                    if (recommendations.isNotEmpty) ...[
                      Text(
                        'You might also like',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 225,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: recommendations.length,
                          itemBuilder: (context, index) {
                            final item = recommendations[index];
                            return Container(
                              width: 120,
                              margin: const EdgeInsets.only(right: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        item.coverImage,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Container(
                                                  color: Colors.grey[800],
                                                  child: const Icon(
                                                    Icons.movie,
                                                  ),
                                                ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    height: 50,
                                    child: Text(
                                      item.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEpisodesTab(MediaDetailsEntity? details) {
    if (_isLoadingEpisodes) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_allEpisodes.isEmpty) {
      return CustomScrollView(
        key: const PageStorageKey<String>('episodes_empty'),
        slivers: [
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.tv_off,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No episodes found',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (details?.episodes != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Expected: ${details!.episodes} episodes',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final hasSeasons = _seasons != null && _seasons!.isNotEmpty;
    final totalPages = _getTotalPages();

    return CustomScrollView(
      key: const PageStorageKey<String>('episodes'),
      slivers: [
        // Season/Page Selector
        SliverToBoxAdapter(
          child: Column(
            children: [
              if (hasSeasons)
                // Season Selector
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _seasons!.length,
                    itemBuilder: (context, index) {
                      final season = _seasons![index];
                      final isSelected = season == _selectedSeason;
                      final episodeCount =
                          _episodesBySeason?[season]?.length ?? 0;

                      final seasonName = _seasonNames?[season];
                      final seasonLabel =
                          seasonName != null && seasonName.isNotEmpty
                          ? '$seasonName ($episodeCount)'
                          : 'Season $season ($episodeCount)';

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(seasonLabel),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              _selectSeason(season);
                            }
                          },
                        ),
                      );
                    },
                  ),
                )
              else
                // Page Selector
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: _currentPage > 1
                            ? () => _goToPage(_currentPage - 1)
                            : null,
                      ),
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Page $_currentPage of $totalPages',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (_fullDetails?.episodes != null &&
                                  _allEpisodes.length < _fullDetails!.episodes!)
                                Text(
                                  '${_allEpisodes.length} of ${_fullDetails!.episodes} episodes loaded',
                                  style: Theme.of(context).textTheme.bodySmall
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
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: _currentPage < totalPages
                            ? () => _goToPage(_currentPage + 1)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.list),
                        tooltip: 'Go to page',
                        onPressed: () =>
                            _showPageSelectorDialog(context, totalPages),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // Episodes List
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final episode = _episodes[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                clipBehavior: Clip.antiAlias,
                elevation: 2,
                child: InkWell(
                  onTap: () {
                    _showEpisodeSourceSelection(context, episode);
                  },
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Thumbnail
                      SizedBox(
                        width: 140,
                        height: 100,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Builder(
                              builder: (context) {
                                final thumbnailUrl = _resolveEpisodeThumbnail(
                                  episode,
                                );
                                if (thumbnailUrl == null ||
                                    thumbnailUrl.isEmpty) {
                                  return Container(
                                    color: Colors.grey[800],
                                    child: const Icon(Icons.tv),
                                  );
                                }
                                return Image.network(
                                  thumbnailUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        color: Colors.grey[800],
                                        child: const Icon(
                                          Icons.image_not_supported,
                                        ),
                                      ),
                                );
                              },
                            ),
                            // Play icon overlay
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.play_arrow,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Info
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Episode ${episode.number}',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                episode.title.isNotEmpty
                                    ? episode.title
                                    : 'Episode ${episode.number}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              if (episode.releaseDate != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat(
                                    'MMM d, y',
                                  ).format(episode.releaseDate!),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      // Progress indicator for episode
                      FutureBuilder<WatchHistoryEntry?>(
                        future: _watchHistoryController.getEntryForMedia(
                          widget.media.id,
                          widget.media.sourceId,
                          MediaType.anime,
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.hasData &&
                              snapshot.data != null &&
                              snapshot.data!.episodeNumber == episode.number) {
                            final entry = snapshot.data!;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.play_circle,
                                    size: 12,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    entry.progressDisplayString,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  if (entry.remainingTimeFormatted != null) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      '• ${entry.remainingTimeFormatted}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                ),
              );
            }, childCount: _episodes.length),
          ),
        ),
      ],
    );
  }

  /// Show dialog to select a specific page
  void _showPageSelectorDialog(BuildContext context, int totalPages) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        int? selectedPage;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Go to Page'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Select a page (1-$totalPages)'),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        totalPages > 10 ? 10 : totalPages,
                        (index) {
                          final page = index + 1;
                          final isSelected = selectedPage == page;
                          return Padding(
                            padding: const EdgeInsets.all(4),
                            child: ChoiceChip(
                              label: Text('$page'),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  selectedPage = selected ? page : null;
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  if (totalPages > 10) ...[
                    const SizedBox(height: 8),
                    TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Or enter page number',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        final page = int.tryParse(value);
                        if (page != null && page >= 1 && page <= totalPages) {
                          setState(() {
                            selectedPage = page;
                          });
                        }
                      },
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: selectedPage != null
                      ? () {
                          Navigator.of(dialogContext).pop();
                          _goToPage(selectedPage!);
                        }
                      : null,
                  child: const Text('Go'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildChaptersTab(MediaDetailsEntity? details) {
    if (_isLoadingChapters) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_chapters.isEmpty) {
      return CustomScrollView(
        key: const PageStorageKey<String>('chapters_empty'),
        slivers: [
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.book_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No chapters found',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (details?.chapters != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Expected: ${details!.chapters} chapters',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return CustomScrollView(
      key: const PageStorageKey<String>('chapters'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final chapter = _chapters[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                child: Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        child: Text(
                          '${chapter.number.toInt()}',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        chapter.title.isNotEmpty
                            ? chapter.title
                            : 'Chapter ${chapter.number}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: chapter.releaseDate != null
                          ? Text(
                              DateFormat(
                                'MMM d, y',
                              ).format(chapter.releaseDate!),
                            )
                          : null,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        _showChapterSourceSelection(context, chapter);
                      },
                    ),
                    // Progress indicator for chapter
                    FutureBuilder<WatchHistoryEntry?>(
                      future: _watchHistoryController.getEntryForMedia(
                        widget.media.id,
                        widget.media.sourceId,
                        widget.media.type,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.hasData &&
                            snapshot.data != null &&
                            snapshot.data!.chapterNumber == chapter.number) {
                          final entry = snapshot.data!;
                          return Padding(
                            padding: const EdgeInsets.only(
                              left: 16,
                              right: 16,
                              bottom: 8,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.book,
                                  size: 12,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  entry.progressDisplayString,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              );
            }, childCount: _chapters.length),
          ),
        ),
      ],
    );
  }

  Widget _buildMoreInfoTab(MediaDetailsEntity? details) {
    final characters = details?.characters ?? [];
    final staff = details?.staff ?? [];
    final studios = details?.studios ?? [];

    return Builder(
      builder: (context) {
        return CustomScrollView(
          key: const PageStorageKey<String>('more_info'),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Characters
                    if (characters.isNotEmpty) ...[
                      Text(
                        'Characters',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 160,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: characters.length,
                          itemBuilder: (context, index) {
                            final character = characters[index];
                            return Container(
                              width: 100,
                              margin: const EdgeInsets.only(right: 12),
                              child: Column(
                                children: [
                                  CircleAvatar(
                                    radius: 40,
                                    backgroundImage: character.image != null
                                        ? NetworkImage(character.image!)
                                        : null,
                                    child: character.image == null
                                        ? const Icon(Icons.person)
                                        : null,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    character.name,
                                    maxLines: 2,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    character.role,
                                    maxLines: 1,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Staff
                    if (staff.isNotEmpty) ...[
                      Text(
                        'Staff',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: staff
                            .map(
                              (person) => SizedBox(
                                width: 150,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      person.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      person.role,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Studios (Anime Only)
                    if (studios.isNotEmpty) ...[
                      Text(
                        'Studios',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: studios
                            .map(
                              (studio) => Chip(
                                label: Text(studio.name),
                                backgroundColor: studio.isMain
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.primaryContainer
                                    : Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                                labelStyle: TextStyle(
                                  color: studio.isMain
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.onPrimaryContainer
                                      : Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                ),
                                side: BorderSide.none,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatsGrid(BuildContext context, MediaDetailsEntity? details) {
    final stats = <MapEntry<String, String>>[];

    // Rating
    final score = details?.averageScore ?? details?.meanScore;
    if (score != null) {
      stats.add(MapEntry('Score', '$score / 100'));
    }

    // Episodes/Chapters
    if (widget.media.type == MediaType.anime && details?.episodes != null) {
      stats.add(MapEntry('Episodes', '${details!.episodes}'));
    } else if (widget.media.type == MediaType.manga) {
      if (details?.chapters != null) {
        stats.add(MapEntry('Chapters', '${details!.chapters}'));
      }
      if (details?.volumes != null) {
        stats.add(MapEntry('Volumes', '${details!.volumes}'));
      }
    }

    // Duration (Anime Only)
    if (widget.media.type == MediaType.anime && details?.duration != null) {
      stats.add(MapEntry('Duration', '${details!.duration} min'));
    }

    // Popularity
    if (details?.popularity != null) {
      stats.add(MapEntry('Popularity', _formatNumber(details!.popularity!)));
    }

    // Favorites
    if (details?.favorites != null) {
      stats.add(MapEntry('Favorites', _formatNumber(details!.favorites!)));
    }

    // Start Date
    if (details?.startDate != null) {
      stats.add(
        MapEntry('Started', DateFormat('MMM d, y').format(details!.startDate!)),
      );
    }

    // Season (Anime Only)
    if (widget.media.type == MediaType.anime && details?.season != null) {
      final seasonText = '${details!.season} ${details.seasonYear ?? ''}';
      stats.add(MapEntry('Season', seasonText.trim()));
    }

    // Data Source
    stats.add(MapEntry('Source', widget.media.sourceName));

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.6,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        return _buildStatRow(context, stat.key, stat.value);
      },
    );
  }

  Widget _buildStatRow(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _getStatusText(MediaStatus status) {
    switch (status) {
      case MediaStatus.ongoing:
        return 'AIRING';
      case MediaStatus.completed:
        return 'FINISHED';
      case MediaStatus.upcoming:
        return 'NOT YET AIRED';
    }
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  /// Show episode source selection bottom sheet
  /// Requirements: 1.1
  void _showEpisodeSourceSelection(
    BuildContext context,
    EpisodeEntity episode, [
    bool resumeFromSavedPosition = true,
  ]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return EpisodeSourceSelectionSheet(
          media: widget.media,
          episode: episode,
          isChapter: false,
          onSourceSelected: (selection) {
            _navigateToVideoPlayer(
              context,
              episode,
              selection.source,
              selection.allSources,
              resumeFromSavedPosition: resumeFromSavedPosition,
            );
          },
        );
      },
    );
  }

  /// Navigate to video player with selected source
  /// Requirements: 5.1, 5.3
  void _navigateToVideoPlayer(
    BuildContext context,
    EpisodeEntity episode,
    SourceEntity source,
    List<SourceEntity> allSources, {
    bool resumeFromSavedPosition = true,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen.fromSourceSelection(
          media: widget.media,
          episode: episode,
          source: source,
          allSources: allSources,
          resumeFromSavedPosition: resumeFromSavedPosition,
        ),
      ),
    );
  }

  /// Show chapter source selection bottom sheet
  /// Requirements: 1.2
  void _showChapterSourceSelection(
    BuildContext context,
    ChapterEntity chapter, [
    bool resumeFromSavedPosition = true,
  ]) {
    // Create an EpisodeEntity from the chapter for the selection sheet
    final episodeFromChapter = EpisodeEntity(
      id: chapter.id,
      mediaId: chapter.mediaId,
      title: chapter.title,
      number: chapter.number.toInt(),
      releaseDate: chapter.releaseDate,
      sourceProvider: chapter.sourceProvider,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return EpisodeSourceSelectionSheet(
          media: widget.media,
          episode: episodeFromChapter,
          isChapter: true,
          onSourceSelected: (selection) {
            _navigateToMangaReader(
              context,
              chapter,
              selection,
              resumeFromSavedPosition,
            );
          },
        );
      },
    );
  }

  /// Navigate to manga/novel reader after selecting a source for a chapter
  /// Group episodes by season if season information can be inferred
  /// Returns null if seasons cannot be determined
  Map<int, List<EpisodeEntity>>? _groupEpisodesBySeason(
    List<EpisodeEntity> episodes,
  ) {
    // Check if any episodes have season information (e.g., from TMDB)
    final episodesWithSeasons = episodes
        .where((e) => e.seasonNumber != null)
        .toList();

    if (episodesWithSeasons.isEmpty) {
      // No season information available, use page-based pagination
      return null;
    }

    // Group episodes by season number
    final seasonGroups = <int, List<EpisodeEntity>>{};
    for (final episode in episodes) {
      if (episode.seasonNumber != null) {
        final season = episode.seasonNumber!;
        seasonGroups.putIfAbsent(season, () => []).add(episode);
      }
    }

    // Sort episodes within each season by episode number
    for (final season in seasonGroups.keys) {
      seasonGroups[season]!.sort((a, b) => a.number.compareTo(b.number));
    }

    Logger.info(
      'Grouped ${episodes.length} episodes into ${seasonGroups.length} seasons',
    );

    return seasonGroups.isNotEmpty ? seasonGroups : null;
  }

  /// Get season names from TMDB metadata if available
  Map<int, String?> _getSeasonNames(List<EpisodeEntity> episodes) {
    // Try to find a TMDB episode to get the tvId
    final tmdbEpisode = episodes.firstWhere(
      (e) => e.sourceProvider == 'tmdb' && e.seasonNumber != null,
      orElse: () => episodes.first,
    );

    if (tmdbEpisode.sourceProvider == 'tmdb') {
      final seasonMetadata = TmdbExternalDataSourceImpl.getSeasonMetadata(
        tmdbEpisode.mediaId,
      );

      if (seasonMetadata != null) {
        final seasonNames = <int, String?>{};
        for (final entry in seasonMetadata.entries) {
          seasonNames[entry.key] = entry.value['name'] as String?;
        }
        return seasonNames;
      }
    }

    return {};
  }

  /// Update displayed episodes based on current page
  void _updateEpisodesForCurrentPage() {
    if (_allEpisodes.isEmpty) {
      _episodes = [];
      return;
    }

    final startIndex = (_currentPage - 1) * _episodesPerPage;
    final endIndex = startIndex + _episodesPerPage;
    _episodes = _allEpisodes.sublist(
      startIndex,
      endIndex > _allEpisodes.length ? _allEpisodes.length : endIndex,
    );
  }

  /// Get total number of pages based on total episode count
  int _getTotalPages() {
    // Use the actual aggregated episode count as primary source
    // This ensures we use the most complete dataset
    final totalEpisodes = _allEpisodes.isNotEmpty
        ? _allEpisodes.length
        : (_fullDetails?.episodes ?? 0);
    if (totalEpisodes == 0) return 1;
    return ((totalEpisodes - 1) ~/ _episodesPerPage) + 1;
  }

  /// Navigate to a specific page
  void _goToPage(int page) {
    final totalPages = _getTotalPages();
    if (page < 1 || page > totalPages) return;

    setState(() {
      _currentPage = page;
      _updateEpisodesForCurrentPage();
    });
  }

  /// Navigate to a specific season
  void _selectSeason(int season) {
    if (_episodesBySeason == null || !_episodesBySeason!.containsKey(season)) {
      return;
    }

    setState(() {
      _selectedSeason = season;
      _episodes = _episodesBySeason![season] ?? [];
    });
  }

  String? _resolveEpisodeThumbnail(EpisodeEntity episode) {
    if (episode.thumbnail != null && episode.thumbnail!.isNotEmpty) {
      return episode.thumbnail;
    }

    final alternativeData = episode.alternativeData;
    if (alternativeData == null || alternativeData.isEmpty) {
      return null;
    }

    const providerPreference = [
      'jikan',
      'mal',
      'myanimelist',
      'kitsu',
      'anilist',
      'simkl',
      'tmdb',
    ];

    for (final provider in providerPreference) {
      final data = alternativeData[provider];
      if (data?.thumbnail != null && data!.thumbnail!.isNotEmpty) {
        return data.thumbnail;
      }
    }

    for (final data in alternativeData.values) {
      if (data.thumbnail != null && data.thumbnail!.isNotEmpty) {
        return data.thumbnail;
      }
    }

    return null;
  }

  void _navigateToMangaReader(
    BuildContext context,
    ChapterEntity chapter,
    SourceSelectionResult selection, [
    bool resumeFromSavedPosition = true,
  ]) {
    final source = selection.source;
    final providerChapter = chapter.copyWith(
      id: source.sourceLink,
      sourceProvider: source.providerId,
    );

    // Check if this is a novel - use novel reader instead
    if (widget.media.type == MediaType.novel) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => NovelReaderScreen(
            chapter: providerChapter,
            media: widget.media,
            allChapters: _chapters,
            source: source,
            sourceSelection: selection,
            resumeFromSavedPosition: resumeFromSavedPosition,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MangaReaderScreen(
            chapter: providerChapter,
            sourceId: source.providerId,
            itemId: widget.media.id,
            media: widget.media,
            source: source,
            chapterNumber: chapter.number.toString(), // Pass chapter number
          ),
        ),
      );
    }
  }

  /// Show dialog to select library status and add media to library
  void _showAddToLibraryDialog() {
    if (_libraryStatus != null) {
      return;
    }
    final title = widget.media.title;

    // Determine appropriate statuses based on media type
    final statuses = widget.media.type == MediaType.anime
        ? [
            LibraryStatus.planToWatch,
            LibraryStatus.currentlyWatching,
            LibraryStatus.completed,
            LibraryStatus.onHold,
            LibraryStatus.dropped,
          ]
        : [
            LibraryStatus.planToWatch,
            LibraryStatus.currentlyWatching,
            LibraryStatus.completed,
            LibraryStatus.onHold,
            LibraryStatus.dropped,
          ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add to Library'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            const Text('Select status:'),
            const SizedBox(height: 8),
            ...statuses.map(
              (status) => RadioListTile<LibraryStatus>(
                title: Text(_getStatusDisplayName(status)),
                value: status,
                groupValue: null,
                onChanged: (selected) {
                  Navigator.of(context).pop();
                  if (selected != null) {
                    _addToLibrary(selected);
                  }
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  String _getStatusDisplayName(LibraryStatus status) {
    switch (status) {
      case LibraryStatus.planToWatch:
        return widget.media.type == MediaType.manga
            ? 'Plan to Read'
            : 'Plan to Watch';
      case LibraryStatus.currentlyWatching:
        return 'Currently Watching';
      case LibraryStatus.completed:
        return 'Completed';
      case LibraryStatus.onHold:
        return 'On Hold';
      case LibraryStatus.dropped:
        return 'Dropped';
      case LibraryStatus.wantToWatch:
        return 'Want to Watch';
      case LibraryStatus.watched:
        return 'Watched';
      case LibraryStatus.watching:
        return 'Watching';
      case LibraryStatus.finished:
        return 'Finished';
    }
  }

  Future<void> _addToLibrary(LibraryStatus status) async {
    if (_isLibraryActionInProgress) return;
    setState(() => _isLibraryActionInProgress = true);
    try {
      final normalizedId = LibraryItemEntity.generateNormalizedId(
        widget.media.title,
        widget.media.type,
        _fullDetails?.startDate?.year ?? widget.media.startDate?.year,
      );

      final libraryItem = LibraryItemEntity(
        id: _buildLibraryItemId(),
        mediaId: widget.media.id,
        userService: TrackingService.local,
        media: widget.media,
        mediaType: widget.media.type,
        normalizedId: normalizedId,
        sourceId: widget.media.sourceId,
        sourceName: widget.media.sourceName,
        status: status,
        addedAt: DateTime.now(),
        lastUpdated: DateTime.now(),
      );

      final result = await _addToLibraryUseCase.call(
        AddToLibraryParams(item: libraryItem),
      );

      if (!mounted) return;

      result.fold(
        (failure) {
          setState(() => _isLibraryActionInProgress = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to add to library: ${failure.message}'),
              backgroundColor: Colors.red,
            ),
          );
        },
        (_) {
          setState(() {
            _libraryItem = libraryItem;
            _libraryStatus = status;
            _isLibraryActionInProgress = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Added to library: ${_getStatusDisplayName(status)}',
              ),
              backgroundColor: Colors.green,
            ),
          );
        },
      );
    } catch (e) {
      Logger.error(
        'Failed to add to library: $e',
        tag: 'AnimeMangaDetailsScreen',
      );
      if (mounted) {
        setState(() => _isLibraryActionInProgress = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add to library: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmRemoveFromLibrary() async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from Library'),
        content: Text('Remove "${widget.media.title}" from your library?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete),
            label: const Text('Remove'),
          ),
        ],
      ),
    );

    if (shouldRemove == true) {
      await _removeFromLibrary();
    }
  }

  Future<void> _removeFromLibrary() async {
    final item = _libraryItem;
    if (item == null || _isLibraryActionInProgress) return;
    setState(() => _isLibraryActionInProgress = true);
    final result = await _removeFromLibraryUseCase.call(
      RemoveFromLibraryParams(itemId: item.id),
    );

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() => _isLibraryActionInProgress = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove from library: ${failure.message}'),
            backgroundColor: Colors.red,
          ),
        );
      },
      (_) {
        setState(() {
          _libraryItem = null;
          _libraryStatus = null;
          _isLibraryActionInProgress = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Removed from library')));
      },
    );
  }

  /// Play or Continue button functionality
  void _playOrContinue() async {
    try {
      final mediaType = widget.media.type;

      // Check watch history for existing progress
      final watchHistory = await _watchHistoryController.getEntryForMedia(
        widget.media.id,
        widget.media.sourceId,
        widget.media.type,
      );

      if (mediaType == MediaType.movie) {
        // For movies, show source selection
        _showMovieSourceSelection();
      } else if (mediaType == MediaType.anime) {
        // For anime, check if we have watch history
        if (watchHistory != null && watchHistory.episodeNumber != null) {
          // Show confirmation dialog before continuing
          final shouldResume = await _showResumeConfirmationDialog(
            watchHistory,
          );
          await _continueFromEpisode(watchHistory.episodeNumber!, shouldResume);
        } else {
          // Play first episode
          await _playFirstEpisode();
        }
      } else {
        // For manga/novel, check if we have reading history
        if (watchHistory != null && watchHistory.chapterNumber != null) {
          // Show confirmation dialog before continuing
          final shouldResume = await _showResumeConfirmationDialog(
            watchHistory,
          );
          await _continueFromChapter(
            watchHistory.chapterNumber!.toDouble(),
            shouldResume,
          );
        } else {
          // Read first chapter
          await _readFirstChapter();
        }
      }
    } catch (e) {
      Logger.error(
        'Error in play/continue: $e',
        tag: 'AnimeMangaDetailsScreen',
      );
      // Fallback
      if (widget.media.type == MediaType.movie) {
        _showMovieSourceSelection();
      } else if (widget.media.type == MediaType.anime) {
        _playFirstEpisode();
      } else {
        _readFirstChapter();
      }
    }
  }

  Future<void> _continueFromEpisode(
    int episodeNumber,
    bool shouldResume,
  ) async {
    final episode = _episodes.firstWhere(
      (e) => e.number == episodeNumber,
      orElse: () => _episodes.first,
    );
    _showEpisodeSourceSelection(context, episode, shouldResume);
  }

  Future<void> _playFirstEpisode() async {
    if (_episodes.isNotEmpty) {
      _showEpisodeSourceSelection(context, _episodes.first);
    }
  }

  Future<void> _continueFromChapter(
    double chapterNumber,
    bool shouldResume,
  ) async {
    final chapter = _chapters.firstWhere(
      (c) => c.number == chapterNumber,
      orElse: () => _chapters.first,
    );
    _showChapterSourceSelection(context, chapter, shouldResume);
  }

  Future<void> _readFirstChapter() async {
    if (_chapters.isNotEmpty) {
      _showChapterSourceSelection(context, _chapters.first);
    }
  }

  /// Shows a confirmation dialog asking whether to resume from saved position or start over
  Future<bool> _showResumeConfirmationDialog(WatchHistoryEntry entry) async {
    // Check if there's meaningful progress to resume from
    final hasProgress = _hasMeaningfulProgress(entry);

    if (!hasProgress) {
      // No meaningful progress, just start over
      return false;
    }

    String resumeText;
    String mediaTypeText;

    if (entry.mediaType.isVideoType) {
      // Video content (anime, movie, etc.)
      final position = entry.playbackPositionMs ?? 0;
      final duration = entry.totalDurationMs ?? 0;
      final remainingMs = duration - position;
      final remainingMinutes = (remainingMs / 60000).round();

      resumeText = remainingMinutes > 0
          ? 'Resume from ${remainingMinutes}m remaining?'
          : 'Resume from saved position?';
      mediaTypeText =
          entry.episodeTitle ?? 'Episode ${entry.episodeNumber ?? 1}';
    } else {
      // Reading content (manga, novel)
      if (entry.pageNumber != null && entry.totalPages != null) {
        final remainingPages = entry.totalPages! - entry.pageNumber!;
        resumeText =
            'Resume from page ${entry.pageNumber! + 1} ($remainingPages pages left)?';
      } else if (entry.chapterNumber != null) {
        resumeText = 'Resume from chapter ${entry.chapterNumber! + 1}?';
      } else {
        resumeText = 'Resume from saved position?';
      }
      mediaTypeText =
          entry.chapterTitle ?? 'Chapter ${entry.chapterNumber ?? 1}';
    }

    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Resume "${entry.title}"?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mediaTypeText),
                  const SizedBox(height: 8),
                  Text(resumeText),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Start over'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Resume'),
                ),
              ],
            );
          },
        ) ??
        false; // Default to false if dialog is dismissed
  }

  /// Checks if entry has meaningful progress worth resuming from
  bool _hasMeaningfulProgress(WatchHistoryEntry entry) {
    if (entry.mediaType.isVideoType) {
      // For video content, consider progress meaningful if more than 30 seconds watched
      // and not in the last 30 seconds (to avoid resuming near the end)
      final position = entry.playbackPositionMs ?? 0;
      final duration = entry.totalDurationMs ?? 0;

      return position > 30000 && // More than 30 seconds watched
          duration > 60000 && // At least 1 minute total
          (duration - position) > 30000; // More than 30 seconds remaining
    } else {
      // For reading content, consider progress meaningful if not on first page/chapter
      if (entry.pageNumber != null && entry.totalPages != null) {
        return entry.pageNumber! > 0 &&
            entry.pageNumber! < entry.totalPages! - 1;
      }
      if (entry.chapterNumber != null) {
        return entry.chapterNumber! > 0;
      }
      return false;
    }
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
