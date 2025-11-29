import '../data/models/deep_link_models.dart';
import '../data/models/repository_config_model.dart';
import '../domain/entities/extension_entity.dart';

/// Exception thrown when deep link parsing fails
class DeepLinkParseException implements Exception {
  final String message;
  const DeepLinkParseException(this.message);

  @override
  String toString() => 'DeepLinkParseException: $message';
}

/// Handles incoming deep links for extension repository installation.
///
/// Supports the following URI schemes:
/// - aniyomi://add-repo?url=<repo_url>
/// - tachiyomi://add-repo?url=<repo_url>
/// - mangayomi://add-repo?url=<anime_url>&manga_url=<manga_url>&novel_url=<novel_url>
/// - dar://add-repo?url=<anime_url>&manga_url=<manga_url>&novel_url=<novel_url>
/// - cloudstreamrepo://<repo_url>
/// - https://cs.repo/?<repo_url>
class DeepLinkHandler {
  /// Callback to save repository configuration
  final Future<void> Function(ExtensionType type, RepositoryConfig config)?
  onSaveRepository;

  DeepLinkHandler({this.onSaveRepository});

  /// Parses a deep link URI and extracts repository parameters.
  ///
  /// Returns [DeepLinkParams] containing the extension type and repository URLs.
  /// Throws [DeepLinkParseException] if the URI format is invalid or missing required parameters.
  DeepLinkParams parseDeepLinkParams(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();

    // Handle aniyomi/tachiyomi scheme
    if (scheme == 'aniyomi' || scheme == 'tachiyomi') {
      return _parseAniyomiTachiyomiScheme(uri, scheme);
    }

    // Handle mangayomi/dar scheme
    if (scheme == 'mangayomi' || scheme == 'dar') {
      return _parseMangayomiDarScheme(uri, scheme);
    }

    // Handle cloudstreamrepo scheme
    if (scheme == 'cloudstreamrepo') {
      return _parseCloudStreamRepoScheme(uri);
    }

    // Handle cs.repo host (https://cs.repo/?<repo_url>)
    if (host == 'cs.repo') {
      return _parseCsRepoHost(uri);
    }

    throw DeepLinkParseException('Unsupported link format: $scheme://$host');
  }

  /// Parses aniyomi:// or tachiyomi:// scheme URIs.
  ///
  /// Expected format: aniyomi://add-repo?url=<repo_url>
  /// The 'url' parameter is required and used for all repository types.
  DeepLinkParams _parseAniyomiTachiyomiScheme(Uri uri, String scheme) {
    if (uri.host != 'add-repo') {
      throw DeepLinkParseException(
        'Invalid $scheme deep link: expected host "add-repo", got "${uri.host}"',
      );
    }

    final url = uri.queryParameters['url'];
    if (url == null || url.isEmpty) {
      throw DeepLinkParseException(
        'Missing required parameter "url" in $scheme deep link',
      );
    }

    // Aniyomi/Tachiyomi uses the same URL for manga repository
    return DeepLinkParams(
      extensionType: ExtensionType.aniyomi,
      mangaRepoUrl: url,
    );
  }

  /// Parses mangayomi:// or dar:// scheme URIs.
  ///
  /// Expected format: mangayomi://add-repo?url=<anime_url>&manga_url=<manga_url>&novel_url=<novel_url>
  /// At least one URL parameter must be provided.
  DeepLinkParams _parseMangayomiDarScheme(Uri uri, String scheme) {
    if (uri.host != 'add-repo') {
      throw DeepLinkParseException(
        'Invalid $scheme deep link: expected host "add-repo", got "${uri.host}"',
      );
    }

    final params = uri.queryParameters;

    // 'url' parameter is used as anime URL, or anime_url can be explicit
    final animeUrl = params['anime_url'] ?? params['url'];
    final mangaUrl = params['manga_url'];
    final novelUrl = params['novel_url'];

    if (animeUrl == null && mangaUrl == null && novelUrl == null) {
      throw DeepLinkParseException(
        'Missing required parameters in $scheme deep link. '
        'At least one of "url", "anime_url", "manga_url", or "novel_url" must be provided',
      );
    }

    return DeepLinkParams(
      extensionType: ExtensionType.mangayomi,
      animeRepoUrl: animeUrl,
      mangaRepoUrl: mangaUrl,
      novelRepoUrl: novelUrl,
    );
  }

