import '../domain/entities/chapter_entity.dart';
import '../domain/entities/episode_entity.dart';
import '../domain/entities/media_entity.dart';
import '../domain/entities/media_details_entity.dart';
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
                  const Duration(seconds: 10),
                  onTimeout: () {
                    Logger.warning(
                      'Episode fetch timeout for provider $providerId',
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

    // Get primary provider episodes as base
    final primaryEpisodes = episodesByProvider[primaryMedia.sourceId] ?? [];

    // If primary has episodes, use it as base and enhance with other providers
    if (primaryEpisodes.isNotEmpty) {
      final result = _mergeEpisodesWithPrimary(
        primaryEpisodes,
        primaryMedia.sourceId,
        episodesByProvider,
        primaryCoverImage: primaryMedia.coverImage,
      );
      final duration = DateTime.now().difference(startTime).inMilliseconds;
      Logger.info(
        'Episode aggregation completed: ${result.length} episodes in ${duration}ms',
        tag: 'DataAggregator',
      );
      return result;
    }

    // If primary has no episodes, select best provider based on priority
    Logger.info(
      'Primary provider has no episodes, using fallback selection',
      tag: 'DataAggregator',
    );
    final result = _selectBestEpisodeList(episodesByProvider);
    final duration = DateTime.now().difference(startTime).inMilliseconds;
    Logger.info(
      'Episode aggregation completed (fallback): ${result.length} episodes in ${duration}ms',
      tag: 'DataAggregator',
    );
    return result;
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
  }) {
    Logger.debug(
      'Merging ${primaryEpisodes.length} episodes with data from ${episodesByProvider.length - 1} additional providers',
      tag: 'DataAggregator',
    );

    final mergedEpisodes = <EpisodeEntity>[];

    // Get priority order for episode thumbnails
    final thumbnailPriority = priorityConfig.episodeThumbnailPriority;

    for (final primaryEpisode in primaryEpisodes) {
      var enhancedEpisode = primaryEpisode;

      // Check if primary episode needs a better thumbnail
      // A thumbnail is considered "missing" if it's null, empty, or just the cover image fallback
      final needsBetterThumbnail =
          primaryEpisode.thumbnail == null ||
          primaryEpisode.thumbnail!.isEmpty ||
          _isFallbackCoverImage(primaryEpisode.thumbnail, primaryCoverImage);

      if (needsBetterThumbnail) {
        // Try providers in priority order
        for (final providerId in thumbnailPriority) {
          if (providerId == primaryProviderId) continue;

          final providerEpisodes = episodesByProvider[providerId] ?? [];
          final matchingEpisode = _findMatchingEpisode(
            primaryEpisode,
            providerEpisodes,
          );

          if (matchingEpisode != null &&
              matchingEpisode.thumbnail != null &&
              matchingEpisode.thumbnail!.isNotEmpty &&
              !_isFallbackCoverImage(
                matchingEpisode.thumbnail,
                primaryCoverImage,
              )) {
            // Found a real thumbnail! Create enhanced episode
            enhancedEpisode = EpisodeEntity(
              id: primaryEpisode.id,
              mediaId: primaryEpisode.mediaId,
              title: primaryEpisode.title,
              number: primaryEpisode.number,
              thumbnail: matchingEpisode.thumbnail,
              duration: primaryEpisode.duration ?? matchingEpisode.duration,
              releaseDate:
                  primaryEpisode.releaseDate ?? matchingEpisode.releaseDate,
            );

            Logger.info(
              'Enhanced episode ${primaryEpisode.number} with thumbnail from $providerId',
            );
            break;
          }
        }
      }

      // If primary episode lacks release date, try to find one
      if (enhancedEpisode.releaseDate == null) {
        for (final entry in episodesByProvider.entries) {
          if (entry.key == primaryProviderId) continue;

          final matchingEpisode = _findMatchingEpisode(
            primaryEpisode,
            entry.value,
          );

          if (matchingEpisode != null && matchingEpisode.releaseDate != null) {
            enhancedEpisode = EpisodeEntity(
              id: enhancedEpisode.id,
              mediaId: enhancedEpisode.mediaId,
              title: enhancedEpisode.title,
              number: enhancedEpisode.number,
              thumbnail: enhancedEpisode.thumbnail,
              duration: enhancedEpisode.duration,
              releaseDate: matchingEpisode.releaseDate,
            );

            Logger.info(
              'Enhanced episode ${primaryEpisode.number} with release date from ${entry.key}',
            );
            break;
          }
        }
      }

      mergedEpisodes.add(enhancedEpisode);
    }

    Logger.info('Merged ${mergedEpisodes.length} episodes');
    return mergedEpisodes;
  }

  /// Select the best episode list when primary provider has no episodes
  ///
  /// This method selects the episode list from the provider with the highest
  /// priority that has episodes available, preferring providers with more
  /// complete metadata (thumbnails, release dates).
  List<EpisodeEntity> _selectBestEpisodeList(
    Map<String, List<EpisodeEntity>> episodesByProvider,
  ) {
    Logger.info('Selecting best episode list from available providers');

    // Get priority order
    final priority = priorityConfig.episodeThumbnailPriority;

    // Try providers in priority order
    for (final providerId in priority) {
      final episodes = episodesByProvider[providerId];
      if (episodes != null && episodes.isNotEmpty) {
        Logger.info(
          'Selected episodes from $providerId (${episodes.length} episodes)',
        );
        return episodes;
      }
    }

    // If no priority provider has episodes, return first non-empty list
    for (final entry in episodesByProvider.entries) {
      if (entry.value.isNotEmpty) {
        Logger.info(
          'Selected episodes from ${entry.key} (${entry.value.length} episodes)',
        );
        return entry.value;
      }
    }

    Logger.warning('No episodes found from any provider');
    return [];
  }

  /// Find a matching episode in a list based on episode number
  ///
  /// This is a simple matching strategy that matches episodes by their number.
  /// In the future, this could be enhanced with fuzzy title matching.
  EpisodeEntity? _findMatchingEpisode(
    EpisodeEntity targetEpisode,
    List<EpisodeEntity> candidateEpisodes,
  ) {
    // Try exact number match first
    for (final candidate in candidateEpisodes) {
      if (candidate.number == targetEpisode.number) {
        return candidate;
      }
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
    return normalizedThumbnail == normalizedCover;
  }

  /// Normalize an image URL for comparison
  ///
  /// Removes common size suffixes and variations to compare base URLs
  String _normalizeImageUrl(String url) {
    // Remove common size suffixes from various providers
    // MyAnimeList: /images/anime/1079/138100l.jpg -> /images/anime/1079/138100
    // Kitsu: /poster_images/1376/large.jpg -> /poster_images/1376
    String normalized = url
        .replaceAll(
          RegExp(
            r'[_-]?(small|medium|large|original|l|m|s)\.(jpg|jpeg|png|webp)$',
            caseSensitive: false,
          ),
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

    // Create aggregated details
    final aggregatedDetails = primaryDetails.copyWith(
      characters: mergedCharacters.isNotEmpty ? mergedCharacters : null,
      staff: mergedStaff.isNotEmpty ? mergedStaff : null,
      recommendations: mergedRecommendations.isNotEmpty
          ? mergedRecommendations
          : null,
    );

    Logger.info(
      'Aggregated details: ${mergedCharacters.length} characters, '
      '${mergedStaff.length} staff, ${mergedRecommendations.length} recommendations',
    );

    return aggregatedDetails;
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
