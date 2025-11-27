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

  const DeepLinkParams({
    required this.extensionType,
    this.animeRepoUrl,
    this.mangaRepoUrl,
    this.novelRepoUrl,
  });

  /// Returns true if at least one repository URL is provided
  bool get hasAnyUrl =>
      animeRepoUrl != null || mangaRepoUrl != null || novelRepoUrl != null;

  /// Returns a list of all non-null repository URLs
  List<String> get allUrls => [
    if (animeRepoUrl != null) animeRepoUrl!,
    if (mangaRepoUrl != null) mangaRepoUrl!,
    if (novelRepoUrl != null) novelRepoUrl!,
  ];

  @override
  List<Object?> get props => [
    extensionType,
    animeRepoUrl,
    mangaRepoUrl,
    novelRepoUrl,
  ];

  @override
  String toString() =>
      'DeepLinkParams(type: $extensionType, anime: $animeRepoUrl, manga: $mangaRepoUrl, novel: $novelRepoUrl)';
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
