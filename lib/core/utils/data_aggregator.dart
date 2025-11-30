import '../domain/entities/chapter_entity.dart';
import '../domain/entities/episode_entity.dart';
import '../domain/entities/media_entity.dart';
import '../domain/entities/media_details_entity.dart';
import '../data/datasources/tmdb_external_data_source.dart';
import 'cross_provider_matcher.dart';
import 'provider_priority_config.dart';
import 'logger.dart';
import 'retry_handler.dart';

/// Represents image URLs with source provider attribution
class ImageUrls {
  final String? coverImage;
  final String? bannerImage;
  final String sourceProvider;

  const ImageUrls({
    this.coverImage,
    this.bannerImage,
    required this.sourceProvider,
  });

  /// Check if this ImageUrls has any images
  bool get hasAnyImage => coverImage != null || bannerImage != null;

  /// Check if this ImageUrls has a cover image
  bool get hasCoverImage => coverImage != null && coverImage!.isNotEmpty;

  /// Check if this ImageUrls has a banner image
  bool get hasBannerImage => bannerImage != null && bannerImage!.isNotEmpty;

  @override
  String toString() {
    return 'ImageUrls(coverImage: ${coverImage != null ? "present" : "null"}, '
        'bannerImage: ${bannerImage != null ? "present" : "null"}, '
        'sourceProvider: $sourceProvider)';
  }
}

/// Aggregates data from multiple providers according to priority rules
///
/// This class is responsible for merging information from different providers
/// to create the most complete and accurate dataset possible. It uses
/// configurable priority rules to determine which provider's data to prefer
/// for different types of information.
class DataAggregator {
  final ProviderPriorityConfig priorityConfig;
  final RetryHandler retryHandler;

  DataAggregator({
    ProviderPriorityConfig? priorityConfig,
    RetryHandler? retryHandler,
  }) : priorityConfig =
           priorityConfig ?? ProviderPriorityConfig.defaultConfig(),
       retryHandler = retryHandler ?? RetryHandler();

  /// Aggregate episode data from multiple providers
  ///
  /// This method merges episode lists from multiple providers, prioritizing:
  /// 1. Episodes with thumbnails (following episodeThumbnailPriority)
  /// 2. Episodes with complete metadata (title, air date, description)
  /// 3. Primary provider's episode numbering scheme
  ///
  /// The method preserves source provider attribution for each episode.
  ///
  /// Parameters:
  /// - [primaryMedia]: The media entity from the primary source
  /// - [matches]: Map of provider ID to ProviderMatch for matched providers
  /// - [episodeFetcher]: Function to fetch episodes from a specific provider
  ///
  /// Returns a merged list of episodes with the most complete information
  Future<List<EpisodeEntity>> aggregateEpisodes({
    required MediaEntity primaryMedia,
    required Map<String, ProviderMatch> matches,
    required Future<List<EpisodeEntity>> Function(
      String mediaId,
      String providerId,
    )
    episodeFetcher,
  }) async {
    final startTime = DateTime.now();
    Logger.info(
      'Starting episode aggregation for "${primaryMedia.title}" from ${matches.length + 1} providers',
      tag: 'DataAggregator',
    );

    // Collect cover images from all providers for fallback detection
    final providerCoverImages = <String, String?>{};
    providerCoverImages[primaryMedia.sourceId] = primaryMedia.coverImage;
    for (final entry in matches.entries) {
      providerCoverImages[entry.key] = entry.value.mediaEntity?.coverImage;
    }

    // Fetch episodes from all providers in parallel
    final episodeFutures = <String, Future<List<EpisodeEntity>>>{};

    // Add primary provider
    episodeFutures[primaryMedia.sourceId] = episodeFetcher(
      primaryMedia.id,
      primaryMedia.sourceId,
    );

    // Add matched providers with retry logic
    for (final entry in matches.entries) {
      final providerId = entry.key;
      final match = entry.value;

      episodeFutures[providerId] = retryHandler
          .execute<List<EpisodeEntity>>(
            operation: () =>
                episodeFetcher(match.providerMediaId, providerId).timeout(
                  const Duration(
                    seconds: 60,
                  ), // Increased timeout for large series
                  onTimeout: () {
                    Logger.warning(
                      'Episode fetch timeout for provider $providerId (60s limit)',
                      tag: 'DataAggregator',
                    );
                    return <EpisodeEntity>[];
                  },
                ),
            providerId: providerId,
            operationName: 'Fetch episodes from $providerId',
          )
          .catchError((error) {
            // Log error but don't block other providers
            Logger.error(
              'Episode fetch failed for provider $providerId after retries',
              error: error,
              tag: 'DataAggregator',
            );
            return <EpisodeEntity>[];
          });
    }

    // Wait for all fetches to complete
    final episodeResults = await Future.wait(
      episodeFutures.entries.map((entry) async {
        final providerId = entry.key;
        final episodes = await entry.value;
        return MapEntry(providerId, episodes);
      }),
    );

    // Convert to map
    final episodesByProvider = Map.fromEntries(episodeResults);

    Logger.info(
      'Fetched episodes from providers: ${episodesByProvider.map((k, v) => MapEntry(k, v.length))}',
      tag: 'DataAggregator',
    );

    // If no episodes from any provider, return empty list
    if (episodesByProvider.values.every((episodes) => episodes.isEmpty)) {
      final duration = DateTime.now().difference(startTime).inMilliseconds;
      Logger.warning(
        'No episodes found from any provider (${duration}ms)',
        tag: 'DataAggregator',
      );
      return [];
    }

    // Check if TMDB has season information
    // If TMDB has season info, we'll use it for season-based grouping and matching
    final tmdbEpisodes = episodesByProvider['tmdb'] ?? [];
    final tmdbHasSeasonInfo =
        tmdbEpisodes.isNotEmpty &&
        tmdbEpisodes.any((e) => e.seasonNumber != null);

    // Find the provider with the most episodes (preferring those with thumbnails)
    // This will be our base episode list
    String? bestBaseProviderId;
    List<EpisodeEntity>? bestBaseEpisodes;
    double bestScore = 0.0;
    bool useSeasonBasedMatching = false;

    // Always find the provider with the most episodes for the base
    for (final entry in episodesByProvider.entries) {
      final providerId = entry.key;
      final episodes = entry.value;

      if (episodes.isEmpty) continue;

      // Calculate score: episode count + bonus for thumbnails
      double score = episodes.length.toDouble();
      final episodesWithThumbnails = episodes
          .where((e) => e.thumbnail != null && e.thumbnail!.isNotEmpty)
          .length;
      score +=
          episodesWithThumbnails * 2.0; // Prefer providers with episode images

      if (score > bestScore) {
        bestScore = score;
        bestBaseProviderId = providerId;
        bestBaseEpisodes = episodes;
      }
    }

    // If TMDB has season info, we'll use season-based matching
    // This allows us to match episodes by season+episode when TMDB provides that structure
    if (tmdbHasSeasonInfo) {
      Logger.info(
        'TMDB has season information (${tmdbEpisodes.where((e) => e.seasonNumber != null).length} episodes with seasons). Will use season-based matching and grouping.',
        tag: 'DataAggregator',
      );
      useSeasonBasedMatching = true;

      // If the base provider doesn't have season info, try to infer it from TMDB
      // by matching episodes and assigning season numbers
      if (bestBaseEpisodes != null &&
          bestBaseProviderId != null &&
          !bestBaseEpisodes.any((e) => e.seasonNumber != null)) {
        Logger.info(
          'Base provider $bestBaseProviderId does not have season info. Will infer season numbers from TMDB structure.',
          tag: 'DataAggregator',
        );

        // Get season metadata from TMDB (names and episode counts)
        // Try to get it from the first TMDB episode's mediaId (which is the tvId)
        final tmdbTvId = tmdbEpisodes.isNotEmpty
            ? tmdbEpisodes.first.mediaId
            : null;
        Map<int, Map<String, dynamic>>? tmdbSeasonMetadata;
        if (tmdbTvId != null) {
          tmdbSeasonMetadata = TmdbExternalDataSourceImpl.getSeasonMetadata(
            tmdbTvId,
          );
        }

        // Group TMDB episodes by season to understand the structure
        final tmdbSeasonGroups = <int, List<EpisodeEntity>>{};
        for (final ep in tmdbEpisodes) {
          if (ep.seasonNumber != null) {
            tmdbSeasonGroups.putIfAbsent(ep.seasonNumber!, () => []).add(ep);
          }
        }

        // Sort seasons and calculate episode ranges
        // Use actual episode counts from season metadata if available, otherwise count episodes
        final sortedSeasons = tmdbSeasonGroups.keys.toList()..sort();
        final seasonRanges =
            <int, int>{}; // season -> episode count in that season
        final seasonNames = <int, String?>{}; // season -> season name

        for (final season in sortedSeasons) {
          // Get episode count from metadata if available, otherwise count episodes
          if (tmdbSeasonMetadata != null &&
              tmdbSeasonMetadata.containsKey(season)) {
            final metadata = tmdbSeasonMetadata[season]!;
            seasonRanges[season] =
                metadata['episode_count'] as int? ??
                tmdbSeasonGroups[season]!.length;
            seasonNames[season] = metadata['name'] as String?;
          } else {
            // Fallback: count actual episodes in this season
            seasonRanges[season] = tmdbSeasonGroups[season]!.length;
          }
        }

        Logger.info(
          'TMDB season structure: ${seasonRanges.map((k, v) => MapEntry('S$k', '$v episodes (${seasonNames[k] ?? "unnamed"})'))}',
          tag: 'DataAggregator',
        );

        // Assign season numbers to base episodes based on TMDB structure
        // Calculate cumulative episode counts per season
        int currentGlobalEp = 0;
        final updatedBaseEpisodes = <EpisodeEntity>[];
        for (final season in sortedSeasons) {
          final seasonEpCount = seasonRanges[season] ?? 0;
          final seasonStart = currentGlobalEp + 1;
          final seasonEnd = currentGlobalEp + seasonEpCount;

          // Assign season numbers to base episodes in this range
          for (final ep in bestBaseEpisodes) {
            if (ep.number >= seasonStart && ep.number <= seasonEnd) {
              // Check if we've already added this episode
              if (!updatedBaseEpisodes.any((e) => e.id == ep.id)) {
                updatedBaseEpisodes.add(ep.copyWith(seasonNumber: season));
              }
            }
          }

          currentGlobalEp = seasonEnd;
        }

        // Add any remaining episodes that don't fit into TMDB's season structure
        for (final ep in bestBaseEpisodes) {
          if (!updatedBaseEpisodes.any((e) => e.id == ep.id)) {
            updatedBaseEpisodes.add(ep);
          }
        }

        // Sort by episode number to maintain order
        updatedBaseEpisodes.sort((a, b) => a.number.compareTo(b.number));
        bestBaseEpisodes = updatedBaseEpisodes;

        Logger.info(
          'Assigned season numbers to ${updatedBaseEpisodes.where((e) => e.seasonNumber != null).length} base episodes based on TMDB structure.',
          tag: 'DataAggregator',
        );
      }
    }

    // If we found a good base provider, use it
    if (bestBaseEpisodes != null && bestBaseProviderId != null) {
      final isPrimary = bestBaseProviderId == primaryMedia.sourceId;

      if (isPrimary) {
        // Use primary as base and enhance with other providers
        final result = _mergeEpisodesWithPrimary(
          bestBaseEpisodes,
          bestBaseProviderId,
          episodesByProvider,
          primaryCoverImage: primaryMedia.coverImage,
          providerCoverImages: providerCoverImages,
          useSeasonBasedMatching: useSeasonBasedMatching,
        );
        final duration = DateTime.now().difference(startTime).inMilliseconds;
        Logger.info(
          'Episode aggregation completed using primary provider: ${result.length} episodes in ${duration}ms',
          tag: 'DataAggregator',
        );
        return result;
      } else {
        // Use best provider as base (has more episodes than primary)
        Logger.info(
          'Using provider $bestBaseProviderId with ${bestBaseEpisodes.length} episodes as base (primary ${primaryMedia.sourceId} has ${episodesByProvider[primaryMedia.sourceId]?.length ?? 0} episodes)',
          tag: 'DataAggregator',
        );
        final result = _mergeEpisodesWithPrimary(
          bestBaseEpisodes,
          bestBaseProviderId,
          episodesByProvider,
          primaryCoverImage: primaryMedia.coverImage,
          providerCoverImages: providerCoverImages,
          useSeasonBasedMatching: useSeasonBasedMatching,
        );
        final duration = DateTime.now().difference(startTime).inMilliseconds;
        Logger.info(
          'Episode aggregation completed using best provider: ${result.length} episodes in ${duration}ms',
          tag: 'DataAggregator',
        );
        return result;
      }
    }

    // If no provider has episodes, return empty list
    Logger.warning(
      'No episodes found from any provider',
      tag: 'DataAggregator',
    );
    return [];
  }

