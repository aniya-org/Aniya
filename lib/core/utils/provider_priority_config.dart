/// Configuration class for managing provider priorities across different data types.
///
/// This class defines the priority order for selecting data from different providers
/// when aggregating cross-provider information. Different data types (episodes, images,
/// metadata, chapters) may have different optimal providers.
class ProviderPriorityConfig {
  /// Priority order for episode thumbnails
  /// Kitsu is prioritized for high-quality episode thumbnails
  final List<String> episodeThumbnailPriority;

  /// Priority order for high-resolution images (covers, banners)
  /// TMDB provides the highest quality images
  final List<String> imageQualityPriority;

  /// Priority order for anime metadata (synopsis, ratings, etc.)
  /// AniList has comprehensive anime metadata
  final List<String> animeMetadataPriority;

  /// Priority order for manga chapters
  /// Kitsu is the primary source for manga chapter data
  final List<String> mangaChapterPriority;

  /// Priority order for character information
  /// AniList has detailed character information
  final List<String> characterPriority;

  /// Minimum confidence threshold for auto-matching (0.0 to 1.0)
  /// Matches below this threshold will be ignored
  final double minConfidenceThreshold;

  /// Creates a new provider priority configuration
  ProviderPriorityConfig({
    List<String>? episodeThumbnailPriority,
    List<String>? imageQualityPriority,
    List<String>? animeMetadataPriority,
    List<String>? mangaChapterPriority,
    List<String>? characterPriority,
    double? minConfidenceThreshold,
    // 'jikan', 'anilist', 'kitsu', 'simkl', 'tmdb'
  }) : episodeThumbnailPriority =
           episodeThumbnailPriority ??
           ['tmdb', 'jikan', 'mal', 'myanimelist', 'anilist', 'kitsu', 'simkl'],
       imageQualityPriority =
           imageQualityPriority ??
           ['tmdb', 'jikan', 'mal', 'myanimelist', 'anilist', 'kitsu', 'simkl'],
       animeMetadataPriority =
           animeMetadataPriority ??
           ['jikan', 'mal', 'myanimelist', 'anilist', 'kitsu', 'simkl'],
       mangaChapterPriority = mangaChapterPriority ?? ['kitsu', 'anilist'],
       characterPriority = characterPriority ?? ['anilist', 'jikan', 'kitsu'],
       minConfidenceThreshold = minConfidenceThreshold ?? 0.8 {
    // Validate confidence threshold
    if (this.minConfidenceThreshold < 0.0 ||
        this.minConfidenceThreshold > 1.0) {
      throw ArgumentError(
        'minConfidenceThreshold must be between 0.0 and 1.0, '
        'got ${this.minConfidenceThreshold}',
      );
    }
  }

  /// Creates a default configuration with standard priorities
  factory ProviderPriorityConfig.defaultConfig() {
    return ProviderPriorityConfig();
  }

  /// Creates a copy of this configuration with optional overrides
  ProviderPriorityConfig copyWith({
    List<String>? episodeThumbnailPriority,
    List<String>? imageQualityPriority,
    List<String>? animeMetadataPriority,
    List<String>? mangaChapterPriority,
    List<String>? characterPriority,
    double? minConfidenceThreshold,
  }) {
    return ProviderPriorityConfig(
      episodeThumbnailPriority:
          episodeThumbnailPriority ?? this.episodeThumbnailPriority,
      imageQualityPriority: imageQualityPriority ?? this.imageQualityPriority,
      animeMetadataPriority:
          animeMetadataPriority ?? this.animeMetadataPriority,
      mangaChapterPriority: mangaChapterPriority ?? this.mangaChapterPriority,
      characterPriority: characterPriority ?? this.characterPriority,
      minConfidenceThreshold:
          minConfidenceThreshold ?? this.minConfidenceThreshold,
    );
  }

  /// Gets the priority list for a specific data type
  List<String> getPriorityForDataType(String dataType) {
    switch (dataType.toLowerCase()) {
      case 'episode_thumbnail':
      case 'episode':
        return episodeThumbnailPriority;
      case 'image':
      case 'cover':
      case 'banner':
        return imageQualityPriority;
      case 'anime_metadata':
      case 'anime':
        return animeMetadataPriority;
      case 'manga_chapter':
      case 'chapter':
        return mangaChapterPriority;
      case 'character':
        return characterPriority;
      default:
        // Return anime metadata priority as default
        return animeMetadataPriority;
    }
  }

  /// Checks if a confidence score meets the minimum threshold
  bool meetsConfidenceThreshold(double confidence) {
    return confidence >= minConfidenceThreshold;
  }

  /// Sorts providers by priority for a given data type
  /// Returns a new list with providers sorted according to priority
  List<String> sortProvidersByPriority(
    List<String> providers,
    String dataType,
  ) {
    final priority = getPriorityForDataType(dataType);
    final sorted = <String>[];

    // Add providers in priority order
    for (final provider in priority) {
      if (providers.contains(provider)) {
        sorted.add(provider);
      }
    }

    // Add any remaining providers not in priority list
    for (final provider in providers) {
      if (!sorted.contains(provider)) {
        sorted.add(provider);
      }
    }

    return sorted;
  }

  @override
  String toString() {
    return 'ProviderPriorityConfig('
        'episodeThumbnailPriority: $episodeThumbnailPriority, '
        'imageQualityPriority: $imageQualityPriority, '
        'animeMetadataPriority: $animeMetadataPriority, '
        'mangaChapterPriority: $mangaChapterPriority, '
        'characterPriority: $characterPriority, '
        'minConfidenceThreshold: $minConfidenceThreshold)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ProviderPriorityConfig &&
        _listEquals(other.episodeThumbnailPriority, episodeThumbnailPriority) &&
        _listEquals(other.imageQualityPriority, imageQualityPriority) &&
        _listEquals(other.animeMetadataPriority, animeMetadataPriority) &&
        _listEquals(other.mangaChapterPriority, mangaChapterPriority) &&
        _listEquals(other.characterPriority, characterPriority) &&
        other.minConfidenceThreshold == minConfidenceThreshold;
  }

  @override
  int get hashCode {
    return Object.hash(
      Object.hashAll(episodeThumbnailPriority),
      Object.hashAll(imageQualityPriority),
      Object.hashAll(animeMetadataPriority),
      Object.hashAll(mangaChapterPriority),
      Object.hashAll(characterPriority),
      minConfidenceThreshold,
    );
  }

  /// Helper method to compare two lists for equality
  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