  /// Parses cloudstreamrepo:// scheme URIs.
  ///
  /// Expected format: cloudstreamrepo://<repo_url>
  /// The path (after the scheme) is the repository URL.
  DeepLinkParams _parseCloudStreamRepoScheme(Uri uri) {
    // The repository URL is in the path, starting after the scheme
    // cloudstreamrepo://https://example.com/repo.json
    // The host + path forms the URL
    String repoUrl;

    if (uri.host.isNotEmpty) {
      // Reconstruct the URL from host and path
      repoUrl = '${uri.host}${uri.path}';

      // Check if it looks like a URL scheme (http/https)
      if (!repoUrl.startsWith('http://') && !repoUrl.startsWith('https://')) {
        // Assume https if no scheme
        repoUrl = 'https://$repoUrl';
      }
    } else if (uri.path.isNotEmpty) {
      repoUrl = uri.path;
      if (!repoUrl.startsWith('http://') && !repoUrl.startsWith('https://')) {
        repoUrl = 'https://$repoUrl';
      }
    } else {
      throw DeepLinkParseException(
        'Missing repository URL in cloudstreamrepo deep link',
      );
    }

    // Add query string if present
    if (uri.query.isNotEmpty) {
      repoUrl = '$repoUrl?${uri.query}';
    }

    return _buildCloudStreamParams(repoUrl);
  }

  DeepLinkParams _buildCloudStreamParams(String repoUrl) {
    return DeepLinkParams(
      extensionType: ExtensionType.cloudstream,
      animeRepoUrl: repoUrl,
      mangaRepoUrl: repoUrl,
      novelRepoUrl: repoUrl,
      movieRepoUrl: repoUrl,
      tvShowRepoUrl: repoUrl,
      cartoonRepoUrl: repoUrl,
      documentaryRepoUrl: repoUrl,
      livestreamRepoUrl: repoUrl,
      nsfwRepoUrl: repoUrl,
    );
  }

  /// Parses cs.repo host URIs.
  ///
  /// Expected format: https://cs.repo/?<repo_url>
  /// The query string is the repository URL.
  DeepLinkParams _parseCsRepoHost(Uri uri) {
    // The repository URL is in the query string
    // https://cs.repo/?https://example.com/repo.json
    final query = uri.query;

    if (query.isEmpty) {
      throw DeepLinkParseException(
        'Missing repository URL in cs.repo deep link',
      );
    }

    String repoUrl = query;

    // The query might be URL-encoded, decode it
    try {
      repoUrl = Uri.decodeComponent(repoUrl);
    } catch (_) {
      // If decoding fails, use as-is
    }

    // Ensure it has a scheme
    if (!repoUrl.startsWith('http://') && !repoUrl.startsWith('https://')) {
      repoUrl = 'https://$repoUrl';
    }

    return _buildCloudStreamParams(repoUrl);
  }

  /// Processes a deep link URI and adds the repositories.
  ///
  /// Returns a [DeepLinkResult] indicating success or failure.
  Future<DeepLinkResult> handleDeepLink(Uri uri) async {
    try {
      final params = parseDeepLinkParams(uri);

      if (!params.hasAnyUrl) {
        return DeepLinkResult.failure(
          message: 'No repository URLs found in deep link',
        );
      }

      // Create repository config from parsed params
      final config = RepositoryConfig(
        animeRepoUrl: params.animeRepoUrl,
        mangaRepoUrl: params.mangaRepoUrl,
        novelRepoUrl: params.novelRepoUrl,
        movieRepoUrl: params.movieRepoUrl,
        tvShowRepoUrl: params.tvShowRepoUrl,
        cartoonRepoUrl: params.cartoonRepoUrl,
        documentaryRepoUrl: params.documentaryRepoUrl,
        livestreamRepoUrl: params.livestreamRepoUrl,
        nsfwRepoUrl: params.nsfwRepoUrl,
      );

      // Save the repository configuration if callback is provided
      if (onSaveRepository != null) {
        await onSaveRepository!(params.extensionType, config);
      }

      // Build success message
      final addedRepos = params.allUrls;
      final repoCount = addedRepos.length;
      final repoWord = repoCount == 1 ? 'repository' : 'repositories';

      return DeepLinkResult.success(
        message:
            'Successfully added $repoCount $repoWord for ${_extensionTypeName(params.extensionType)}',
        addedRepos: addedRepos,
      );
    } on DeepLinkParseException catch (e) {
      return DeepLinkResult.failure(message: e.message);
    } catch (e) {
      return DeepLinkResult.failure(
        message: 'Failed to process deep link: ${e.toString()}',
      );
    }
  }

  /// Returns a human-readable name for the extension type.
  String _extensionTypeName(ExtensionType type) {
    switch (type) {
      case ExtensionType.aniyomi:
        return 'Aniyomi';
      case ExtensionType.mangayomi:
        return 'Mangayomi';
      case ExtensionType.cloudstream:
        return 'CloudStream';
      case ExtensionType.lnreader:
        return 'LnReader';
    }
  }
}