  /// Merge episodes using primary provider's list as base
  ///
  /// This method takes the primary provider's episode list and enhances it
  /// with data from other providers, particularly focusing on adding thumbnails
  /// and completing metadata.
  List<EpisodeEntity> _mergeEpisodesWithPrimary(
    List<EpisodeEntity> primaryEpisodes,
    String primaryProviderId,
    Map<String, List<EpisodeEntity>> episodesByProvider, {
    String? primaryCoverImage,
    Map<String, String?> providerCoverImages = const {},
    bool useSeasonBasedMatching = false,
  }) {
    Logger.debug(
      'Merging ${primaryEpisodes.length} episodes with data from ${episodesByProvider.length - 1} additional providers',
      tag: 'DataAggregator',
    );

    final mergedEpisodes = <EpisodeEntity>[];

    // Get priority order for episode thumbnails
    final thumbnailPriority = priorityConfig.episodeThumbnailPriority;

    // Get the cover image for the primary provider (the one providing the base episodes)
    // This is important because when a non-primary provider has more episodes and becomes the base,
    // we need to check against that provider's cover image, not the original primary media's cover image
    final primaryProviderCoverImage =
        providerCoverImages[primaryProviderId] ?? primaryCoverImage;

    Logger.debug(
      'Using provider $primaryProviderId as base with cover image: ${primaryProviderCoverImage?.substring(0, primaryProviderCoverImage.length > 100 ? 100 : primaryProviderCoverImage.length) ?? "null"}...',
      tag: 'DataAggregator',
    );

    for (final primaryEpisode in primaryEpisodes) {
      var releaseDate = primaryEpisode.releaseDate;
      final alternativeData = Map<String, EpisodeData>.from(
        primaryEpisode.alternativeData ?? const {},
      );
      alternativeData[primaryProviderId] = EpisodeData(
        title: primaryEpisode.title,
        thumbnail: primaryEpisode.thumbnail,
        airDate: primaryEpisode.releaseDate,
      );

      // Always choose the best thumbnail from all providers according to priority
      // Priority order: Jikan > MyAnimeList > Kitsu > AniList > Simkl > TMDB
      String? bestThumbnail = null;
      String? bestThumbnailProvider = null;
      var primaryIsFallback = true;

      // Always search for the best thumbnail according to priority
      // This ensures we get the highest quality thumbnail from the highest priority provider
      // Try providers in priority order (highest to lowest)
      // Include the primary provider in the search if it's in the priority list
      for (final providerId in thumbnailPriority) {
        final providerEpisodes = episodesByProvider[providerId] ?? [];
        if (providerEpisodes.isEmpty) {
          Logger.debug(
            'Episode ${primaryEpisode.number}: Provider $providerId has no episodes',
            tag: 'DataAggregator',
          );
          continue;
        }
        final matchingEpisode = _findMatchingEpisode(
          primaryEpisode,
          providerEpisodes,
          useSeasonBasedMatching: useSeasonBasedMatching,
        );
        if (matchingEpisode == null) {
          Logger.debug(
            'Episode ${primaryEpisode.number}: No matching episode found in $providerId (has ${providerEpisodes.length} episodes)',
            tag: 'DataAggregator',
          );
        }

        if (matchingEpisode != null) {
          alternativeData[providerId] = EpisodeData(
            title: matchingEpisode.title,
            thumbnail: matchingEpisode.thumbnail,
            airDate: matchingEpisode.releaseDate,
          );
        }

        if (matchingEpisode != null &&
            matchingEpisode.thumbnail != null &&
            matchingEpisode.thumbnail!.isNotEmpty) {
          // Check if this thumbnail is a fallback by comparing to the provider's cover image
          final providerCoverImage = providerCoverImages[providerId];
          final isMatchingFallback = _isFallbackCoverImage(
            matchingEpisode.thumbnail,
            providerCoverImage ?? primaryCoverImage,
          );

          // Found a thumbnail from this provider
          final currentPriority = bestThumbnailProvider != null
              ? (thumbnailPriority.contains(bestThumbnailProvider)
                    ? thumbnailPriority.indexOf(bestThumbnailProvider)
                    : 999)
              : 999;
          final newPriority = thumbnailPriority.indexOf(providerId);

          // Use this thumbnail if:
          // 1. We don't have a thumbnail yet, OR
          // 2. Current thumbnail is a fallback AND this is NOT a fallback (real thumbnail), OR
          // 3. Current thumbnail is a fallback AND this is also a fallback BUT this provider has higher priority, OR
          // 4. Current thumbnail is NOT a fallback AND this is NOT a fallback AND this provider has higher priority
          final shouldUse =
              bestThumbnail == null ||
              (primaryIsFallback && !isMatchingFallback) ||
              (primaryIsFallback &&
                  isMatchingFallback &&
                  newPriority < currentPriority) ||
              (!primaryIsFallback &&
                  !isMatchingFallback &&
                  newPriority < currentPriority);

          if (shouldUse) {
            bestThumbnail = matchingEpisode.thumbnail;
            bestThumbnailProvider = providerId;
            // Update primaryIsFallback for next iteration
            primaryIsFallback = isMatchingFallback;
            // If we found a real (non-fallback) thumbnail from the highest priority provider (Jikan), we can stop
            if (newPriority == 0 && !isMatchingFallback) {
              break;
            }
          }
        }
      }

      // If no thumbnail was found from priority providers, fall back to primary provider's thumbnail
      if (bestThumbnail == null &&
          primaryEpisode.thumbnail != null &&
          primaryEpisode.thumbnail!.isNotEmpty) {
        final isPrimaryFallback = _isFallbackCoverImage(
          primaryEpisode.thumbnail,
          primaryProviderCoverImage,
        );
        if (!isPrimaryFallback) {
          bestThumbnail = primaryEpisode.thumbnail;
          bestThumbnailProvider = primaryProviderId;
          primaryIsFallback = false;
        }
      }

      // Check if the final best thumbnail is a fallback cover image
      // Compare against the provider's cover image that provided this thumbnail
      final bestProviderCoverImage = bestThumbnailProvider != null
          ? (providerCoverImages[bestThumbnailProvider] ?? primaryCoverImage)
          : primaryCoverImage;
      final finalThumbnailIsFallback =
          bestThumbnail != null &&
          _isFallbackCoverImage(bestThumbnail, bestProviderCoverImage);

      // Log fallback detection for debugging
      if (bestThumbnail != null && finalThumbnailIsFallback) {
        final thumbnailPreview = bestThumbnail.length > 100
            ? '${bestThumbnail.substring(0, 100)}...'
            : bestThumbnail;
        final coverPreview = bestProviderCoverImage != null
            ? (bestProviderCoverImage.length > 100
                  ? '${bestProviderCoverImage.substring(0, 100)}...'
                  : bestProviderCoverImage)
            : 'null';
        Logger.debug(
          'Episode ${primaryEpisode.number}: Detected fallback cover image from $bestThumbnailProvider. Thumbnail: $thumbnailPreview, Cover: $coverPreview',
          tag: 'DataAggregator',
        );
      }

      // Only set thumbnail if it's not a fallback cover image
      final finalThumbnail = finalThumbnailIsFallback ? null : bestThumbnail;

      if (bestThumbnailProvider != null &&
          bestThumbnailProvider != primaryProviderId &&
          !finalThumbnailIsFallback) {
        final priorityIndex = thumbnailPriority.indexOf(bestThumbnailProvider);
        Logger.debug(
          'Episode ${primaryEpisode.number}: Selected thumbnail from $bestThumbnailProvider (priority: $priorityIndex)',
          tag: 'DataAggregator',
        );
      } else if (finalThumbnailIsFallback) {
        Logger.debug(
          'Episode ${primaryEpisode.number}: Thumbnail is fallback cover image, setting to null',
          tag: 'DataAggregator',
        );
      }

      // If primary episode lacks release date, try to find one
      if (releaseDate == null) {
        for (final entry in episodesByProvider.entries) {
          if (entry.key == primaryProviderId) continue;

          final matchingEpisode = _findMatchingEpisode(
            primaryEpisode,
            entry.value,
            useSeasonBasedMatching:
                false, // Don't use season matching for release date enhancement
          );

          if (matchingEpisode != null && matchingEpisode.releaseDate != null) {
            releaseDate = matchingEpisode.releaseDate;
            alternativeData[entry.key] = EpisodeData(
              title: matchingEpisode.title,
              thumbnail: matchingEpisode.thumbnail,
              airDate: matchingEpisode.releaseDate,
            );

            Logger.info(
              'Enhanced episode ${primaryEpisode.number} with release date from ${entry.key}',
            );
            break;
          }
        }
      }

      mergedEpisodes.add(
        EpisodeEntity(
          id: primaryEpisode.id,
          mediaId: primaryEpisode.mediaId,
          title: primaryEpisode.title,
          number: primaryEpisode.number,
          thumbnail: finalThumbnail,
          duration: primaryEpisode.duration,
          releaseDate: releaseDate,
          seasonNumber: primaryEpisode.seasonNumber, // Preserve season number
          alternativeData: alternativeData.isEmpty
              ? null
              : Map.unmodifiable(alternativeData),
        ),
      );
    }

    Logger.info('Merged ${mergedEpisodes.length} episodes');
    return mergedEpisodes;
  }

