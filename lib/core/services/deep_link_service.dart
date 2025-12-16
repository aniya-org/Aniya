import 'dart:async';
import 'dart:io';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import '../data/models/deep_link_models.dart';
import '../data/models/repository_config_model.dart';
import '../domain/entities/extension_entity.dart';
import '../utils/logger.dart';
import '../utils/platform_utils.dart';
import 'deep_link_handler.dart';

/// Service that manages deep link listening and processing.
///
/// This service integrates with the app_links package to listen for incoming
/// deep links and processes them using the DeepLinkHandler.
///
/// Supported schemes:
/// - `aniyomi://add-repo?url={repo_url}`
/// - `tachiyomi://add-repo?url={repo_url}`
/// - `mangayomi://add-repo?url={anime_url}&manga_url={manga_url}&novel_url={novel_url}`
/// - `dar://add-repo?url={anime_url}&manga_url={manga_url}&novel_url={novel_url}`
/// - `cloudstreamrepo://{repo_url}`
/// - `https://cs.repo/?{repo_url}`
class DeepLinkService {
  static const String _tag = 'DeepLinkService';

  final AppLinks? _appLinks;
  final DeepLinkHandler _deepLinkHandler;
  final bool _useDesktopArgumentLinks;

  StreamSubscription<Uri>? _linkSubscription;

  /// Callback invoked when a deep link is successfully processed
  final void Function(DeepLinkResult result)? onDeepLinkProcessed;

  /// Callback invoked when a deep link processing fails
  final void Function(String error)? onDeepLinkError;

  /// Callback to save repository configuration
  final Future<void> Function(ExtensionType type, RepositoryConfig config)?
  onSaveRepository;

  DeepLinkService({
    AppLinks? appLinks,
    DeepLinkHandler? deepLinkHandler,
    this.onDeepLinkProcessed,
    this.onDeepLinkError,
    this.onSaveRepository,
  }) : _useDesktopArgumentLinks =
           PlatformUtils.isWindows || PlatformUtils.isLinux,
       _appLinks = (PlatformUtils.isWindows || PlatformUtils.isLinux)
           ? null
           : (appLinks ?? AppLinks()),
       _deepLinkHandler =
           deepLinkHandler ??
           DeepLinkHandler(onSaveRepository: onSaveRepository);

