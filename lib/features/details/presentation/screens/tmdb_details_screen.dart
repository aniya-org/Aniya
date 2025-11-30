import 'package:flutter/material.dart';
import '../../../../core/services/tmdb_service.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/cross_provider_matcher.dart';
import '../../../../core/utils/data_aggregator.dart';
import '../../../../core/utils/provider_cache.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/domain/entities/media_entity.dart';
import '../../../../core/domain/entities/media_details_entity.dart';
import '../../../../core/domain/entities/episode_entity.dart';
import '../../../../core/domain/entities/source_entity.dart';
import '../../../../core/data/datasources/external_remote_data_source.dart';
import '../../../../core/widgets/provider_badge.dart';
import '../../../../core/widgets/provider_attribution_dialog.dart';
import '../../../media_details/presentation/screens/episode_source_selection_sheet.dart';
import '../../../video_player/presentation/screens/video_player_screen.dart';

/// Details screen for TMDB movies and TV shows
class TmdbDetailsScreen extends StatefulWidget {
  final Map tmdbData;
  final bool isMovie;

  const TmdbDetailsScreen({
    required this.tmdbData,
    required this.isMovie,
    super.key,
  });

  @override
  State<TmdbDetailsScreen> createState() => _TmdbDetailsScreenState();
}

class _TmdbDetailsScreenState extends State<TmdbDetailsScreen>
    with SingleTickerProviderStateMixin {
  late final TmdbService _tmdbService;
  late final CrossProviderMatcher _matcher;
  late final DataAggregator _aggregator;
  late final ProviderCache _cache;
  late final ExternalRemoteDataSource _externalDataSource;
  late TabController _tabController;

  Map? _fullDetails;
  bool _isLoading = true;
  bool _hasError = false;

  // Season & Episode State
  int _selectedSeason = 1;
  Map? _seasonDetails;
  bool _isLoadingSeason = false;

  // Cross-provider aggregation state
  Map<String, ProviderMatch>? _providerMatches;
  List<EpisodeEntity>? _aggregatedEpisodes;
  bool _isAggregating = false;
  List<String> _contributingProviders = [];

  @override
  void initState() {
    super.initState();
    _tmdbService = sl<TmdbService>();
    _matcher = sl<CrossProviderMatcher>();
    _aggregator = sl<DataAggregator>();
    _cache = sl<ProviderCache>();
    _externalDataSource = sl<ExternalRemoteDataSource>();
    // 3 tabs for TV Shows (Overview, Episodes, More Info), 2 for Movies
    _tabController = TabController(length: widget.isMovie ? 2 : 3, vsync: this);
    _fetchFullDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchFullDetails() async {
    try {
      final id = widget.tmdbData['id'];
      final appendToResponse = 'credits,videos,recommendations,similar';

      final result = widget.isMovie
          ? await _tmdbService.getMovieDetails(
              id,
              appendToResponse: appendToResponse,
            )
          : await _tmdbService.getTVShowDetails(
              id,
              appendToResponse: appendToResponse,
            );

      if (mounted) {
        setState(() {
          _fullDetails = result;
          _isLoading = false;
        });
      }

      // Start cross-provider matching and aggregation for all metadata
      if (mounted) {
        await _performCrossProviderMatching();
      }

      // If TV show, fetch season 1 details by default
      if (!widget.isMovie && mounted) {
        // Check if season 1 exists in the seasons list
        final seasons = (result['seasons'] as List?) ?? [];
        if (seasons.any((s) => s['season_number'] == 1)) {
          _fetchSeasonDetails(id, 1);
        } else if (seasons.isNotEmpty) {
          // Fallback to the first available season if season 1 is missing (e.g. specials only)
          _fetchSeasonDetails(id, seasons.first['season_number']);
        }
      }
    } catch (e) {
      Logger.error('Error fetching TMDB details', error: e);
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  /// Perform cross-provider matching to find this media in anime/manga databases
  /// and aggregate all metadata from all providers
  Future<void> _performCrossProviderMatching() async {
    if (_fullDetails == null) return;

    setState(() {
      _isAggregating = true;
    });

    try {
      final title = widget.isMovie
          ? (_fullDetails!['title'] as String? ?? '')
          : (_fullDetails!['name'] as String? ?? '');

      final releaseYear = widget.isMovie
          ? _extractYear(_fullDetails!['release_date'] as String?)
          : _extractYear(_fullDetails!['first_air_date'] as String?);

      Logger.info(
        'Searching for TMDB media "$title" across all providers for full aggregation',
      );

      // Search all providers (anime/manga and other sources) for matching content
      final matches = await _matcher.findMatches(
        title: title,
        type: widget.isMovie ? MediaType.movie : MediaType.tvShow,
        primarySourceId: 'tmdb',
        year: releaseYear,
        searchFunction: _searchProvider,
        cache: _cache,
      );

      if (matches.isNotEmpty) {
        Logger.info(
          'Found ${matches.length} matches for TMDB media: ${matches.keys.join(", ")}',
        );

        // Convert TMDB data to MediaDetailsEntity for aggregation
        final tmdbDetails = _convertTmdbToMediaDetails(_fullDetails!);

        // Aggregate full media details from all matched providers
        final aggregatedDetails = await _aggregator.aggregateMediaDetails(
          primaryDetails: tmdbDetails,
          matches: matches,
          detailsFetcher: _fetchDetailsFromProvider,
        );

        // Update full details with aggregated data
        if (mounted) {
          setState(() {
            // Merge aggregated data back into _fullDetails map for display
            _mergeAggregatedDetailsIntoMap(aggregatedDetails);
            _providerMatches = matches;
            _contributingProviders =
                aggregatedDetails.contributingProviders ??
                ['tmdb', ...matches.keys];
            _isAggregating = false;
          });
        }

        // If TV show, try to aggregate episode data
        if (!widget.isMovie) {
          await _aggregateEpisodeData(matches);
        }
      } else {
        Logger.info('No high-confidence matches found for TMDB media');
        if (mounted) {
          setState(() {
            _contributingProviders = ['tmdb'];
            _isAggregating = false;
          });
        }
      }
    } catch (e) {
      Logger.error('Error performing cross-provider matching', error: e);
      if (mounted) {
        setState(() {
          _contributingProviders = ['tmdb'];
          _isAggregating = false;
        });
      }
    }
  }

  /// Convert TMDB data map to MediaDetailsEntity
  MediaDetailsEntity _convertTmdbToMediaDetails(Map tmdbData) {
    final title = widget.isMovie
        ? (tmdbData['title'] as String? ?? '')
        : (tmdbData['name'] as String? ?? '');
    final overview = tmdbData['overview'] as String?;
    final posterPath = tmdbData['poster_path'] as String?;
    final backdropPath = tmdbData['backdrop_path'] as String?;
    final voteAverage = (tmdbData['vote_average'] as num?)?.toDouble();
    final popularity = (tmdbData['popularity'] as num?)?.toInt();
    final releaseDate = widget.isMovie
        ? (tmdbData['release_date'] as String?)
        : (tmdbData['first_air_date'] as String?);
    final genres =
        (tmdbData['genres'] as List?)
            ?.map((g) => g['name'] as String)
            .toList() ??
        [];
    final runtime = widget.isMovie
        ? (tmdbData['runtime'] as int?)
        : (tmdbData['episode_run_time'] as List?)?.firstOrNull as int?;
    final status = tmdbData['status'] as String?;
    final numberOfEpisodes = tmdbData['number_of_episodes'] as int?;

    // Parse dates
    DateTime? startDate;
    DateTime? endDate;
    if (releaseDate != null && releaseDate.isNotEmpty) {
      startDate = DateTime.tryParse(releaseDate);
    }
    final endDateStr = widget.isMovie
        ? (tmdbData['release_date'] as String?)
        : (tmdbData['last_air_date'] as String?);
    if (endDateStr != null && endDateStr.isNotEmpty) {
      endDate = DateTime.tryParse(endDateStr);
    }

    // Convert cast to characters
    final cast = (tmdbData['credits']?['cast'] as List?)?.take(20).map((c) {
      return CharacterEntity(
        id: c['id'].toString(),
        name: c['name'] ?? 'Unknown',
        nativeName: null,
        image: c['profile_path'] != null
            ? TmdbService.getProfileUrl(c['profile_path'])
            : null,
        role: c['character'] ?? 'Actor',
      );
    }).toList();

    // Convert crew to staff
    final crew = (tmdbData['credits']?['crew'] as List?)?.take(20).map((c) {
      return StaffEntity(
        id: c['id'].toString(),
        name: c['name'] ?? 'Unknown',
        nativeName: null,
        image: c['profile_path'] != null
            ? TmdbService.getProfileUrl(c['profile_path'])
            : null,
        role: c['job'] ?? 'Crew',
      );
    }).toList();

    // Convert recommendations
    final recommendations = (tmdbData['recommendations']?['results'] as List?)
        ?.take(10)
        .map((r) {
          return RecommendationEntity(
            id: r['id'].toString(),
            title: r['title'] ?? r['name'] ?? 'Unknown',
            englishTitle: null,
            romajiTitle: null,
            coverImage: r['poster_path'] != null
                ? TmdbService.getPosterUrl(r['poster_path'])
                : '',
            rating: 0,
          );
        })
        .toList();

    // Convert trailer
    TrailerEntity? trailer;
    final videos = (tmdbData['videos']?['results'] as List?);
    if (videos != null) {
      final trailerVideo = videos.firstWhere(
        (v) => v['type'] == 'Trailer' && v['site'] == 'YouTube',
        orElse: () => null,
      );
      if (trailerVideo != null) {
        trailer = TrailerEntity(id: trailerVideo['key'] ?? '', site: 'youtube');
      }
    }

    return MediaDetailsEntity(
      id: tmdbData['id'].toString(),
      title: title,
      englishTitle: null,
      romajiTitle: null,
      nativeTitle: null,
      coverImage: posterPath != null
          ? TmdbService.getPosterUrl(posterPath)
          : '',
      bannerImage: backdropPath != null
          ? TmdbService.getBackdropUrl(backdropPath)
          : null,
      description: overview,
      type: widget.isMovie ? MediaType.movie : MediaType.tvShow,
      status: _mapTmdbStatus(status),
      rating: voteAverage != null
          ? voteAverage * 10
          : null, // Convert 0-10 to 0-100
      averageScore: voteAverage != null ? (voteAverage * 10).toInt() : null,
      meanScore: null,
      popularity: popularity,
      favorites: null,
      genres: genres,
      tags: [],
      startDate: startDate,
      endDate: endDate,
      episodes: numberOfEpisodes,
      chapters: null,
      volumes: null,
      duration: runtime,
      season: null,
      seasonYear: startDate?.year,
      isAdult: false,
      siteUrl: null,
      sourceId: 'tmdb',
      sourceName: 'TMDB',
      characters: cast,
      staff: crew,
      reviews: null,
      recommendations: recommendations,
      relations: null,
      studios: null,
      rankings: null,
      trailer: trailer,
    );
  }

  /// Map TMDB status to MediaStatus
  MediaStatus _mapTmdbStatus(String? status) {
    if (status == null) return MediaStatus.upcoming;
    switch (status.toLowerCase()) {
      case 'released':
      case 'ended':
        return MediaStatus.completed;
      case 'returning series':
        return MediaStatus.ongoing;
      default:
        return MediaStatus.upcoming;
    }
  }

  /// Merge aggregated MediaDetailsEntity back into TMDB map for display
  void _mergeAggregatedDetailsIntoMap(MediaDetailsEntity aggregated) {
    if (_fullDetails == null) return;

    // Update fields with aggregated data (highest quality, highest values)
    _fullDetails = Map.from(_fullDetails!);

    // Update description if aggregated one is longer/more complete
    if (aggregated.description != null &&
        aggregated.description!.isNotEmpty &&
        (_fullDetails!['overview'] == null ||
            aggregated.description!.length >
                (_fullDetails!['overview'] as String).length)) {
      _fullDetails!['overview'] = aggregated.description;
    }

    // Update rating if aggregated is higher
    final currentRating = (_fullDetails!['vote_average'] as num?)?.toDouble();
    if (aggregated.rating != null &&
        (currentRating == null || (aggregated.rating! / 10) > currentRating)) {
      _fullDetails!['vote_average'] = aggregated.rating! / 10;
    }

    // Update popularity if aggregated is higher
    if (aggregated.popularity != null &&
        (_fullDetails!['popularity'] == null ||
            aggregated.popularity! >
                (_fullDetails!['popularity'] as num).toInt())) {
      _fullDetails!['popularity'] = aggregated.popularity;
    }

    // Merge genres (deduplicate)
    final existingGenres = ((_fullDetails!['genres'] as List?) ?? [])
        .map((g) => g['name'] as String)
        .toSet();
    existingGenres.addAll(aggregated.genres);
    _fullDetails!['genres'] = existingGenres
        .map((g) => {'name': g, 'id': 0})
        .toList();

    // Update episode count if aggregated is higher (for TV shows)
    if (!widget.isMovie && aggregated.episodes != null) {
      final currentEpisodes = _fullDetails!['number_of_episodes'] as int?;
      if (currentEpisodes == null || aggregated.episodes! > currentEpisodes) {
        _fullDetails!['number_of_episodes'] = aggregated.episodes;
      }
    }

    // Merge characters (cast)
    if (aggregated.characters != null && aggregated.characters!.isNotEmpty) {
      final existingCast = (_fullDetails!['credits']?['cast'] as List?) ?? [];
      final castMap = <String, dynamic>{};
      for (final cast in existingCast) {
        castMap[cast['id'].toString()] = cast;
      }
      // Add new characters from aggregated data
      for (final character in aggregated.characters!) {
        if (!castMap.containsKey(character.id)) {
          existingCast.add({
            'id': int.tryParse(character.id) ?? 0,
            'name': character.name,
            'character': character.role,
            'profile_path': character.image?.replaceFirst(
              'https://image.tmdb.org/t/p/w500',
              '',
            ),
          });
        }
      }
      if (_fullDetails!['credits'] == null) {
        _fullDetails!['credits'] = {};
      }
      _fullDetails!['credits']['cast'] = existingCast;
    }

    // Merge staff (crew)
    if (aggregated.staff != null && aggregated.staff!.isNotEmpty) {
      final existingCrew = (_fullDetails!['credits']?['crew'] as List?) ?? [];
      final crewMap = <String, dynamic>{};
      for (final crew in existingCrew) {
        crewMap['${crew['id']}_${crew['job']}'] = crew;
      }
      // Add new staff from aggregated data
      for (final staff in aggregated.staff!) {
        final key = '${staff.id}_${staff.role}';
        if (!crewMap.containsKey(key)) {
          existingCrew.add({
            'id': int.tryParse(staff.id) ?? 0,
            'name': staff.name,
            'job': staff.role,
            'profile_path': staff.image?.replaceFirst(
              'https://image.tmdb.org/t/p/w500',
              '',
            ),
          });
        }
      }
      if (_fullDetails!['credits'] == null) {
        _fullDetails!['credits'] = {};
      }
      _fullDetails!['credits']['crew'] = existingCrew;
    }

    // Merge recommendations
    if (aggregated.recommendations != null &&
        aggregated.recommendations!.isNotEmpty) {
      final existingRecs =
          (_fullDetails!['recommendations']?['results'] as List?) ?? [];
      final recsMap = <String, dynamic>{};
      for (final rec in existingRecs) {
        recsMap[rec['id'].toString()] = rec;
      }
      // Add new recommendations from aggregated data
      for (final rec in aggregated.recommendations!) {
        if (!recsMap.containsKey(rec.id)) {
          existingRecs.add({
            'id': int.tryParse(rec.id) ?? 0,
            'title': rec.title,
            'name': rec.title,
            'poster_path': rec.coverImage.replaceFirst(
              'https://image.tmdb.org/t/p/w500',
              '',
            ),
          });
        }
      }
      if (_fullDetails!['recommendations'] == null) {
        _fullDetails!['recommendations'] = {};
      }
      _fullDetails!['recommendations']['results'] = existingRecs;
    }
  }

  /// Fetch media details from a specific provider
  Future<MediaDetailsEntity> _fetchDetailsFromProvider(
    String mediaId,
    String providerId,
  ) async {
    try {
      return await _externalDataSource.getMediaDetails(
        mediaId,
        providerId,
        widget.isMovie ? MediaType.movie : MediaType.tvShow,
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
        type: widget.isMovie ? MediaType.movie : MediaType.tvShow,
        genres: [],
        tags: [],
        sourceId: providerId,
        sourceName: providerId,
      );
    }
  }

  /// Search a specific provider for matching media
  Future<List<MediaEntity>> _searchProvider(
    String query,
    String providerId,
    MediaType type,
  ) async {
    try {
      // Only search anime/manga providers (not TMDB itself)
      if (providerId.toLowerCase() == 'tmdb') {
        return [];
      }

      // Map media types for cross-provider searching
      // TMDB TV shows should search anime providers as anime type
      // TMDB movies should also search anime providers as anime type (some anime are movies)
      MediaType searchType = type;
      if ((type == MediaType.tvShow || type == MediaType.movie) &&
          (providerId.toLowerCase() == 'anilist' ||
              providerId.toLowerCase() == 'jikan' ||
              providerId.toLowerCase() == 'kitsu' ||
              providerId.toLowerCase() == 'mal' ||
              providerId.toLowerCase() == 'myanimelist')) {
        searchType = MediaType.anime;
      }

      final results = await _externalDataSource.searchMedia(
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

  /// Aggregate episode data from matched providers
  Future<void> _aggregateEpisodeData(Map<String, ProviderMatch> matches) async {
    try {
      // Create a MediaEntity for the TMDB media
      final tmdbMedia = MediaEntity(
        id: widget.tmdbData['id'].toString(),
        title: _fullDetails!['name'] as String? ?? '',
        coverImage: _fullDetails!['poster_path'] as String? ?? '',
        type: MediaType.tvShow,
        genres: [],
        status: MediaStatus.ongoing,
        sourceId: 'tmdb',
        sourceName: 'TMDB',
      );

      // Aggregate episodes from all matched providers
      final aggregatedEpisodes = await _aggregator.aggregateEpisodes(
        primaryMedia: tmdbMedia,
        matches: matches,
        episodeFetcher: _fetchEpisodesFromProvider,
      );

      if (aggregatedEpisodes.isNotEmpty) {
        Logger.info(
          'Aggregated ${aggregatedEpisodes.length} episodes from ${matches.length + 1} providers',
        );

        if (mounted) {
          setState(() {
            _aggregatedEpisodes = aggregatedEpisodes;
          });
        }
      }
    } catch (e) {
      Logger.error('Error aggregating episode data', error: e);
    }
  }

  /// Fetch episodes from a specific provider
  Future<List<EpisodeEntity>> _fetchEpisodesFromProvider(
    String mediaId,
    String providerId,
  ) async {
    try {
      if (providerId.toLowerCase() == 'tmdb') {
        // For TMDB, we don't have a direct episode fetcher
        // Episodes come from season details
        return [];
      }

      // Create a MediaEntity for the episode fetch
      final media = MediaEntity(
        id: mediaId,
        title: '', // Title not needed for episode fetch
        coverImage: '',
        type: MediaType.tvShow,
        genres: [],
        status: MediaStatus.ongoing,
        sourceId: providerId,
        sourceName: providerId,
      );

      final episodes = await _externalDataSource.getEpisodes(media);

      return episodes;
    } catch (e) {
      Logger.error(
        'Error fetching episodes from provider $providerId',
        error: e,
      );
      return [];
    }
  }

  /// Extract year from date string (YYYY-MM-DD format)
  int? _extractYear(String? dateString) {
    if (dateString == null || dateString.isEmpty) return null;
    try {
      return int.parse(dateString.split('-').first);
    } catch (e) {
      return null;
    }
  }

  /// Format DateTime to readable string
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _fetchSeasonDetails(int tvId, int seasonNumber) async {
    if (mounted) {
      setState(() {
        _isLoadingSeason = true;
        _selectedSeason = seasonNumber;
      });
    }

    try {
      final result = await _tmdbService.getTVShowSeasonDetails(
        tvId,
        seasonNumber,
      );
      if (mounted) {
        setState(() {
          _seasonDetails = result;
          _isLoadingSeason = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSeason = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use full details if available, otherwise fallback to initial data
    final data = _fullDetails ?? widget.tmdbData;

    final String title = widget.isMovie
        ? (data['title'] as String? ?? 'Unknown')
        : (data['name'] as String? ?? 'Unknown');
    final String? backdropPath = data['backdrop_path'] as String?;
    final String? posterPath = data['poster_path'] as String?;
    final String? overview = data['overview'] as String?;
    final double rating = (data['vote_average'] as num?)?.toDouble() ?? 0.0;
    final String status = data['status'] as String? ?? 'Unknown';

    // Extract genres
    final List genres = data['genres'] as List? ?? [];
    final List<String> genreNames = genres
        .map((g) => g['name'] as String)
        .toList();

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
              titleSpacing: 0,
              title: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: innerBoxIsScrolled ? 1 : 0,
                child: Text(
                  title,
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
                    if (backdropPath != null)
                      Image.network(
                        TmdbService.getBackdropUrl(backdropPath),
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
                            tag: 'poster_${data['id']}',
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
                                child: posterPath != null
                                    ? Image.network(
                                        TmdbService.getPosterUrl(posterPath),
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        color: Colors.grey[800],
                                        child: const Icon(
                                          Icons.movie,
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
                                        status,
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
                                      rating.toStringAsFixed(1),
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
                    // Provider attribution badges
                    if (_contributingProviders.isNotEmpty &&
                        _contributingProviders.length > 1) ...[
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
                                if (_isAggregating) ...[
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            ProviderBadgeList(
                              providers: _contributingProviders,
                              onProviderTap: (provider) {
                                _showProviderAttributionDialog(provider);
                              },
                              isSmall: false,
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
                    if (!widget.isMovie) const Tab(text: 'Episodes'),
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
                  _buildOverviewTab(data, genreNames, overview),

                  // Episodes Tab (TV Only)
                  if (!widget.isMovie) _buildEpisodesTab(data),

                  // More Info Tab
                  _buildMoreInfoTab(data),
                ],
              ),
      ),
    );
  }

  Widget _buildOverviewTab(Map data, List<String> genres, String? overview) {
    final recommendations =
        (data['recommendations']?['results'] as List?) ?? [];
    final similar = (data['similar']?['results'] as List?) ?? [];
    final relatedContent = [...recommendations, ...similar].take(10).toList();

    return Builder(
      builder: (context) {
        return CustomScrollView(
          key: const PageStorageKey<String>('overview'),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats Grid
                    _buildStatsGrid(context, data),
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
                      overview ?? 'No description available.',
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
                    if (relatedContent.isNotEmpty) ...[
                      Text(
                        'You might also like',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 200,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: relatedContent.length,
                          itemBuilder: (context, index) {
                            final item = relatedContent[index];
                            final posterPath = item['poster_path'];
                            return Container(
                              width: 120,
                              margin: const EdgeInsets.only(right: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: posterPath != null
                                          ? Image.network(
                                              TmdbService.getPosterUrl(
                                                posterPath,
                                              ),
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                            )
                                          : Container(
                                              color: Colors.grey[800],
                                              child: const Icon(Icons.movie),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item['title'] ?? item['name'] ?? 'Unknown',
                                    maxLines: 2,
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

  Widget _buildEpisodesTab(Map data) {
    final seasons = (data['seasons'] as List?) ?? [];
    final tmdbEpisodes = (_seasonDetails?['episodes'] as List?) ?? [];

    // Use aggregated episodes if available, otherwise use TMDB episodes
    final hasAggregatedEpisodes =
        _aggregatedEpisodes != null && _aggregatedEpisodes!.isNotEmpty;

    return Builder(
      builder: (context) {
        return CustomScrollView(
          key: const PageStorageKey<String>('episodes'),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  // Season Selector
                  Container(
                    height: 60,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: seasons.length,
                      itemBuilder: (context, index) {
                        final season = seasons[index];
                        final seasonNum = season['season_number'];
                        final isSelected = seasonNum == _selectedSeason;

                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(season['name'] ?? 'Season $seasonNum'),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                _fetchSeasonDetails(data['id'], seasonNum);
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  // Show info banner if using aggregated data
                  if (hasAggregatedEpisodes)
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Showing enhanced episode data from multiple sources',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Episodes List
            if (_isLoadingSeason)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (hasAggregatedEpisodes)
              // Show aggregated episodes
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final episode = _aggregatedEpisodes![index];
                  return _buildAggregatedEpisodeCard(episode);
                }, childCount: _aggregatedEpisodes!.length),
              )
            else
              // Show TMDB episodes
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final episode = tmdbEpisodes[index];
                  return _buildTmdbEpisodeCard(episode);
                }, childCount: tmdbEpisodes.length),
              ),
          ],
        );
      },
    );
  }

  Widget _buildAggregatedEpisodeCard(EpisodeEntity episode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GestureDetector(
        onTap: () => _showEpisodeSourceSelectionForAggregated(episode),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Episode Image
              if (episode.thumbnail != null && episode.thumbnail!.isNotEmpty)
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    episode.thumbnail!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[800],
                      child: const Icon(Icons.tv, size: 48),
                    ),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'EP ${episode.number}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            episode.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (episode.releaseDate != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _formatDate(episode.releaseDate!),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    // Show source provider badge if available
                    if (episode.sourceProvider != null &&
                        episode.sourceProvider!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.source,
                            size: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Source: ',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          ProviderBadge(
                            providerId: episode.sourceProvider!,
                            isSmall: true,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTmdbEpisodeCard(Map episode) {
    final stillPath = episode['still_path'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GestureDetector(
        onTap: () => _showEpisodeSourceSelection(episode),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Episode Image
              if (stillPath != null)
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    TmdbService.getBackdropUrl(stillPath),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[800],
                      child: const Icon(Icons.tv, size: 48),
                    ),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'EP ${episode['episode_number']}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            episode['name'] ?? 'Unknown',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      episode['overview'] ?? 'No description available.',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      episode['air_date'] ?? '',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoreInfoTab(Map data) {
    final cast = (data['credits']?['cast'] as List?)?.take(10).toList() ?? [];
    final crew = (data['credits']?['crew'] as List?)?.take(5).toList() ?? [];
    final videos = (data['videos']?['results'] as List?) ?? [];

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
                    // Cast
                    if (cast.isNotEmpty) ...[
                      Text(
                        'Cast',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 160,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: cast.length,
                          itemBuilder: (context, index) {
                            final person = cast[index];
                            final profilePath = person['profile_path'];
                            return Container(
                              width: 100,
                              margin: const EdgeInsets.only(right: 12),
                              child: Column(
                                children: [
                                  CircleAvatar(
                                    radius: 40,
                                    backgroundImage: profilePath != null
                                        ? NetworkImage(
                                            TmdbService.getProfileUrl(
                                              profilePath,
                                            ),
                                          )
                                        : null,
                                    child: profilePath == null
                                        ? const Icon(Icons.person)
                                        : null,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    person['name'] ?? 'Unknown',
                                    maxLines: 2,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    person['character'] ?? '',
                                    maxLines: 2,
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

                    // Crew
                    if (crew.isNotEmpty) ...[
                      Text(
                        'Crew',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: crew
                            .map(
                              (person) => SizedBox(
                                width: 150,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      person['name'] ?? 'Unknown',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      person['job'] ?? 'Unknown',
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

                    // Videos
                    if (videos.isNotEmpty) ...[
                      Text(
                        'Videos',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...videos.map(
                        (video) => Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: const Icon(
                              Icons.play_circle_outline,
                              size: 40,
                            ),
                            title: Text(video['name'] ?? 'Unknown'),
                            subtitle: Text(video['type'] ?? 'Video'),
                            onTap: () {
                              // TODO: Play video
                            },
                          ),
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

  Widget _buildStatsGrid(BuildContext context, Map data) {
    final releaseDate = widget.isMovie
        ? (data['release_date'] as String?)
        : (data['first_air_date'] as String?);

    final runtime = widget.isMovie
        ? (data['runtime'] as int?)
        : (data['episode_run_time'] as List?)?.firstOrNull as int?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          _buildStatRow(context, 'Type', widget.isMovie ? 'Movie' : 'TV Show'),
          if (releaseDate != null)
            _buildStatRow(context, 'Release Date', releaseDate),
          if (runtime != null)
            _buildStatRow(context, 'Duration', '${runtime}m'),
          _buildStatRow(
            context,
            'Popularity',
            (data['popularity'] as num?)?.toStringAsFixed(0) ?? 'N/A',
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Show episode source selection sheet for TMDB episode
  /// Requirements: 1.1
  void _showEpisodeSourceSelection(Map tmdbEpisode) {
    final episodeNumber = tmdbEpisode['episode_number'] as int? ?? 0;
    final episodeName = tmdbEpisode['name'] as String? ?? 'Unknown';
    final airDate = tmdbEpisode['air_date'] as String?;

    // Create an EpisodeEntity from the TMDB episode data
    final episode = EpisodeEntity(
      id: '${_selectedSeason}_${episodeNumber}',
      mediaId: widget.tmdbData['id'].toString(),
      number: episodeNumber,
      title: episodeName,
      releaseDate: airDate != null ? DateTime.tryParse(airDate) : null,
      thumbnail: tmdbEpisode['still_path'] != null
          ? TmdbService.getBackdropUrl(tmdbEpisode['still_path'])
          : null,
      sourceProvider: 'tmdb',
    );

    // Create a MediaEntity from the TMDB data
    final media = MediaEntity(
      id: widget.tmdbData['id'].toString(),
      title: _fullDetails?['name'] as String? ?? 'Unknown',
      coverImage: _fullDetails?['poster_path'] as String? ?? '',
      type: MediaType.tvShow,
      genres: [],
      status: MediaStatus.ongoing,
      sourceId: 'tmdb',
      sourceName: 'TMDB',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => EpisodeSourceSelectionSheet(
        media: media,
        episode: episode,
        isChapter: false,
        onSourceSelected: (selection) {
          _navigateToVideoPlayer(
            media,
            episode,
            selection.source,
            selection.allSources,
          );
        },
      ),
    );
  }

  /// Show episode source selection sheet for aggregated episode
  /// Requirements: 1.1
  void _showEpisodeSourceSelectionForAggregated(EpisodeEntity episode) {
    // Create a MediaEntity from the TMDB data
    final media = MediaEntity(
      id: widget.tmdbData['id'].toString(),
      title: _fullDetails?['name'] as String? ?? 'Unknown',
      coverImage: _fullDetails?['poster_path'] as String? ?? '',
      type: MediaType.tvShow,
      genres: [],
      status: MediaStatus.ongoing,
      sourceId: 'tmdb',
      sourceName: 'TMDB',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => EpisodeSourceSelectionSheet(
        media: media,
        episode: episode,
        isChapter: false,
        onSourceSelected: (selection) {
          _navigateToVideoPlayer(
            media,
            episode,
            selection.source,
            selection.allSources,
          );
        },
      ),
    );
  }

  /// Navigate to video player with selected source
  /// Requirements: 5.1, 5.3
  void _navigateToVideoPlayer(
    MediaEntity media,
    EpisodeEntity episode,
    SourceEntity source,
    List<SourceEntity> allSources,
  ) {
    Logger.info(
      'Navigating to video player for episode ${episode.number} with source ${source.name}',
      tag: 'TmdbDetailsScreen',
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen.fromSourceSelection(
          media: media,
          episode: episode,
          source: source,
          allSources: allSources,
        ),
      ),
    );
  }

  /// Show dialog with detailed provider attribution information
  void _showProviderAttributionDialog(String providerId) {
    // Build data source attribution map
    final Map<String, String> dataSourceAttribution = {};

    if (providerId.toLowerCase() == 'tmdb') {
      dataSourceAttribution['title'] = 'tmdb';
      dataSourceAttribution['releaseDate'] = 'tmdb';
      dataSourceAttribution['overview'] = 'tmdb';
      dataSourceAttribution['ratings'] = 'tmdb';
      dataSourceAttribution['images'] = 'tmdb';
      dataSourceAttribution['castAndCrew'] = 'tmdb';
      if (!widget.isMovie) {
        dataSourceAttribution['episodes'] = 'tmdb';
      }
    } else {
      if (_aggregatedEpisodes != null &&
          _aggregatedEpisodes!.any((e) => e.sourceProvider == providerId)) {
        dataSourceAttribution['episodes'] = providerId;
        dataSourceAttribution['episodeThumbnails'] = providerId;
      }
      dataSourceAttribution['additionalMetadata'] = providerId;
    }

    // Build match confidences map
    final Map<String, double>? matchConfidences = _providerMatches != null
        ? Map.fromEntries(
            _providerMatches!.entries.map(
              (e) => MapEntry(e.key, e.value.confidence),
            ),
          )
        : null;

    showProviderAttributionDialog(
      context,
      dataSourceAttribution: dataSourceAttribution,
      contributingProviders: _contributingProviders,
      matchConfidences: matchConfidences,
      primaryProvider: 'tmdb',
    );
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