  /// Find a matching episode in a list based on episode number or season+episode
  ///
  /// If useSeasonBasedMatching is true and target has season info, matches by season+episode.
  /// If target has season info but candidate doesn't, tries to map global episode number to season+episode.
  /// Otherwise, matches by episode number only.
  EpisodeEntity? _findMatchingEpisode(
    EpisodeEntity targetEpisode,
    List<EpisodeEntity> candidateEpisodes, {
    bool useSeasonBasedMatching = false,
  }) {
    // If using season-based matching and target has season info, try season+episode match first
    if (useSeasonBasedMatching && targetEpisode.seasonNumber != null) {
      // First, try exact season+episode match (if candidate also has season info)
      for (final candidate in candidateEpisodes) {
        if (candidate.seasonNumber != null &&
            candidate.seasonNumber == targetEpisode.seasonNumber &&
            candidate.number == targetEpisode.number) {
          Logger.debug(
            'Episode S${targetEpisode.seasonNumber}E${targetEpisode.number}: Found season+episode match in provider (S${candidate.seasonNumber}E${candidate.number})',
            tag: 'DataAggregator',
          );
          return candidate;
        }
      }

      // If target has season info but candidates don't, try to map global episode numbers
      // Calculate which global episode number corresponds to this season+episode
      // by counting episodes in previous seasons
      int? targetGlobalNumber;
      if (targetEpisode.seasonNumber != null) {
        // Find all episodes with season info to calculate season boundaries
        final episodesWithSeasons = candidateEpisodes
            .where((e) => e.seasonNumber != null)
            .toList();
        if (episodesWithSeasons.isNotEmpty) {
          // Group by season to find episode counts per season
          final seasonGroups = <int, List<EpisodeEntity>>{};
          for (final ep in episodesWithSeasons) {
            if (ep.seasonNumber != null) {
              seasonGroups.putIfAbsent(ep.seasonNumber!, () => []).add(ep);
            }
          }

          // Calculate global episode number for target season+episode
          int globalNum = targetEpisode.number;
          for (final season in seasonGroups.keys.toList()..sort()) {
            if (season < targetEpisode.seasonNumber!) {
              final seasonEpCount = seasonGroups[season]!
                  .map((e) => e.number)
                  .reduce(
                    (a, b) => a > b ? a : b,
                  ); // Max episode number in season
              globalNum += seasonEpCount;
            }
          }
          targetGlobalNumber = globalNum;
        }
      }

      // Try to match by calculated global number
      if (targetGlobalNumber != null) {
        for (final candidate in candidateEpisodes) {
          if (candidate.number == targetGlobalNumber) {
            Logger.debug(
              'Episode S${targetEpisode.seasonNumber}E${targetEpisode.number}: Found match by calculated global number ${targetGlobalNumber} (episode ${candidate.number})',
              tag: 'DataAggregator',
            );
            return candidate;
          }
        }
      }
    }

    // Try exact number match
    for (final candidate in candidateEpisodes) {
      if (candidate.number == targetEpisode.number) {
        Logger.debug(
          'Episode ${targetEpisode.number}: Found exact match in provider (episode ${candidate.number})',
          tag: 'DataAggregator',
        );
        return candidate;
      }
    }

    // For episodes with different numbering, try to find the closest match within a small range (±2 episodes)
    EpisodeEntity? closestMatch;
    int smallestDiff = 999;
    for (final candidate in candidateEpisodes) {
      final diff = (candidate.number - targetEpisode.number).abs();
      if (diff <= 2 && diff < smallestDiff) {
        smallestDiff = diff;
        closestMatch = candidate;
      }
    }

    if (closestMatch != null) {
      Logger.debug(
        'Episode ${targetEpisode.number}: Found close match (episode ${closestMatch.number}, diff: $smallestDiff)',
        tag: 'DataAggregator',
      );
      return closestMatch;
    }

    // Could add fuzzy title matching here in the future
    return null;
  }