  /// Initializes the deep link service and starts listening for incoming links.
  ///
  /// This should be called during app initialization.
  Future<void> initialize() async {
    Logger.info('Initializing deep link service...', tag: _tag);

    if (_useDesktopArgumentLinks) {
      await _initializeDesktopLinks();
    }

    if (_appLinks == null) {
      return;
    }

    try {
      await _initializeAppLinks();
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to initialize deep link service',
        tag: _tag,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _initializeAppLinks() async {
    final appLinks = _appLinks;
    if (appLinks == null) {
      return;
    }

    // Check for initial link (app opened via deep link)
    final initialUri = await appLinks.getInitialLink();
    if (initialUri != null) {
      Logger.info('Initial deep link received: $initialUri', tag: _tag);
      await _handleDeepLink(initialUri);
    }

    // Listen for incoming links while app is running
    _linkSubscription = appLinks.uriLinkStream.listen(
      (Uri uri) async {
        Logger.info('Deep link received: $uri', tag: _tag);
        await _handleDeepLink(uri);
      },
      onError: (error) {
        Logger.error('Error receiving deep link', tag: _tag, error: error);
        onDeepLinkError?.call('Failed to receive deep link: $error');
      },
    );

    Logger.info('Deep link service initialized successfully', tag: _tag);
  }

  Future<void> _initializeDesktopLinks() async {
    try {
      final uris = _extractDesktopDeepLinkUris();
      if (uris.isEmpty) {
        Logger.info('No desktop deep link arguments detected', tag: _tag);
        return;
      }

      for (final uri in uris) {
        Logger.info('Desktop deep link received: $uri', tag: _tag);
        await _handleDeepLink(uri);
      }
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to initialize desktop deep link handling',
        tag: _tag,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  List<Uri> _extractDesktopDeepLinkUris() {
    final args = Platform.executableArguments;
    if (args.isEmpty) {
      return const [];
    }

    final uris = <Uri>[];
    for (final rawArg in args) {
      final normalized = _normalizeArgument(rawArg);
      final uri = Uri.tryParse(normalized);
      if (uri == null) continue;
      if (!isSupportedScheme(uri)) continue;
      uris.add(uri);
    }
    return uris;
  }

  String _normalizeArgument(String value) {
    var trimmed = value.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }

    // Remove matching surrounding quotes (single or double)
    if ((trimmed.startsWith('"') && trimmed.endsWith('"')) ||
        (trimmed.startsWith('\'') && trimmed.endsWith('\''))) {
      if (trimmed.length >= 2) {
        trimmed = trimmed.substring(1, trimmed.length - 1);
      }
    }

    return trimmed;
  }

  /// Handles an incoming deep link URI.
  Future<void> _handleDeepLink(Uri uri) async {
    try {
      final result = await _deepLinkHandler.handleDeepLink(uri);

      if (result.success) {
        Logger.info(
          'Deep link processed successfully: ${result.message}',
          tag: _tag,
        );
        onDeepLinkProcessed?.call(result);
      } else {
        Logger.warning(
          'Deep link processing failed: ${result.message}',
          tag: _tag,
        );
        onDeepLinkError?.call(result.message);
      }
    } on DeepLinkParseException catch (e) {
      Logger.warning('Invalid deep link format: ${e.message}', tag: _tag);
      onDeepLinkError?.call(e.message);
    } catch (e, stackTrace) {
      Logger.error(
        'Unexpected error processing deep link',
        tag: _tag,
        error: e,
        stackTrace: stackTrace,
      );
      onDeepLinkError?.call('Failed to process deep link: $e');
    }
  }

  /// Manually processes a deep link URI.
  ///
  /// This can be used to test deep link handling or process links from other sources.
  Future<DeepLinkResult> processDeepLink(Uri uri) async {
    return _deepLinkHandler.handleDeepLink(uri);
  }

  /// Checks if a URI is a supported deep link scheme.
  bool isSupportedScheme(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();

    return scheme == 'aniya' ||
        scheme == 'aniyomi' ||
        scheme == 'tachiyomi' ||
        scheme == 'mangayomi' ||
        scheme == 'dar' ||
        scheme == 'cloudstreamrepo' ||
        host == 'cs.repo';
  }

  /// Disposes of the deep link service and stops listening for links.
  void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
    Logger.info('Deep link service disposed', tag: _tag);
  }
}

/// Mixin to add deep link handling capabilities to a StatefulWidget.
///
/// Usage:
/// ```dart
/// class _MyAppState extends State<MyApp> with DeepLinkMixin {
///   @override
///   void initState() {
///     super.initState();
///     initializeDeepLinks(
///       onSuccess: (result) => showSnackBar(result.message),
///       onError: (error) => showErrorSnackBar(error),
///       onSaveRepository: (type, config) => viewModel.saveRepository(type, config),
///     );
///   }
///
///   @override
///   void dispose() {
///     disposeDeepLinks();
///     super.dispose();
///   }
/// }
/// ```
mixin DeepLinkMixin<T extends StatefulWidget> on State<T> {
  DeepLinkService? _deepLinkService;

  /// Initializes deep link handling.
  Future<void> initializeDeepLinks({
    void Function(DeepLinkResult result)? onSuccess,
    void Function(String error)? onError,
    Future<void> Function(ExtensionType type, RepositoryConfig config)?
    onSaveRepository,
  }) async {
    _deepLinkService = DeepLinkService(
      onDeepLinkProcessed: onSuccess,
      onDeepLinkError: onError,
      onSaveRepository: onSaveRepository,
    );
    await _deepLinkService!.initialize();
  }

  /// Disposes of deep link handling.
  void disposeDeepLinks() {
    _deepLinkService?.dispose();
    _deepLinkService = null;
  }
}
