import 'dart:math';
import '../domain/entities/media_entity.dart';
import 'logger.dart';
import 'provider_cache.dart';
import 'retry_handler.dart';

/// Represents a match found for a media item in another provider
class ProviderMatch {
  final String providerId;
  final String providerMediaId;
  final double confidence;
  final String matchedTitle;
  final MediaEntity? mediaEntity;

  const ProviderMatch({
    required this.providerId,
    required this.providerMediaId,
    required this.confidence,
    required this.matchedTitle,
    this.mediaEntity,
  });
}

/// Handles cross-provider matching using fuzzy title matching and confidence scoring
class CrossProviderMatcher {
  /// Minimum confidence threshold for auto-matching (80%)
  static const double minConfidenceThreshold = 0.8;

  /// Retry handler for network operations
  final RetryHandler retryHandler;

  CrossProviderMatcher({RetryHandler? retryHandler})
    : retryHandler = retryHandler ?? RetryHandler();

  /// Calculate Levenshtein distance between two strings
  /// This measures the minimum number of single-character edits needed
  /// to change one string into another
  int levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    // Create a matrix to store distances
    final matrix = List.generate(
      s1.length + 1,
      (i) => List.filled(s2.length + 1, 0),
    );

    // Initialize first row and column
    for (int i = 0; i <= s1.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= s2.length; j++) {
      matrix[0][j] = j;
    }

