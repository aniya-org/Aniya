import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/data/datasources/external_remote_data_source.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/domain/entities/entities.dart';
import '../../../../core/domain/entities/source_entity.dart';
import '../../../../core/enums/tracking_service.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/utils/logger.dart';
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

  const AnimeMangaDetailsScreen({required this.media, super.key});

  @override
  State<AnimeMangaDetailsScreen> createState() =>
      _AnimeMangaDetailsScreenState();
}

class _AnimeMangaDetailsScreenState extends State<AnimeMangaDetailsScreen>
    with SingleTickerProviderStateMixin {
  late final ExternalRemoteDataSource _dataSource;
  late final AuthViewModel _authViewModel;
  late TabController _tabController;

  MediaDetailsEntity? _fullDetails;
  bool _isLoading = true;
  bool _hasError = false;

  // Provider attribution
  List<String> _contributingProviders = [];
  Map<String, String>? _dataSourceAttribution;
  Map<String, double>? _matchConfidences;

  // Episodes state
  List<EpisodeEntity> _episodes = [];
  bool _isLoadingEpisodes = false;
  bool _isEpisodePagingEnabled = false;
  bool _isLoadingMoreEpisodes = false;
  int? _nextEpisodeOffset;
  String? _episodePagingProviderId;
  String? _episodePagingProviderMediaId;

  // Chapters state
  List<ChapterEntity> _chapters = [];
  bool _isLoadingChapters = false;

  @override
  void initState() {
    super.initState();
    _dataSource = sl<ExternalRemoteDataSource>();
    _authViewModel = sl<AuthViewModel>();
    // 3 tabs for Anime/Manga (Overview, Episodes/Chapters, More Info)
    final isAnime = widget.media.type == MediaType.anime;
    _tabController = TabController(length: 3, vsync: this);
    _initializeAttributionFromMedia(widget.media);
    _fetchFullDetails();
    if (isAnime) {
      _fetchEpisodes();
    } else {
      _fetchChapters();
    }
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
      final result = await _dataSource.getMediaDetails(
        widget.media.id,
        widget.media.sourceId,
        widget.media.type,
      );

      if (mounted) {
        setState(() {
          _fullDetails = result;
          _isLoading = false;
          _updateProviderAttribution(result);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchEpisodes() async {
    if (widget.media.type != MediaType.anime) return;

    setState(() {
      _isLoadingEpisodes = true;
    });

    final shouldPaginate = _shouldPaginateEpisodes(widget.media);

    if (shouldPaginate) {
      final success = await _fetchEpisodePage(offset: 0, append: false);
      if (!success) {
        await _fetchEpisodesAggregated();
      }
    } else {
      await _fetchEpisodesAggregated();
    }
  }

  Future<void> _fetchEpisodesAggregated() async {
    try {
      final episodes = await _dataSource.getEpisodes(widget.media);
      if (mounted) {
        setState(() {
          _episodes = episodes;
          _isLoadingEpisodes = false;
          _isEpisodePagingEnabled = false;
          _nextEpisodeOffset = null;
          _episodePagingProviderId = null;
          _episodePagingProviderMediaId = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingEpisodes = false;
          _isEpisodePagingEnabled = false;
        });
      }
    }
  }

  Future<bool> _fetchEpisodePage({
    required int offset,
    required bool append,
  }) async {
    try {
      final request = EpisodePageRequest(
        media: widget.media,
        offset: offset,
        providerId: _episodePagingProviderId,
        providerMediaId: _episodePagingProviderMediaId,
      );

      final pageResult = await _dataSource.getEpisodePage(request);
      if (!mounted) return false;

      setState(() {
        _isEpisodePagingEnabled = true;
        if (append) {
          _episodes = [..._episodes, ...pageResult.episodes];
          _isLoadingMoreEpisodes = false;
        } else {
          _episodes = pageResult.episodes;
          _isLoadingEpisodes = false;
        }
        _nextEpisodeOffset = pageResult.nextOffset;
        _episodePagingProviderId = pageResult.providerId;
        _episodePagingProviderMediaId = pageResult.providerMediaId;
      });

      return true;
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to fetch episode page',
        error: e,
        stackTrace: stackTrace,
      );
      if (!mounted) return false;
      setState(() {
        if (append) {
          _isLoadingMoreEpisodes = false;
        } else {
          _isLoadingEpisodes = false;
        }
      });
      return false;
    }
  }

  Future<void> _fetchMoreEpisodes() async {
    if (!_isEpisodePagingEnabled || _isLoadingMoreEpisodes) return;
    final nextOffset = _nextEpisodeOffset;
    if (nextOffset == null) return;

    setState(() {
      _isLoadingMoreEpisodes = true;
    });

    final success = await _fetchEpisodePage(offset: nextOffset, append: true);
    if (!success && mounted) {
      setState(() {
        _isEpisodePagingEnabled = false;
      });
    }
  }

  bool _handleEpisodesScrollNotification(ScrollNotification notification) {
    if (!_isEpisodePagingEnabled || _isLoadingMoreEpisodes) {
      return false;
    }

    final metrics = notification.metrics;
    if (!metrics.outOfRange &&
        metrics.pixels >= metrics.maxScrollExtent - 200) {
      _fetchMoreEpisodes();
    }

    return false;
  }

  bool _shouldPaginateEpisodes(MediaEntity media) {
    final title = media.title.toLowerCase();
    final seasonPattern = RegExp(
      r'(season|part|cour|chapter)\s*(\d+|[ivx]+)',
      caseSensitive: false,
    );
    final ordinalPattern = RegExp(
      r'\b(2nd|3rd|4th|second|third|fourth)\b',
      caseSensitive: false,
    );
    final isExplicitSeason =
        seasonPattern.hasMatch(title) || ordinalPattern.hasMatch(title);

    final totalEpisodes = _fullDetails?.episodes ?? media.totalEpisodes;
    final isLongRunning =
        (totalEpisodes ?? 0) == 0 || (totalEpisodes ?? 0) > 100;

    return isLongRunning && !isExplicitSeason;
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
        return 'Jikan';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use full details if available, otherwise fallback to initial data
    final title = _fullDetails?.title ?? widget.media.title;
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
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            // 1. Sliver App Bar with Backdrop and Gradient
            SliverAppBar(
              expandedHeight: 400,
              pinned: true,
              stretch: true,
              backgroundColor: Theme.of(context).colorScheme.surface,
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
                                  title,
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
                            onPressed: () {
                              // TODO: Implement Add to Library
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Add to Library'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              // TODO: Implement Custom List
                            },
                            icon: const Icon(Icons.playlist_add),
                            label: const Text('Custom List'),
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

    if (_episodes.isEmpty) {
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

    return NotificationListener<ScrollNotification>(
      onNotification: _handleEpisodesScrollNotification,
      child: CustomScrollView(
        key: const PageStorageKey<String>('episodes'),
        slivers: [
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
                              episode.thumbnail != null
                                  ? Image.network(
                                      episode.thumbnail!,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              Container(
                                                color: Colors.grey[800],
                                                child: const Icon(
                                                  Icons.image_not_supported,
                                                ),
                                              ),
                                    )
                                  : Container(
                                      color: Colors.grey[800],
                                      child: const Icon(Icons.tv),
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
                      ],
                    ),
                  ),
                );
              }, childCount: _episodes.length),
            ),
          ),
          if (_isEpisodePagingEnabled)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: _isLoadingMoreEpisodes
                      ? const CircularProgressIndicator()
                      : _nextEpisodeOffset != null
                      ? const SizedBox.shrink()
                      : const Text('All episodes loaded'),
                ),
              ),
            ),
        ],
      ),
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
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    child: Text(
                      '${chapter.number.toInt()}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
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
                          DateFormat('MMM d, y').format(chapter.releaseDate!),
                        )
                      : null,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    _showChapterSourceSelection(context, chapter);
                  },
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
    EpisodeEntity episode,
  ) {
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
    List<SourceEntity> allSources,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen.fromSourceSelection(
          media: widget.media,
          episode: episode,
          source: source,
          allSources: allSources,
        ),
      ),
    );
  }

  /// Show chapter source selection bottom sheet
  /// Requirements: 1.2
  void _showChapterSourceSelection(
    BuildContext context,
    ChapterEntity chapter,
  ) {
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
            _navigateToMangaReader(context, chapter, selection);
          },
        );
      },
    );
  }

  /// Navigate to manga/novel reader after selecting a source for a chapter
  void _navigateToMangaReader(
    BuildContext context,
    ChapterEntity chapter,
    SourceSelectionResult selection,
  ) {
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
          ),
        ),
      );
    }
  }
}

// Custom delegate for pinned tab bar
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