  /// Check if a thumbnail URL is likely a fallback cover image
  ///
  /// This helps identify episodes that have the anime/manga cover as their
  /// thumbnail (used as fallback when no episode-specific image is available).
  /// We want to replace these with real episode thumbnails from other providers.
  bool _isFallbackCoverImage(String? thumbnail, String? coverImage) {
    if (thumbnail == null || coverImage == null) return false;
    if (thumbnail.isEmpty || coverImage.isEmpty) return false;

    // Normalize URLs for comparison (remove size suffixes, etc.)
    final normalizedThumbnail = _normalizeImageUrl(thumbnail);
    final normalizedCover = _normalizeImageUrl(coverImage);

    // Check if they're the same image (possibly with different sizes)
    if (normalizedThumbnail == normalizedCover) {
      return true;
    }

    // Additional check: Look for common cover/poster image patterns in the URL
    // This catches cases where the URL structure is different but it's still a cover image
    final thumbnailLower = thumbnail.toLowerCase();

    // Check if thumbnail contains common cover/poster keywords
    final hasCoverKeywords =
        thumbnailLower.contains('poster') ||
        thumbnailLower.contains('cover') ||
        thumbnailLower.contains('main_picture') ||
        thumbnailLower.contains('poster_image');

    // If thumbnail has cover keywords and the base paths are similar, it's likely a fallback
    if (hasCoverKeywords) {
      // Extract base path (domain + main path without size/format variations)
      final thumbnailBase = _extractBasePath(thumbnail);
      final coverBase = _extractBasePath(coverImage);
      if (thumbnailBase.isNotEmpty &&
          coverBase.isNotEmpty &&
          thumbnailBase == coverBase) {
        return true;
      }
    }

    return false;
  }

  /// Extract base path from URL for comparison
  String _extractBasePath(String url) {
    try {
      final uri = Uri.parse(url);
      // Get path without filename variations
      final path = uri.path;
      // Remove size suffixes and file extensions
      final basePath = path
          .replaceAll(
            RegExp(
              r'[_-]?(small|medium|large|original|l|m|s|w\d+)[_-]?',
              caseSensitive: false,
            ),
            '',
          )
          .replaceAll(
            RegExp(r'\.(jpg|jpeg|png|webp)$', caseSensitive: false),
            '',
          );
      return basePath.toLowerCase();
    } catch (e) {
      return '';
    }
  }

