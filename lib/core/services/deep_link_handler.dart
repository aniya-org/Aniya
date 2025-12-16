import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dartotsu_extension_bridge/Models/Source.dart' as bridge_models;
import '../../eval_extensions/storage/aniya_eval_plugin_store.dart';
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

class _AniyaManifestPlugin {
  final String id;
  final String name;
  final String version;
  final String language;
  final bridge_models.ItemType itemType;
  final String? url;
  final String? sourceCode;

  const _AniyaManifestPlugin({
    required this.id,
    required this.name,
    required this.version,
    required this.language,
    required this.itemType,
    this.url,
    this.sourceCode,
  });
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

  final AniyaEvalPluginStore? _aniyaStore;
  final http.Client _httpClient;

  DeepLinkHandler({
    this.onSaveRepository,
    AniyaEvalPluginStore? aniyaStore,
    http.Client? httpClient,
  }) : _aniyaStore = aniyaStore,
       _httpClient = httpClient ?? http.Client();

  /// Parses a deep link URI and extracts repository parameters.
  ///
  /// Returns [DeepLinkParams] containing the extension type and repository URLs.
  /// Throws [DeepLinkParseException] if the URI format is invalid or missing required parameters.
  DeepLinkParams parseDeepLinkParams(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();

    if (scheme == 'aniya') {
      if (host != 'add-extension' && host != 'add-extension-manifest') {
        throw DeepLinkParseException(
          'Invalid aniya deep link: expected host "add-extension" or "add-extension-manifest", got "${uri.host}"',
        );
      }
      final url = uri.queryParameters['url'];
      if (url == null || url.trim().isEmpty) {
        throw DeepLinkParseException(
          'Missing required parameter "url" in aniya deep link',
        );
      }
      return DeepLinkParams(
        extensionType: ExtensionType.aniya,
        animeRepoUrl: url.trim(),
      );
    }

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

  Future<DeepLinkResult> _handleAniyaDeepLink(Uri uri) async {
    final host = uri.host.toLowerCase();
    if (host != 'add-extension' && host != 'add-extension-manifest') {
      return DeepLinkResult.failure(
        message: 'Invalid aniya deep link host: ${uri.host}',
      );
    }

    final store = _aniyaStore;
    if (store == null) {
      return DeepLinkResult.failure(
        message: 'Aniya extension store is not available',
      );
    }

    await store.init();

    final url = uri.queryParameters['url'];
    if (url == null || url.trim().isEmpty) {
      return DeepLinkResult.failure(
        message: 'Missing required parameter "url" in aniya deep link',
      );
    }

    final normalizedUrl = url.trim();
    final urlUri = Uri.tryParse(normalizedUrl);
    if (urlUri == null ||
        !(urlUri.isScheme('http') || urlUri.isScheme('https'))) {
      return DeepLinkResult.failure(message: 'Invalid URL: $normalizedUrl');
    }

    try {
      if (host == 'add-extension') {
        final sourceCode = await _fetchText(urlUri);
        final plugin = _buildPluginFromParams(
          uri,
          url: normalizedUrl,
          sourceCode: sourceCode,
        );
        await store.put(plugin);
        return DeepLinkResult.success(
          message: 'Installed 1 Aniya extension',
          addedRepos: [normalizedUrl],
        );
      }

      final manifestBody = await _fetchText(urlUri);
      final plugins = _parseManifest(manifestBody);

      if (plugins.isEmpty) {
        return DeepLinkResult.failure(message: 'No plugins found in manifest');
      }

      final installedUrls = <String>[];
      for (final entry in plugins) {
        final pluginUrl = entry.url?.trim();
        final sourceCode =
            entry.sourceCode ??
            (pluginUrl == null ? null : await _fetchText(Uri.parse(pluginUrl)));
        if (sourceCode == null || sourceCode.trim().isEmpty) {
          continue;
        }
        final plugin = AniyaEvalPlugin(
          id: entry.id,
          name: entry.name,
          version: entry.version,
          language: entry.language,
          itemType: entry.itemType,
          url: pluginUrl,
          sourceCode: sourceCode,
        );
        await store.put(plugin);
        if (pluginUrl != null) {
          installedUrls.add(pluginUrl);
        }
      }

      return DeepLinkResult.success(
        message:
            'Installed ${plugins.length} Aniya ${plugins.length == 1 ? 'extension' : 'extensions'}',
        addedRepos: installedUrls.isEmpty ? [normalizedUrl] : installedUrls,
      );
    } catch (e) {
      return DeepLinkResult.failure(
        message: 'Failed to install Aniya extensions: $e',
      );
    }
  }

  Future<String> _fetchText(Uri uri) async {
    final response = await _httpClient.get(uri);
    if (response.statusCode != 200) {
      throw StateError('HTTP ${response.statusCode} fetching $uri');
    }
    return response.body;
  }

  AniyaEvalPlugin _buildPluginFromParams(
    Uri deepLink, {
    required String url,
    required String sourceCode,
  }) {
    final qp = deepLink.queryParameters;
    final id = (qp['id'] ?? _deriveIdFromUrl(url)).trim();
    final name = (qp['name'] ?? _deriveNameFromUrl(url)).trim();
    final version = (qp['version'] ?? '0.0.0').trim();
    final language = (qp['lang'] ?? qp['language'] ?? 'en').trim();
    final itemType = _parseAniyaItemType(qp['itemType'] ?? qp['type']);

    return AniyaEvalPlugin(
      id: id,
      name: name,
      version: version,
      language: language,
      itemType: itemType,
      url: url,
      sourceCode: sourceCode,
    );
  }

  bridge_models.ItemType _parseAniyaItemType(String? raw) {
    final value = (raw ?? 'anime').toLowerCase().trim();
    return bridge_models.ItemType.values.firstWhere(
      (e) => e.name.toLowerCase() == value,
      orElse: () => bridge_models.ItemType.anime,
    );
  }

  String _deriveIdFromUrl(String url) {
    final uri = Uri.tryParse(url);
    final last = uri?.pathSegments.isNotEmpty == true
        ? uri!.pathSegments.last
        : url;
    final withoutExt = last.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
    final normalized = withoutExt.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    return normalized.isEmpty ? 'aniya_plugin' : normalized;
  }

  String _deriveNameFromUrl(String url) {
    final id = _deriveIdFromUrl(url);
    return id.replaceAll('_', ' ').replaceAll('-', ' ').trim();
  }

  List<_AniyaManifestPlugin> _parseManifest(String body) {
    final decoded = jsonDecode(body);
    final List<dynamic> list;
    if (decoded is List) {
      list = decoded;
    } else if (decoded is Map) {
      final plugins =
          decoded['plugins'] ?? decoded['extensions'] ?? decoded['items'];
      if (plugins is List) {
        list = plugins;
      } else {
        list = const [];
      }
    } else {
      list = const [];
    }

    final results = <_AniyaManifestPlugin>[];
    for (final item in list) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final url = (map['url'] ?? map['codeUrl'] ?? map['sourceUrl'])
          ?.toString();
      final sourceCode = (map['sourceCode'] ?? map['code'] ?? map['source'])
          ?.toString();
      final name = map['name']?.toString();

      final resolvedUrl = url?.trim();
      final resolvedId = map['id']?.toString();
      final resolvedName = name?.trim();

      final stableUrlForDerivation = resolvedUrl ?? 'aniya_plugin';
      final finalId = (resolvedId == null || resolvedId.trim().isEmpty)
          ? _deriveIdFromUrl(stableUrlForDerivation)
          : resolvedId.trim();
      final finalName = (resolvedName == null || resolvedName.isEmpty)
          ? _deriveNameFromUrl(stableUrlForDerivation)
          : resolvedName;
      final version = (map['version']?.toString() ?? '0.0.0').trim();
      final language =
          (map['lang']?.toString() ?? map['language']?.toString() ?? 'en')
              .trim();
      final itemType = _parseAniyaItemType(
        map['itemType']?.toString() ?? map['type']?.toString(),
      );

      results.add(
        _AniyaManifestPlugin(
          id: finalId,
          name: finalName,
          version: version,
          language: language,
          itemType: itemType,
          url: resolvedUrl,
          sourceCode: sourceCode,
        ),
      );
    }
    return results;
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
      if (uri.scheme.toLowerCase() == 'aniya') {
        return await _handleAniyaDeepLink(uri);
      }

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
      case ExtensionType.aniya:
        return 'Aniya';
    }
  }
}
