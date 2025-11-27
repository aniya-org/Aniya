import 'package:equatable/equatable.dart';

/// Configuration for extension repository URLs
///
/// Stores the URLs for anime, manga, and novel extension repositories
/// for a specific extension type (Mangayomi, Aniyomi, CloudStream, etc.)
class RepositoryConfig extends Equatable {
  /// URL for anime extension repository
  final String? animeRepoUrl;

  /// URL for manga extension repository
  final String? mangaRepoUrl;

  /// URL for novel extension repository
  final String? novelRepoUrl;

  /// URL for movie extension repository (CloudStream)
  final String? movieRepoUrl;

  /// URL for TV show extension repository (CloudStream)
  final String? tvShowRepoUrl;

  /// URL for cartoon extension repository (CloudStream)
  final String? cartoonRepoUrl;

  /// URL for documentary extension repository (CloudStream)
  final String? documentaryRepoUrl;

  /// URL for livestream extension repository (CloudStream)
  final String? livestreamRepoUrl;

  const RepositoryConfig({
    this.animeRepoUrl,
    this.mangaRepoUrl,
    this.novelRepoUrl,
    this.movieRepoUrl,
    this.tvShowRepoUrl,
    this.cartoonRepoUrl,
    this.documentaryRepoUrl,
    this.livestreamRepoUrl,
  });

  /// Creates an empty configuration with no URLs
  const RepositoryConfig.empty()
    : animeRepoUrl = null,
      mangaRepoUrl = null,
      novelRepoUrl = null,
      movieRepoUrl = null,
      tvShowRepoUrl = null,
      cartoonRepoUrl = null,
      documentaryRepoUrl = null,
      livestreamRepoUrl = null;

  /// Returns true if at least one repository URL is configured
  bool get hasAnyUrl =>
      animeRepoUrl != null ||
      mangaRepoUrl != null ||
      novelRepoUrl != null ||
      movieRepoUrl != null ||
      tvShowRepoUrl != null ||
      cartoonRepoUrl != null ||
      documentaryRepoUrl != null ||
      livestreamRepoUrl != null;

  /// Returns true if all basic repository URLs are configured (anime, manga, novel)
  bool get hasAllUrls =>
      animeRepoUrl != null && mangaRepoUrl != null && novelRepoUrl != null;

  /// Returns true if any CloudStream-specific URLs are configured
  bool get hasCloudStreamUrls =>
      movieRepoUrl != null ||
      tvShowRepoUrl != null ||
      cartoonRepoUrl != null ||
      documentaryRepoUrl != null ||
      livestreamRepoUrl != null;

  /// Returns a list of all non-null repository URLs
  List<String> get allUrls => [
    if (animeRepoUrl != null) animeRepoUrl!,
    if (mangaRepoUrl != null) mangaRepoUrl!,
    if (novelRepoUrl != null) novelRepoUrl!,
    if (movieRepoUrl != null) movieRepoUrl!,
    if (tvShowRepoUrl != null) tvShowRepoUrl!,
    if (cartoonRepoUrl != null) cartoonRepoUrl!,
    if (documentaryRepoUrl != null) documentaryRepoUrl!,
    if (livestreamRepoUrl != null) livestreamRepoUrl!,
  ];

  /// Creates a RepositoryConfig from JSON
  factory RepositoryConfig.fromJson(Map<String, dynamic> json) {
    return RepositoryConfig(
      animeRepoUrl: json['animeRepoUrl'] as String?,
      mangaRepoUrl: json['mangaRepoUrl'] as String?,
      novelRepoUrl: json['novelRepoUrl'] as String?,
      movieRepoUrl: json['movieRepoUrl'] as String?,
      tvShowRepoUrl: json['tvShowRepoUrl'] as String?,
      cartoonRepoUrl: json['cartoonRepoUrl'] as String?,
      documentaryRepoUrl: json['documentaryRepoUrl'] as String?,
      livestreamRepoUrl: json['livestreamRepoUrl'] as String?,
    );
  }

  /// Converts this RepositoryConfig to JSON
  Map<String, dynamic> toJson() {
    return {
      'animeRepoUrl': animeRepoUrl,
      'mangaRepoUrl': mangaRepoUrl,
      'novelRepoUrl': novelRepoUrl,
      'movieRepoUrl': movieRepoUrl,
      'tvShowRepoUrl': tvShowRepoUrl,
      'cartoonRepoUrl': cartoonRepoUrl,
      'documentaryRepoUrl': documentaryRepoUrl,
      'livestreamRepoUrl': livestreamRepoUrl,
    };
  }

  /// Creates a copy of this RepositoryConfig with the given fields replaced
  RepositoryConfig copyWith({
    String? animeRepoUrl,
    String? mangaRepoUrl,
    String? novelRepoUrl,
    String? movieRepoUrl,
    String? tvShowRepoUrl,
    String? cartoonRepoUrl,
    String? documentaryRepoUrl,
    String? livestreamRepoUrl,
    bool clearAnimeUrl = false,
    bool clearMangaUrl = false,
    bool clearNovelUrl = false,
    bool clearMovieUrl = false,
    bool clearTvShowUrl = false,
    bool clearCartoonUrl = false,
    bool clearDocumentaryUrl = false,
    bool clearLivestreamUrl = false,
  }) {
    return RepositoryConfig(
      animeRepoUrl: clearAnimeUrl ? null : (animeRepoUrl ?? this.animeRepoUrl),
      mangaRepoUrl: clearMangaUrl ? null : (mangaRepoUrl ?? this.mangaRepoUrl),
      novelRepoUrl: clearNovelUrl ? null : (novelRepoUrl ?? this.novelRepoUrl),
      movieRepoUrl: clearMovieUrl ? null : (movieRepoUrl ?? this.movieRepoUrl),
      tvShowRepoUrl: clearTvShowUrl
          ? null
          : (tvShowRepoUrl ?? this.tvShowRepoUrl),
      cartoonRepoUrl: clearCartoonUrl
          ? null
          : (cartoonRepoUrl ?? this.cartoonRepoUrl),
      documentaryRepoUrl: clearDocumentaryUrl
          ? null
          : (documentaryRepoUrl ?? this.documentaryRepoUrl),
      livestreamRepoUrl: clearLivestreamUrl
          ? null
          : (livestreamRepoUrl ?? this.livestreamRepoUrl),
    );
  }

  @override
  List<Object?> get props => [
    animeRepoUrl,
    mangaRepoUrl,
    novelRepoUrl,
    movieRepoUrl,
    tvShowRepoUrl,
    cartoonRepoUrl,
    documentaryRepoUrl,
    livestreamRepoUrl,
  ];

  @override
  String toString() =>
      'RepositoryConfig(anime: $animeRepoUrl, manga: $mangaRepoUrl, novel: $novelRepoUrl, movie: $movieRepoUrl, tvShow: $tvShowRepoUrl, cartoon: $cartoonRepoUrl, documentary: $documentaryRepoUrl, livestream: $livestreamRepoUrl)';
}