    // Fill in the rest of the matrix
    for (int i = 1; i <= s1.length; i++) {
      for (int j = 1; j <= s2.length; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1, // deletion
          matrix[i][j - 1] + 1, // insertion
          matrix[i - 1][j - 1] + cost, // substitution
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[s1.length][s2.length];
  }

  /// Normalize a title for comparison by:
  /// - Converting to lowercase
  /// - Removing special characters (keeping alphanumeric and spaces)
  /// - Removing year suffixes (e.g., "(2023)", "- 2023")
  /// - Removing season indicators (e.g., "Season 2", "S2")
  /// - Trimming whitespace
  /// - Collapsing multiple spaces to single space
  String normalizeTitle(String title) {
    String normalized = title.toLowerCase();

    // Remove year suffixes: (2023), - 2023, etc.
    normalized = normalized.replaceAll(
      RegExp(r'[\(\[\-]\s*\d{4}\s*[\)\]]?'),
      '',
    );
    normalized = normalized.replaceAll(RegExp(r'\s+\d{4}\s*$'), '');

    // Remove season indicators: Season 2, S2, 2nd Season, etc.
    normalized = normalized.replaceAll(RegExp(r'\s+season\s+\d+'), '');
    normalized = normalized.replaceAll(RegExp(r'\s+s\d+'), '');
    normalized = normalized.replaceAll(
      RegExp(r'\s+\d+(st|nd|rd|th)\s+season'),
      '',
    );

    // Remove special characters, keep only alphanumeric and spaces
    normalized = normalized.replaceAll(RegExp(r'[^a-z0-9\s]'), '');

    // Collapse multiple spaces and trim
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();

    return normalized;
  }

  String _buildCacheKey({
    required String title,
    String? englishTitle,
    String? romajiTitle,
    int? year,
    required MediaType type,
  }) {
    final normalizedTitle = normalizeTitle(title);
    final normalizedEnglish = englishTitle != null
        ? normalizeTitle(englishTitle)
        : '';
    final normalizedRomaji = romajiTitle != null
        ? normalizeTitle(romajiTitle)
        : '';
    final yearPart = year?.toString() ?? 'unknown';
    return '$normalizedTitle|$normalizedEnglish|$normalizedRomaji|$yearPart|${type.name}';
  }

  /// Remove cached mappings for a given media descriptor if present
  Future<void> invalidateCachedMatches({
    required String title,
    String? englishTitle,
    String? romajiTitle,
    int? year,
    required MediaType type,
    required String primarySourceId,
    required ProviderCache cache,
  }) async {
    final cacheKey = _buildCacheKey(
      title: title,
      englishTitle: englishTitle,
      romajiTitle: romajiTitle,
      year: year,
      type: type,
    );

    try {
      await cache.removeMapping(
        primaryProviderId: primarySourceId,
        primaryMediaId: cacheKey,
      );
      Logger.info(
        'Invalidated cached provider mappings for "$title" ($cacheKey)',
        tag: 'CrossProviderMatcher',
      );
    } catch (e) {
      Logger.error(
        'Failed to invalidate cached mappings for "$title"',
        tag: 'CrossProviderMatcher',
        error: e,
      );
    }
  }

  /// Calculate confidence score for a potential match
  /// Returns a value between 0.0 and 1.0
  ///
  /// Scoring breakdown:
  /// - Title similarity: 80% weight
  /// - Year matching: 10% bonus
  /// - Type matching: 10% bonus
  double calculateMatchConfidence({
    required String sourceTitle,
    required String targetTitle,
    String? sourceEnglishTitle,
    String? targetEnglishTitle,
    String? sourceRomajiTitle,
    String? targetRomajiTitle,
    int? sourceYear,
    int? targetYear,
    MediaType? sourceType,
    MediaType? targetType,
  }) {
    // Normalize all titles
    final normSource = normalizeTitle(sourceTitle);
    final normTarget = normalizeTitle(targetTitle);

    // Calculate title similarity (0.0 to 1.0)
    double titleSimilarity = _calculateTitleSimilarity(normSource, normTarget);

    // Also check English titles if available
    if (sourceEnglishTitle != null && targetEnglishTitle != null) {
      final normSourceEng = normalizeTitle(sourceEnglishTitle);
      final normTargetEng = normalizeTitle(targetEnglishTitle);
      final engSimilarity = _calculateTitleSimilarity(
        normSourceEng,
        normTargetEng,
      );
      titleSimilarity = max(titleSimilarity, engSimilarity);
    }

    // Also check Romaji titles if available
    if (sourceRomajiTitle != null && targetRomajiTitle != null) {
      final normSourceRom = normalizeTitle(sourceRomajiTitle);
      final normTargetRom = normalizeTitle(targetRomajiTitle);
      final romSimilarity = _calculateTitleSimilarity(
        normSourceRom,
        normTargetRom,
      );
      titleSimilarity = max(titleSimilarity, romSimilarity);
    }

    // Year matching bonus
    double yearBonus = 0.0;
    if (sourceYear != null && targetYear != null) {
      if (sourceYear == targetYear) {
        yearBonus = 0.1;
      } else if ((sourceYear - targetYear).abs() <= 1) {
        // Adjacent years get partial credit (e.g., different release dates)
        yearBonus = 0.05;
      }
    }

    // Type matching bonus
    double typeBonus = 0.0;
    if (sourceType != null && targetType != null && sourceType == targetType) {
      typeBonus = 0.1;
    }

    // Weighted combination
    final confidence = (titleSimilarity * 0.8) + yearBonus + typeBonus;
    return confidence.clamp(0.0, 1.0);
  }

  /// Calculate similarity between two normalized titles
  /// Returns a value between 0.0 (completely different) and 1.0 (identical)
  double _calculateTitleSimilarity(String normSource, String normTarget) {
    if (normSource == normTarget) return 1.0;
    if (normSource.isEmpty || normTarget.isEmpty) return 0.0;

    final distance = levenshteinDistance(normSource, normTarget);
    final maxLength = max(normSource.length, normTarget.length);
    final similarity = 1.0 - (distance / maxLength);

    return similarity.clamp(0.0, 1.0);
  }

  /// Check if a match confidence is high enough for auto-matching
  bool isHighConfidenceMatch(double confidence) {
    return confidence >= minConfidenceThreshold;
  }

  /// Find the best match from a list of potential matches
  /// Returns null if no high-confidence match is found
  ProviderMatch? findBestMatch(List<ProviderMatch> matches) {
    if (matches.isEmpty) return null;

    // Sort by confidence (highest first)
    final sortedMatches = List<ProviderMatch>.from(matches)
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    final bestMatch = sortedMatches.first;

    // Only return if it meets the confidence threshold
    return isHighConfidenceMatch(bestMatch.confidence) ? bestMatch : null;
  }

  /// Find matches for a media item across all providers
  ///
  /// Searches all available providers (excluding the primary source) in parallel
  /// to find matching media items. Uses fuzzy title matching and confidence scoring
  /// to identify high-quality matches.
  ///
  /// Parameters:
  /// - [title]: Primary title to search for
  /// - [type]: Media type (anime, manga, movie, tvShow)
  /// - [primarySourceId]: The source ID to exclude from search
  /// - [englishTitle]: Optional English title for better matching
  /// - [romajiTitle]: Optional Romaji title for better matching
  /// - [year]: Optional year for improved confidence scoring
  /// - [searchFunction]: Function to search a specific provider
  /// - [cache]: Optional cache for storing/retrieving mappings
  ///
  /// Returns a map of provider ID to ProviderMatch for all high-confidence matches
  Future<Map<String, ProviderMatch>> findMatches({
    required String title,
    required MediaType type,
    required String primarySourceId,
    String? englishTitle,
    String? romajiTitle,
    int? year,
    required Future<List<MediaEntity>> Function(
      String query,
      String providerId,
      MediaType type,
    )
    searchFunction,
    ProviderCache? cache,
  }) async {
    final startTime = DateTime.now();
    Logger.info(
      'Starting cross-provider match search for "$title" (type: $type, primary: $primarySourceId)',
      tag: 'CrossProviderMatcher',
    );

    final cacheKey = _buildCacheKey(
      title: title,
      englishTitle: englishTitle,
      romajiTitle: romajiTitle,
      year: year,
      type: type,
    );

    // Check cache first
    if (cache != null) {
      try {
        final cachedMappings = await cache.getMappings(
          primaryProviderId: primarySourceId,
          primaryMediaId: cacheKey,
        );

        if (cachedMappings != null && cachedMappings.isNotEmpty) {
          final duration = DateTime.now().difference(startTime).inMilliseconds;
          Logger.info(
            'Cache HIT: Found ${cachedMappings.length} cached mappings for "$title" in ${duration}ms',
            tag: 'CrossProviderMatcher',
          );
          // Return cached mappings as ProviderMatch objects
          // Note: We don't have full MediaEntity from cache, so mediaEntity will be null
          return cachedMappings.map((providerId, mediaId) {
            return MapEntry(
              providerId,
              ProviderMatch(
                providerId: providerId,
                providerMediaId: mediaId,
                confidence: 1.0, // Cached matches are assumed high confidence
                matchedTitle: title,
                mediaEntity: null,
              ),
            );
          });
        } else {
          Logger.info(
            'Cache MISS: No cached mappings found for "$title"',
            tag: 'CrossProviderMatcher',
          );
        }
      } catch (e) {
        Logger.error(
          'Failed to retrieve cached mappings',
          tag: 'CrossProviderMatcher',
          error: e,
        );
        // Continue with fresh search on cache error
      }
    }

    // List of all available providers
    final allProviders = ['tmdb', 'anilist', 'jikan', 'kitsu', 'simkl'];

    // Remove primary source from search list
    final providersToSearch = allProviders
        .where((id) => id.toLowerCase() != primarySourceId.toLowerCase())
        .toList();

    Logger.info(
      'Searching for matches across ${providersToSearch.length} providers: $providersToSearch',
      tag: 'CrossProviderMatcher',
    );

    // Search all providers in parallel with timeout and retry logic
    final searchFutures = providersToSearch.map((providerId) async {
      try {
        // Execute search with retry logic and timeout
        final results = await retryHandler.execute<List<MediaEntity>>(
          operation: () => searchFunction(title, providerId, type).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              Logger.warning('Search timeout for provider $providerId');
              return <MediaEntity>[];
            },
          ),
          providerId: providerId,
          operationName: 'Search $providerId for "$title"',
        );

        if (results.isEmpty) {
          Logger.info(
            'No results found in provider $providerId',
            tag: 'CrossProviderMatcher',
          );
          return null;
        }

        // Calculate confidence for each result and find best match
        ProviderMatch? bestMatch;
        double highestConfidence = 0.0;

        for (final result in results) {
          final confidence = calculateMatchConfidence(
            sourceTitle: title,
            targetTitle: result.title,
            sourceEnglishTitle: englishTitle,
            targetEnglishTitle: null, // MediaEntity doesn't have englishTitle
            sourceRomajiTitle: romajiTitle,
            targetRomajiTitle: null, // MediaEntity doesn't have romajiTitle
            sourceYear: year,
            targetYear: result.startDate?.year,
            sourceType: type,
            targetType: result.type,
          );

          if (confidence > highestConfidence) {
            highestConfidence = confidence;
            bestMatch = ProviderMatch(
              providerId: providerId,
              providerMediaId: result.id,
              confidence: confidence,
              matchedTitle: result.title,
              mediaEntity: result,
            );
          }
        }

        // Only return if confidence meets threshold
        if (bestMatch != null && isHighConfidenceMatch(bestMatch.confidence)) {
          Logger.info(
            'Found high-confidence match in $providerId: "${bestMatch.matchedTitle}" (confidence: ${bestMatch.confidence.toStringAsFixed(2)})',
            tag: 'CrossProviderMatcher',
          );
          return bestMatch;
        } else {
          Logger.info(
            'No high-confidence match in $providerId (best confidence: ${highestConfidence.toStringAsFixed(2)})',
            tag: 'CrossProviderMatcher',
          );
          return null;
        }
      } catch (e) {
        // Handle provider failures gracefully - log and continue with other providers
        Logger.error(
          'Provider FAILURE: Search failed for $providerId after retries',
          tag: 'CrossProviderMatcher',
          error: e,
        );
        return null;
      }
    });

