import 'package:equatable/equatable.dart';
import '../../domain/entities/extension_entity.dart';

/// Parameters extracted from a deep link URI for extension repository installation
class DeepLinkParams extends Equatable {
  /// The type of extension ecosystem (Aniyomi, Mangayomi, CloudStream, etc.)
  final ExtensionType extensionType;

  /// URL for anime extension repository
  final String? animeRepoUrl;

  /// URL for manga extension repository
  final String? mangaRepoUrl;

  /// URL for novel extension repository
  final String? novelRepoUrl;

  /// CloudStream-specific repositories
  final String? movieRepoUrl;
  final String? tvShowRepoUrl;
  final String? cartoonRepoUrl;
  final String? documentaryRepoUrl;
  final String? livestreamRepoUrl;
  final String? nsfwRepoUrl;

  const DeepLinkParams({
    required this.extensionType,
    this.animeRepoUrl,
    this.mangaRepoUrl,
    this.novelRepoUrl,
    this.movieRepoUrl,
    this.tvShowRepoUrl,
    this.cartoonRepoUrl,
    this.documentaryRepoUrl,
    this.livestreamRepoUrl,
    this.nsfwRepoUrl,
  });

  /// Returns true if at least one repository URL is provided
  bool get hasAnyUrl =>
      animeRepoUrl != null ||
      mangaRepoUrl != null ||
      novelRepoUrl != null ||
      movieRepoUrl != null ||
      tvShowRepoUrl != null ||
      cartoonRepoUrl != null ||
      documentaryRepoUrl != null ||
      livestreamRepoUrl != null ||
      nsfwRepoUrl != null;

  /// Returns a list of all non-null repository URLs (deduplicated)
  List<String> get allUrls {
    final seen = <String>{};
    final urls = <String>[];

    void addIfUnique(String? value) {
      if (value == null) return;
      if (seen.add(value)) {
        urls.add(value);
      }
    }

    addIfUnique(animeRepoUrl);
    addIfUnique(mangaRepoUrl);
    addIfUnique(novelRepoUrl);
    addIfUnique(movieRepoUrl);
    addIfUnique(tvShowRepoUrl);
    addIfUnique(cartoonRepoUrl);
    addIfUnique(documentaryRepoUrl);
    addIfUnique(livestreamRepoUrl);
    addIfUnique(nsfwRepoUrl);

    return urls;
  }

  @override
  List<Object?> get props => [
    extensionType,
    animeRepoUrl,
    mangaRepoUrl,
    novelRepoUrl,
    movieRepoUrl,
    tvShowRepoUrl,
    cartoonRepoUrl,
    documentaryRepoUrl,
    livestreamRepoUrl,
    nsfwRepoUrl,
  ];

  @override
  String toString() =>
      'DeepLinkParams(type: $extensionType, anime: $animeRepoUrl, manga: $mangaRepoUrl, novel: $novelRepoUrl, movie: $movieRepoUrl, tvShow: $tvShowRepoUrl, cartoon: $cartoonRepoUrl, documentary: $documentaryRepoUrl, livestream: $livestreamRepoUrl, nsfw: $nsfwRepoUrl)';
}

/// Result of processing a deep link for extension repository installation
class DeepLinkResult extends Equatable {
  /// Whether the deep link was processed successfully
  final bool success;

  /// Human-readable message describing the result
  final String message;

  /// List of repository URLs that were successfully added
  final List<String> addedRepos;

  const DeepLinkResult({
    required this.success,
    required this.message,
    this.addedRepos = const [],
  });

  /// Creates a successful result
  factory DeepLinkResult.success({
    required String message,
    List<String> addedRepos = const [],
  }) {
    return DeepLinkResult(
      success: true,
      message: message,
      addedRepos: addedRepos,
    );
  }

  /// Creates a failure result
  factory DeepLinkResult.failure({required String message}) {
    return DeepLinkResult(
      success: false,
      message: message,
      addedRepos: const [],
    );
  }

  @override
  List<Object?> get props => [success, message, addedRepos];

  @override
  String toString() =>
      'DeepLinkResult(success: $success, message: $message, addedRepos: $addedRepos)';
}