  /// Normalize an image URL for comparison
  ///
  /// Removes common size suffixes and variations to compare base URLs
  String _normalizeImageUrl(String url) {
    // Remove common size suffixes from various providers
    // MyAnimeList: /images/anime/1079/138100l.jpg -> /images/anime/1079/138100
    // Kitsu: /poster_images/1376/large.jpg -> /poster_images/1376
    // Handle MyAnimeList format: 138851l.jpg -> 138851
    String normalized = url
        .replaceAll(
          RegExp(
            r'[_-]?(small|medium|large|original|l|m|s)\.(jpg|jpeg|png|webp)$',
            caseSensitive: false,
          ),
          '',
        )
        // Handle MyAnimeList single-letter suffix before extension (e.g., 138851l.jpg)
        .replaceAll(
          RegExp(r'([a-z])\.(jpg|jpeg|png|webp)$', caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(r'\.(jpg|jpeg|png|webp)$', caseSensitive: false),
          '',
        );

    // Remove query parameters
    final queryIndex = normalized.indexOf('?');
    if (queryIndex > 0) {
      normalized = normalized.substring(0, queryIndex);
    }

    return normalized.toLowerCase();
  }

  /// Aggregate chapter data from multiple providers
  ///
  /// This method merges chapter lists from multiple providers, prioritizing:
  /// 1. The most complete chapter dataset (highest count with metadata)
  /// 2. Primary provider's chapter numbering scheme
  /// 3. Release date metadata from any provider
  ///
  /// The method preserves the primary provider's numbering scheme when available.
  ///
  /// Parameters:
  /// - [primaryMedia]: The media entity from the primary source
  /// - [matches]: Map of provider ID to ProviderMatch for matched providers
  /// - [chapterFetcher]: Function to fetch chapters from a specific provider
  ///
  /// Returns a merged list of chapters with the most complete information
  Future<List<ChapterEntity>> aggregateChapters({
    required MediaEntity primaryMedia,
    required Map<String, ProviderMatch> matches,
    required Future<List<ChapterEntity>> Function(
      String mediaId,
      String providerId,
    )
    chapterFetcher,
  }) async {
    Logger.info(
      'Aggregating chapters for ${primaryMedia.title} from ${matches.length + 1} providers',
    );

    // Fetch chapters from all providers in parallel
    final chapterFutures = <String, Future<List<ChapterEntity>>>{};

    // Add primary provider
    chapterFutures[primaryMedia.sourceId] = chapterFetcher(
      primaryMedia.id,
      primaryMedia.sourceId,
    );

    // Add matched providers with retry logic
    for (final entry in matches.entries) {
      final providerId = entry.key;
      final match = entry.value;

      chapterFutures[providerId] = retryHandler
          .execute<List<ChapterEntity>>(
            operation: () =>
                chapterFetcher(match.providerMediaId, providerId).timeout(
                  const Duration(seconds: 10),
                  onTimeout: () {
                    Logger.warning(
                      'Chapter fetch timeout for provider $providerId',
                    );
                    return <ChapterEntity>[];
                  },
                ),
            providerId: providerId,
            operationName: 'Fetch chapters from $providerId',
          )
          .catchError((error) {
            // Log error but don't block other providers
            Logger.error(
              'Chapter fetch failed for provider $providerId after retries',
              error: error,
            );
            return <ChapterEntity>[];
          });
    }

    // Wait for all fetches to complete
    final chapterResults = await Future.wait(
      chapterFutures.entries.map((entry) async {
        final providerId = entry.key;
        final chapters = await entry.value;
        return MapEntry(providerId, chapters);
      }),
    );

    // Convert to map
    final chaptersByProvider = Map.fromEntries(chapterResults);

    Logger.info(
      'Fetched chapters from providers: ${chaptersByProvider.map((k, v) => MapEntry(k, v.length))}',
    );

    // If no chapters from any provider, return empty list
    if (chaptersByProvider.values.every((chapters) => chapters.isEmpty)) {
      Logger.warning('No chapters found from any provider');
      return [];
    }

    // Get primary provider chapters as base
    final primaryChapters = chaptersByProvider[primaryMedia.sourceId] ?? [];

    // If primary has chapters, use it as base and enhance with other providers
    if (primaryChapters.isNotEmpty) {
      return _mergeChaptersWithPrimary(
        primaryChapters,
        primaryMedia.sourceId,
        chaptersByProvider,
      );
    }

    // If primary has no chapters, select best provider based on completeness
    return _selectBestChapterList(chaptersByProvider);
  }

  /// Merge chapters using primary provider's list as base
  ///
  /// This method takes the primary provider's chapter list and enhances it
  /// with data from other providers, particularly focusing on adding release
  /// dates and completing metadata while preserving the primary provider's
  /// numbering scheme.
  List<ChapterEntity> _mergeChaptersWithPrimary(
    List<ChapterEntity> primaryChapters,
    String primaryProviderId,
    Map<String, List<ChapterEntity>> chaptersByProvider,
  ) {
    Logger.info('Merging chapters with primary provider: $primaryProviderId');

    final mergedChapters = <ChapterEntity>[];

    for (final primaryChapter in primaryChapters) {
      var enhancedChapter = primaryChapter;

      // If primary chapter lacks release date, try to find one from other providers
      if (primaryChapter.releaseDate == null) {
        for (final entry in chaptersByProvider.entries) {
          if (entry.key == primaryProviderId) continue;

          final matchingChapter = _findMatchingChapter(
            primaryChapter,
            entry.value,
          );

          if (matchingChapter != null && matchingChapter.releaseDate != null) {
            // Found a release date! Create enhanced chapter
            enhancedChapter = ChapterEntity(
              id: primaryChapter.id,
              mediaId: primaryChapter.mediaId,
              title: primaryChapter.title,
              number: primaryChapter.number,
              releaseDate: matchingChapter.releaseDate,
              pageCount: primaryChapter.pageCount ?? matchingChapter.pageCount,
              sourceProvider: primaryChapter.sourceProvider,
            );

            Logger.info(
              'Enhanced chapter ${primaryChapter.number} with release date from ${entry.key}',
            );
            break;
          }
        }
      }

      // If primary chapter lacks page count, try to find one
      if (enhancedChapter.pageCount == null) {
        for (final entry in chaptersByProvider.entries) {
          if (entry.key == primaryProviderId) continue;

          final matchingChapter = _findMatchingChapter(
            primaryChapter,
            entry.value,
          );

          if (matchingChapter != null && matchingChapter.pageCount != null) {
            enhancedChapter = ChapterEntity(
              id: enhancedChapter.id,
              mediaId: enhancedChapter.mediaId,
              title: enhancedChapter.title,
              number: enhancedChapter.number,
              releaseDate: enhancedChapter.releaseDate,
              pageCount: matchingChapter.pageCount,
              sourceProvider: enhancedChapter.sourceProvider,
            );

            Logger.info(
              'Enhanced chapter ${primaryChapter.number} with page count from ${entry.key}',
            );
            break;
          }
        }
      }

      mergedChapters.add(enhancedChapter);
    }

    Logger.info('Merged ${mergedChapters.length} chapters');
    return mergedChapters;
  }

  /// Select the best chapter list when primary provider has no chapters
  ///
  /// This method selects the chapter list from the provider with the most
  /// complete dataset, prioritizing:
  /// 1. Providers with more chapters
  /// 2. Providers with more complete metadata (release dates, page counts)
  /// 3. Configured priority order for manga chapters
  List<ChapterEntity> _selectBestChapterList(
    Map<String, List<ChapterEntity>> chaptersByProvider,
  ) {
    Logger.info('Selecting best chapter list from available providers');

    // Calculate completeness score for each provider
    final providerScores = <String, double>{};

    for (final entry in chaptersByProvider.entries) {
      final providerId = entry.key;
      final chapters = entry.value;

      if (chapters.isEmpty) {
        providerScores[providerId] = 0.0;
        continue;
      }

      // Base score: number of chapters
      double score = chapters.length.toDouble();

      // Bonus for chapters with release dates
      final chaptersWithDates = chapters
          .where((c) => c.releaseDate != null)
          .length;
      score += chaptersWithDates * 0.5;

      // Bonus for chapters with page counts
      final chaptersWithPages = chapters
          .where((c) => c.pageCount != null)
          .length;
      score += chaptersWithPages * 0.3;

      providerScores[providerId] = score;
    }

    // Get priority order for manga chapters
    final priority = priorityConfig.mangaChapterPriority;

    // Find the best provider considering both priority and completeness
    String? bestProviderId;
    double bestScore = 0.0;

    // First, try providers in priority order if they have decent scores
    for (final providerId in priority) {
      final score = providerScores[providerId] ?? 0.0;
      if (score > 0 && (bestProviderId == null || score > bestScore * 0.8)) {
        // Accept if it's the first valid one or within 80% of best score
        bestProviderId = providerId;
        bestScore = score;
        break;
      }
    }

    // If no priority provider was good enough, select highest scoring provider
    if (bestProviderId == null) {
      for (final entry in providerScores.entries) {
        if (entry.value > bestScore) {
          bestProviderId = entry.key;
          bestScore = entry.value;
        }
      }
    }

    if (bestProviderId != null) {
      final chapters = chaptersByProvider[bestProviderId]!;
      Logger.info(
        'Selected chapters from $bestProviderId (${chapters.length} chapters, score: $bestScore)',
      );
      return chapters;
    }

    Logger.warning('No chapters found from any provider');
    return [];
  }

  /// Find a matching chapter in a list based on chapter number
  ///
  /// This is a simple matching strategy that matches chapters by their number.
  /// In the future, this could be enhanced with fuzzy title matching.
  ChapterEntity? _findMatchingChapter(
    ChapterEntity targetChapter,
    List<ChapterEntity> candidateChapters,
  ) {
    // Try exact number match first
    for (final candidate in candidateChapters) {
      if (candidate.number == targetChapter.number) {
        return candidate;
      }
    }

    // Could add fuzzy title matching here in the future
    return null;
  }

  /// Merge image URLs from multiple providers with priority-based selection
  ///
  /// This method implements a fallback strategy for images, prioritizing
  /// providers based on image quality (TMDB → Kitsu → others). It handles
  /// missing images by searching alternative providers and preserves source
  /// attribution for each image.
  ///
  /// The method selects:
  /// - Cover images from the highest priority provider that has one
  /// - Banner images from the highest priority provider that has one
  /// - Each image type is selected independently
  ///
  /// Parameters:
  /// - [primary]: The primary provider's image URLs
  /// - [alternatives]: Map of provider ID to ImageUrls for alternative providers
  ///
  /// Returns an ImageUrls object with the best available images and source attribution
  ImageUrls mergeImages({
    required ImageUrls primary,
    required Map<String, ImageUrls> alternatives,
  }) {
    Logger.info(
      'Merging images from primary provider ${primary.sourceProvider} '
      'with ${alternatives.length} alternative providers',
    );

    // Get priority order for images
    final imagePriority = priorityConfig.imageQualityPriority;

    // Start with primary images
    String? selectedCoverImage = primary.coverImage;
    String? selectedCoverSource = primary.sourceProvider;
    String? selectedBannerImage = primary.bannerImage;
    String? selectedBannerSource = primary.sourceProvider;

    // If primary lacks cover image, search alternatives in priority order
    if (!primary.hasCoverImage) {
      Logger.info('Primary provider lacks cover image, searching alternatives');

      for (final providerId in imagePriority) {
        final altImages = alternatives[providerId];
        if (altImages != null && altImages.hasCoverImage) {
          selectedCoverImage = altImages.coverImage;
          selectedCoverSource = providerId;
          Logger.info('Selected cover image from $providerId');
          break;
        }
      }

      // If no priority provider has cover, try any remaining provider
      if (selectedCoverImage == null || selectedCoverImage.isEmpty) {
        for (final entry in alternatives.entries) {
          if (entry.value.hasCoverImage) {
            selectedCoverImage = entry.value.coverImage;
            selectedCoverSource = entry.key;
            Logger.info(
              'Selected cover image from ${entry.key} (non-priority)',
            );
            break;
          }
        }
      }
    }

    // If primary lacks banner image, search alternatives in priority order
    if (!primary.hasBannerImage) {
      Logger.info(
        'Primary provider lacks banner image, searching alternatives',
      );

      for (final providerId in imagePriority) {
        final altImages = alternatives[providerId];
        if (altImages != null && altImages.hasBannerImage) {
          selectedBannerImage = altImages.bannerImage;
          selectedBannerSource = providerId;
          Logger.info('Selected banner image from $providerId');
          break;
        }
      }

      // If no priority provider has banner, try any remaining provider
      if (selectedBannerImage == null || selectedBannerImage.isEmpty) {
        for (final entry in alternatives.entries) {
          if (entry.value.hasBannerImage) {
            selectedBannerImage = entry.value.bannerImage;
            selectedBannerSource = entry.key;
            Logger.info(
              'Selected banner image from ${entry.key} (non-priority)',
            );
            break;
          }
        }
      }
    }

    // Determine the overall source provider for attribution
    // If both images come from the same source, use that
    // Otherwise, use the primary provider as the main source
    String finalSourceProvider;
    if (selectedCoverSource == selectedBannerSource) {
      finalSourceProvider = selectedCoverSource!;
    } else {
      finalSourceProvider = primary.sourceProvider;
    }

    final result = ImageUrls(
      coverImage: selectedCoverImage,
      bannerImage: selectedBannerImage,
      sourceProvider: finalSourceProvider,
    );

    Logger.info(
      'Merged images: cover from ${selectedCoverSource ?? "none"}, '
      'banner from ${selectedBannerSource ?? "none"}',
    );

    return result;
  }

  /// Merge character lists from multiple providers with deduplication
  ///
  /// This method combines character lists from multiple providers and
  /// deduplicates based on character name matching. Characters with the
  /// same name (case-insensitive, normalized) are considered duplicates.
  ///
  /// The method preserves the first occurrence of each unique character,
  /// prioritizing characters with more complete information (image, native name).
  ///
  /// Parameters:
  /// - [characterLists]: List of character lists from different providers
  ///
  /// Returns a deduplicated list of characters
  List<CharacterEntity> mergeCharacters(
    List<List<CharacterEntity>> characterLists,
  ) {
    Logger.info(
      'Merging character lists from ${characterLists.length} providers',
    );

    if (characterLists.isEmpty) {
      return [];
    }

    // Flatten all character lists
    final allCharacters = characterLists.expand((list) => list).toList();

    if (allCharacters.isEmpty) {
      return [];
    }

    // Deduplicate by normalized name
    final seenNames = <String, CharacterEntity>{};

    for (final character in allCharacters) {
      final normalizedName = _normalizeName(character.name);

      if (!seenNames.containsKey(normalizedName)) {
        // First occurrence - add it
        seenNames[normalizedName] = character;
      } else {
        // Duplicate found - keep the one with more complete information
        final existing = seenNames[normalizedName]!;
        final replacement = _selectMoreCompleteCharacter(existing, character);
        seenNames[normalizedName] = replacement;
      }
    }

    final mergedCharacters = seenNames.values.toList();

    Logger.info(
      'Merged ${allCharacters.length} characters into ${mergedCharacters.length} unique characters',
    );

    return mergedCharacters;
  }

  /// Merge staff lists from multiple providers with deduplication
  ///
  /// This method combines staff lists from multiple providers and
  /// deduplicates based on staff name matching. Staff members with the
  /// same name (case-insensitive, normalized) are considered duplicates.
  ///
  /// The method preserves the first occurrence of each unique staff member,
  /// prioritizing staff with more complete information (image, native name).
  ///
  /// Parameters:
  /// - [staffLists]: List of staff lists from different providers
  ///
  /// Returns a deduplicated list of staff members
  List<StaffEntity> mergeStaff(List<List<StaffEntity>> staffLists) {
    Logger.info('Merging staff lists from ${staffLists.length} providers');

    if (staffLists.isEmpty) {
      return [];
    }

    // Flatten all staff lists
    final allStaff = staffLists.expand((list) => list).toList();

    if (allStaff.isEmpty) {
      return [];
    }

    // Deduplicate by normalized name
    final seenNames = <String, StaffEntity>{};

    for (final staff in allStaff) {
      final normalizedName = _normalizeName(staff.name);

      if (!seenNames.containsKey(normalizedName)) {
        // First occurrence - add it
        seenNames[normalizedName] = staff;
      } else {
        // Duplicate found - keep the one with more complete information
        final existing = seenNames[normalizedName]!;
        final replacement = _selectMoreCompleteStaff(existing, staff);
        seenNames[normalizedName] = replacement;
      }
    }

    final mergedStaff = seenNames.values.toList();

    Logger.info(
      'Merged ${allStaff.length} staff into ${mergedStaff.length} unique staff members',
    );

    return mergedStaff;
  }

  /// Merge recommendation lists from multiple providers with deduplication
  ///
  /// This method combines recommendation lists from multiple providers and
  /// deduplicates based on title matching. Recommendations with the same
  /// title (case-insensitive, normalized) are considered duplicates.
  ///
  /// The method preserves the first occurrence of each unique recommendation,
  /// prioritizing recommendations with higher ratings.
  ///
  /// Parameters:
  /// - [recommendationLists]: List of recommendation lists from different providers
  ///
  /// Returns a deduplicated list of recommendations
  List<RecommendationEntity> mergeRecommendations(
    List<List<RecommendationEntity>> recommendationLists,
  ) {
    Logger.info(
      'Merging recommendation lists from ${recommendationLists.length} providers',
    );

    if (recommendationLists.isEmpty) {
      return [];
    }

    // Flatten all recommendation lists
    final allRecommendations = recommendationLists
        .expand((list) => list)
        .toList();

    if (allRecommendations.isEmpty) {
      return [];
    }

    // Deduplicate by normalized title
    final seenTitles = <String, RecommendationEntity>{};

    for (final recommendation in allRecommendations) {
      final normalizedTitle = _normalizeName(recommendation.title);

      if (!seenTitles.containsKey(normalizedTitle)) {
        // First occurrence - add it
        seenTitles[normalizedTitle] = recommendation;
      } else {
        // Duplicate found - keep the one with higher rating
        final existing = seenTitles[normalizedTitle]!;
        if (recommendation.rating > existing.rating) {
          seenTitles[normalizedTitle] = recommendation;
        }
      }
    }

    final mergedRecommendations = seenTitles.values.toList();

    Logger.info(
      'Merged ${allRecommendations.length} recommendations into ${mergedRecommendations.length} unique recommendations',
    );

    return mergedRecommendations;
  }

  /// Aggregate media details from multiple providers
  ///
  /// This method merges complete media details from multiple providers,
  /// combining characters, staff, recommendations, and other metadata.
  /// It uses the primary provider's basic information as the base and
  /// enhances it with data from matched providers.
  ///
  /// The method:
  /// - Merges and deduplicates character lists
  /// - Merges and deduplicates staff lists
  /// - Merges and deduplicates recommendation lists
  /// - Preserves all other metadata from the primary provider
  ///
  /// Parameters:
  /// - [primaryDetails]: The media details from the primary source
  /// - [matches]: Map of provider ID to ProviderMatch for matched providers
  /// - [detailsFetcher]: Function to fetch full details from a specific provider
  ///
  /// Returns aggregated media details with merged metadata
  Future<MediaDetailsEntity> aggregateMediaDetails({
    required MediaDetailsEntity primaryDetails,
    required Map<String, ProviderMatch> matches,
    required Future<MediaDetailsEntity> Function(
      String mediaId,
      String providerId,
    )
    detailsFetcher,
  }) async {
    Logger.info(
      'Aggregating media details for ${primaryDetails.title} from ${matches.length + 1} providers',
    );

    // If no matches, return primary details as-is
    if (matches.isEmpty) {
      Logger.info('No matched providers, returning primary details');
      return primaryDetails;
    }

    // Fetch details from matched providers in parallel
    final detailsFutures = <String, Future<MediaDetailsEntity>>{};

    for (final entry in matches.entries) {
      final providerId = entry.key;
      final match = entry.value;

      detailsFutures[providerId] = retryHandler
          .execute<MediaDetailsEntity>(
            operation: () =>
                detailsFetcher(match.providerMediaId, providerId).timeout(
                  const Duration(seconds: 10),
                  onTimeout: () {
                    Logger.warning(
                      'Details fetch timeout for provider $providerId',
                    );
                    // Return a minimal details entity on timeout
                    return MediaDetailsEntity(
                      id: match.providerMediaId,
                      title: match.matchedTitle,
                      coverImage: '',
                      type: primaryDetails.type,
                      genres: [],
                      tags: [],
                      sourceId: providerId,
                      sourceName: providerId,
                    );
                  },
                ),
            providerId: providerId,
            operationName: 'Fetch details from $providerId',
          )
          .catchError((error) {
            // Log error but don't block other providers
            Logger.error(
              'Details fetch failed for provider $providerId after retries',
              error: error,
            );
            // Return a minimal details entity on error
            return MediaDetailsEntity(
              id: match.providerMediaId,
              title: match.matchedTitle,
              coverImage: '',
              type: primaryDetails.type,
              genres: [],
              tags: [],
              sourceId: providerId,
              sourceName: providerId,
            );
          });
    }

    // Wait for all fetches to complete
    final detailsResults = await Future.wait(
      detailsFutures.entries.map((entry) async {
        final providerId = entry.key;
        final details = await entry.value;
        return MapEntry(providerId, details);
      }),
    );

    // Convert to map
    final detailsByProvider = Map.fromEntries(detailsResults);

    Logger.info('Fetched details from ${detailsByProvider.length} providers');

    // Collect all character lists
    final characterLists = <List<CharacterEntity>>[];
    if (primaryDetails.characters != null &&
        primaryDetails.characters!.isNotEmpty) {
      characterLists.add(primaryDetails.characters!);
    }
    for (final details in detailsByProvider.values) {
      if (details.characters != null && details.characters!.isNotEmpty) {
        characterLists.add(details.characters!);
      }
    }

    // Collect all staff lists
    final staffLists = <List<StaffEntity>>[];
    if (primaryDetails.staff != null && primaryDetails.staff!.isNotEmpty) {
      staffLists.add(primaryDetails.staff!);
    }
    for (final details in detailsByProvider.values) {
      if (details.staff != null && details.staff!.isNotEmpty) {
        staffLists.add(details.staff!);
      }
    }

    // Collect all recommendation lists
    final recommendationLists = <List<RecommendationEntity>>[];
    if (primaryDetails.recommendations != null &&
        primaryDetails.recommendations!.isNotEmpty) {
      recommendationLists.add(primaryDetails.recommendations!);
    }
    for (final details in detailsByProvider.values) {
      if (details.recommendations != null &&
          details.recommendations!.isNotEmpty) {
        recommendationLists.add(details.recommendations!);
      }
    }

    // Merge all metadata
    final mergedCharacters = mergeCharacters(characterLists);
    final mergedStaff = mergeStaff(staffLists);
    final mergedRecommendations = mergeRecommendations(recommendationLists);

    // Merge all other fields intelligently (highest values, highest quality, most recent)
    var aggregatedDetails = primaryDetails;

    // Merge genres and tags (deduplicate)
    final allGenres = <String>{...primaryDetails.genres};
    final allTags = <String>{...primaryDetails.tags};
    for (final details in detailsByProvider.values) {
      allGenres.addAll(details.genres);
      allTags.addAll(details.tags);
    }

    // Choose highest rating/score
    double? bestRating = primaryDetails.rating;
    int? bestAverageScore =
        primaryDetails.averageScore ?? primaryDetails.meanScore;
    for (final details in detailsByProvider.values) {
      if (details.rating != null &&
          (bestRating == null || details.rating! > bestRating)) {
        bestRating = details.rating;
      }
      final score = details.averageScore ?? details.meanScore;
      if (score != null &&
          (bestAverageScore == null || score > bestAverageScore)) {
        bestAverageScore = score;
      }
    }

    // Choose highest popularity and favorites
    int? bestPopularity = primaryDetails.popularity;
    int? bestFavorites = primaryDetails.favorites;
    for (final details in detailsByProvider.values) {
      if (details.popularity != null &&
          (bestPopularity == null || details.popularity! > bestPopularity)) {
        bestPopularity = details.popularity;
      }
      if (details.favorites != null &&
          (bestFavorites == null || details.favorites! > bestFavorites)) {
        bestFavorites = details.favorites;
      }
    }

    // Choose highest episode/chapter/volume counts
    int? bestEpisodes = primaryDetails.episodes;
    int? bestChapters = primaryDetails.chapters;
    int? bestVolumes = primaryDetails.volumes;
    for (final details in detailsByProvider.values) {
      if (details.episodes != null &&
          (bestEpisodes == null || details.episodes! > bestEpisodes)) {
        bestEpisodes = details.episodes;
      }
      if (details.chapters != null &&
          (bestChapters == null || details.chapters! > bestChapters)) {
        bestChapters = details.chapters;
      }
      if (details.volumes != null &&
          (bestVolumes == null || details.volumes! > bestVolumes)) {
        bestVolumes = details.volumes;
      }
    }

    // Choose longest duration
    int? bestDuration = primaryDetails.duration;
    for (final details in detailsByProvider.values) {
      if (details.duration != null &&
          (bestDuration == null || details.duration! > bestDuration)) {
        bestDuration = details.duration;
      }
    }

    // Choose most recent dates (latest start, latest end)
    DateTime? earliestStartDate = primaryDetails.startDate;
    DateTime? latestEndDate = primaryDetails.endDate;
    for (final details in detailsByProvider.values) {
      if (details.startDate != null) {
        if (earliestStartDate == null ||
            details.startDate!.isBefore(earliestStartDate)) {
          earliestStartDate = details.startDate;
        }
      }
      if (details.endDate != null) {
        if (latestEndDate == null || details.endDate!.isAfter(latestEndDate)) {
          latestEndDate = details.endDate;
        }
      }
    }

    // Choose best images (non-null, non-empty, prefer primary source first, then higher quality sources)
    String bestCoverImage = primaryDetails.coverImage;
    String? bestBannerImage = primaryDetails.bannerImage;

    // Only use alternative sources if primary source lacks the image
    // Priority order for images: Jikan > AniList > Kitsu > Simkl > TMDB
    final imagePriority = [
      'tmdb',
      'jikan',
      'myanimelist',
      'mal',
      'anilist',
      'kitsu',
      'simkl',
    ];
    for (final providerId in imagePriority) {
      final details = detailsByProvider[providerId];
      if (details != null) {
        // Only use alternative cover if primary is empty
        if (bestCoverImage.isEmpty && details.coverImage.isNotEmpty) {
          bestCoverImage = details.coverImage;
        }
        // Only use alternative banner if primary is null or empty
        // Prioritize primary source's banner over alternatives
        if (bestBannerImage == null || bestBannerImage.isEmpty) {
          if (details.bannerImage != null && details.bannerImage!.isNotEmpty) {
            bestBannerImage = details.bannerImage;
          }
        }
      }
    }

    // Choose longest/most complete description
    String? bestDescription = primaryDetails.description;
    if (bestDescription == null || bestDescription.isEmpty) {
      for (final details in detailsByProvider.values) {
        if (details.description != null &&
            details.description!.isNotEmpty &&
            (bestDescription == null ||
                details.description!.length > bestDescription.length)) {
          bestDescription = details.description;
        }
      }
    }

    // Merge studios (deduplicate by name)
    final studiosMap = <String, StudioEntity>{};
    if (primaryDetails.studios != null) {
      for (final studio in primaryDetails.studios!) {
        studiosMap[studio.name.toLowerCase()] = studio;
      }
    }
    for (final details in detailsByProvider.values) {
      if (details.studios != null) {
        for (final studio in details.studios!) {
          final key = studio.name.toLowerCase();
          if (!studiosMap.containsKey(key)) {
            studiosMap[key] = studio;
          } else {
            // Prefer main studios
            if (studio.isMain && !studiosMap[key]!.isMain) {
              studiosMap[key] = studio;
            }
          }
        }
      }
    }

    // Merge relations (deduplicate by id)
    final relationsMap = <String, MediaRelationEntity>{};
    if (primaryDetails.relations != null) {
      for (final relation in primaryDetails.relations!) {
        relationsMap[relation.id] = relation;
      }
    }
    for (final details in detailsByProvider.values) {
      if (details.relations != null) {
        for (final relation in details.relations!) {
          if (!relationsMap.containsKey(relation.id)) {
            relationsMap[relation.id] = relation;
          }
        }
      }
    }

    // Choose best trailer (prefer YouTube)
    TrailerEntity? bestTrailer = primaryDetails.trailer;
    if (bestTrailer == null || bestTrailer.site.toLowerCase() != 'youtube') {
      for (final details in detailsByProvider.values) {
        if (details.trailer != null) {
          if (bestTrailer == null ||
              details.trailer!.site.toLowerCase() == 'youtube') {
            bestTrailer = details.trailer;
          }
        }
      }
    }

    // Build data source attribution map
    final dataSourceAttribution = <String, String>{
      'title': primaryDetails.sourceId,
      'coverImage': bestCoverImage == primaryDetails.coverImage
          ? primaryDetails.sourceId
          : _findProviderForImage(bestCoverImage, detailsByProvider),
      if (bestBannerImage != null)
        'bannerImage': bestBannerImage == primaryDetails.bannerImage
            ? primaryDetails.sourceId
            : _findProviderForImage(bestBannerImage, detailsByProvider),
      if (bestDescription != null &&
          bestDescription != primaryDetails.description)
        'description': _findProviderForDescription(
          bestDescription,
          detailsByProvider,
        ),
      if (bestRating != null && bestRating != primaryDetails.rating)
        'rating': _findProviderForRating(bestRating, detailsByProvider),
      if (bestEpisodes != null && bestEpisodes != primaryDetails.episodes)
        'episodes': _findProviderForEpisodes(bestEpisodes, detailsByProvider),
      if (bestChapters != null && bestChapters != primaryDetails.chapters)
        'chapters': _findProviderForChapters(bestChapters, detailsByProvider),
    };

    // Build contributing providers list
    final contributingProviders = <String>[
      primaryDetails.sourceId,
      ...detailsByProvider.keys,
    ];

    // Build match confidences map
    final matchConfidences = <String, double>{};
    for (final entry in matches.entries) {
      matchConfidences[entry.key] = entry.value.confidence;
    }

    // Create aggregated details with all merged data
    aggregatedDetails = primaryDetails.copyWith(
      // Basic info
      coverImage: bestCoverImage,
      bannerImage: bestBannerImage,
      description: bestDescription ?? primaryDetails.description,

      // Ratings and scores
      rating: bestRating,
      averageScore: bestAverageScore,

      // Popularity metrics
      popularity: bestPopularity,
      favorites: bestFavorites,

      // Counts
      episodes: bestEpisodes,
      chapters: bestChapters,
      volumes: bestVolumes,
      duration: bestDuration,

      // Dates
      startDate: earliestStartDate,
      endDate: latestEndDate,

      // Genres and tags (deduplicated)
      genres: allGenres.toList(),
      tags: allTags.toList(),

      // Rich metadata
      characters: mergedCharacters.isNotEmpty ? mergedCharacters : null,
      staff: mergedStaff.isNotEmpty ? mergedStaff : null,
      recommendations: mergedRecommendations.isNotEmpty
          ? mergedRecommendations
          : null,
      studios: studiosMap.values.isNotEmpty ? studiosMap.values.toList() : null,
      relations: relationsMap.values.isNotEmpty
          ? relationsMap.values.toList()
          : null,
      trailer: bestTrailer,

      // Attribution
      dataSourceAttribution: dataSourceAttribution,
      contributingProviders: contributingProviders,
      matchConfidences: matchConfidences,
    );

    Logger.info(
      'Aggregated details: ${mergedCharacters.length} characters, '
      '${mergedStaff.length} staff, ${mergedRecommendations.length} recommendations, '
      '${allGenres.length} genres, ${bestEpisodes ?? 0} episodes',
    );

    return aggregatedDetails;
  }

  /// Helper to find which provider contributed a specific image
  String _findProviderForImage(
    String imageUrl,
    Map<String, MediaDetailsEntity> detailsByProvider,
  ) {
    for (final entry in detailsByProvider.entries) {
      if (entry.value.coverImage == imageUrl ||
          entry.value.bannerImage == imageUrl) {
        return entry.key;
      }
    }
    return 'unknown';
  }

  /// Helper to find which provider contributed a specific description
  String _findProviderForDescription(
    String description,
    Map<String, MediaDetailsEntity> detailsByProvider,
  ) {
    for (final entry in detailsByProvider.entries) {
      if (entry.value.description == description) {
        return entry.key;
      }
    }
    return 'unknown';
  }

  /// Helper to find which provider contributed a specific rating
  String _findProviderForRating(
    double rating,
    Map<String, MediaDetailsEntity> detailsByProvider,
  ) {
    for (final entry in detailsByProvider.entries) {
      if (entry.value.rating == rating) {
        return entry.key;
      }
    }
    return 'unknown';
  }

  /// Helper to find which provider contributed episode count
  String _findProviderForEpisodes(
    int episodes,
    Map<String, MediaDetailsEntity> detailsByProvider,
  ) {
    for (final entry in detailsByProvider.entries) {
      if (entry.value.episodes == episodes) {
        return entry.key;
      }
    }
    return 'unknown';
  }

  /// Helper to find which provider contributed chapter count
  String _findProviderForChapters(
    int chapters,
    Map<String, MediaDetailsEntity> detailsByProvider,
  ) {
    for (final entry in detailsByProvider.entries) {
      if (entry.value.chapters == chapters) {
        return entry.key;
      }
    }
    return 'unknown';
  }

  /// Normalize a name for comparison
  ///
  /// This method normalizes names by:
  /// - Converting to lowercase
  /// - Removing extra whitespace
  /// - Trimming leading/trailing whitespace
  ///
  /// This allows for case-insensitive and whitespace-insensitive matching.
  String _normalizeName(String name) {
    return name.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Select the more complete character between two duplicates
  ///
  /// This method compares two characters and returns the one with more
  /// complete information. Priority is given to characters with:
  /// 1. An image
  /// 2. A native name
  /// 3. More complete role information
  CharacterEntity _selectMoreCompleteCharacter(
    CharacterEntity a,
    CharacterEntity b,
  ) {
    // Count completeness factors
    int scoreA = 0;
    int scoreB = 0;

    if (a.image != null && a.image!.isNotEmpty) scoreA++;
    if (b.image != null && b.image!.isNotEmpty) scoreB++;

    if (a.nativeName != null && a.nativeName!.isNotEmpty) scoreA++;
    if (b.nativeName != null && b.nativeName!.isNotEmpty) scoreB++;

    if (a.role.isNotEmpty) scoreA++;
    if (b.role.isNotEmpty) scoreB++;

    // Return the one with higher score, or the first one if tied
    return scoreB > scoreA ? b : a;
  }

  /// Select the more complete staff member between two duplicates
  ///
  /// This method compares two staff members and returns the one with more
  /// complete information. Priority is given to staff with:
  /// 1. An image
  /// 2. A native name
  /// 3. More complete role information
  StaffEntity _selectMoreCompleteStaff(StaffEntity a, StaffEntity b) {
    // Count completeness factors
    int scoreA = 0;
    int scoreB = 0;

    if (a.image != null && a.image!.isNotEmpty) scoreA++;
    if (b.image != null && b.image!.isNotEmpty) scoreB++;

    if (a.nativeName != null && a.nativeName!.isNotEmpty) scoreA++;
    if (b.nativeName != null && b.nativeName!.isNotEmpty) scoreB++;

    if (a.role.isNotEmpty) scoreA++;
    if (b.role.isNotEmpty) scoreB++;

    // Return the one with higher score, or the first one if tied
    return scoreB > scoreA ? b : a;
  }
}