    // Wait for all searches to complete
    final results = await Future.wait(searchFutures);

    // Build map of successful matches
    final matches = <String, ProviderMatch>{};
    for (final match in results) {
      if (match != null) {
        matches[match.providerId] = match;
      }
    }

    final duration = DateTime.now().difference(startTime).inMilliseconds;
    Logger.info(
      'Match search completed: Found ${matches.length} high-confidence matches in ${duration}ms',
      tag: 'CrossProviderMatcher',
    );

    // Log individual match details
    if (matches.isNotEmpty) {
      for (final entry in matches.entries) {
        Logger.debug(
          'Match: ${entry.key} -> "${entry.value.matchedTitle}" (confidence: ${entry.value.confidence.toStringAsFixed(2)})',
          tag: 'CrossProviderMatcher',
        );
      }
    }

    // Store matches in cache
    if (cache != null && matches.isNotEmpty) {
      try {
        final mappings = matches.map(
          (providerId, match) => MapEntry(providerId, match.providerMediaId),
        );

        await cache.storeMapping(
          primaryProviderId: primarySourceId,
          primaryMediaId: cacheKey,
          providerMappings: mappings,
        );

        Logger.info(
          'Stored ${mappings.length} provider mappings in cache',
          tag: 'CrossProviderMatcher',
        );
      } catch (e) {
        Logger.error(
          'Failed to store mappings in cache',
          tag: 'CrossProviderMatcher',
          error: e,
        );
        // Non-critical error, continue
      }
    }

    return matches;
  }
}
