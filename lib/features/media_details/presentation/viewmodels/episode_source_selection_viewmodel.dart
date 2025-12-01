import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../../../core/domain/entities/extension_entity.dart';
import '../../../../core/domain/entities/media_entity.dart';
import '../../../../core/domain/entities/episode_entity.dart';
import '../../../../core/domain/entities/source_entity.dart';
import '../../../../core/domain/repositories/extension_search_repository.dart';
import '../../../../core/domain/repositories/recent_extensions_repository.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/logger.dart';
import '../../../extensions/controllers/extensions_controller.dart';

/// ViewModel for managing the episode/chapter source selection workflow
/// Handles extension selection, media search, source scraping, and navigation
/// Requirements: 1.3, 2.1, 3.2, 4.1
class EpisodeSourceSelectionViewModel extends ChangeNotifier {
  final ExtensionSearchRepository extensionSearchRepository;
  final RecentExtensionsRepository recentExtensionsRepository;
  final ExtensionsController extensionsController;

  // ============================================================================
  // State Properties
  // ============================================================================

  /// List of extensions compatible with the current media type
  /// Requirements: 1.3, 7.1, 7.2, 7.3, 7.4
  List<ExtensionEntity> _compatibleExtensions = [];

  /// Currently selected extension
  /// Requirements: 2.1
  ExtensionEntity? _selectedExtension;

  /// Currently selected media item
  /// Requirements: 3.5, 4.1
  MediaEntity? _selectedMedia;

  /// Search results from the current search query
  /// Requirements: 3.2, 3.3
  List<MediaEntity> _searchResults = [];

  /// Available sources for the selected media
  /// Requirements: 4.1, 4.2
  List<SourceEntity> _availableSources = [];

  /// Recently used extensions (up to 5)
  /// Requirements: 8.1, 8.2
  List<ExtensionEntity> _recentExtensions = [];

  /// Loading state for extension list
  /// Requirements: 1.3
  bool _isLoadingExtensions = false;

  /// Loading state for media search
  /// Requirements: 2.5, 3.2
  bool _isSearchingMedia = false;

  /// Loading state for source scraping
  /// Requirements: 4.3
  bool _isLoadingSources = false;

  /// Loading state for pagination
  bool _isLoadingMoreResults = false;

  /// Error message if any operation fails
  /// Requirements: 6.1, 6.2, 6.3
  String? _error;

  /// Current search query
  /// Requirements: 3.2
  String? _searchQuery;

  /// Current page number for pagination
  /// Requirements: 3.4
  int _currentSearchPage = 1;

  /// Media data passed to the ViewModel
  MediaEntity? _media;

  /// Episode data passed to the ViewModel
  EpisodeEntity? _episode;

  /// Whether this is for a chapter (true) or episode (false)
  bool _isChapter = false;

  /// Last operation that failed (for retry)
  _LastOperation? _lastFailedOperation;

  // ============================================================================
  // Getters
  // ============================================================================

  List<ExtensionEntity> get compatibleExtensions => _compatibleExtensions;
  ExtensionEntity? get selectedExtension => _selectedExtension;
  MediaEntity? get selectedMedia => _selectedMedia;
  List<MediaEntity> get searchResults => _searchResults;
  List<SourceEntity> get availableSources => _availableSources;
  List<ExtensionEntity> get recentExtensions => _recentExtensions;

  bool get isLoadingExtensions => _isLoadingExtensions;
  bool get isSearchingMedia => _isSearchingMedia;
  bool get isLoadingSources => _isLoadingSources;
  bool get isLoadingMoreResults => _isLoadingMoreResults;

  String? get error => _error;
  String? get searchQuery => _searchQuery;
  int get currentSearchPage => _currentSearchPage;

  MediaEntity? get media => _media;
  EpisodeEntity? get episode => _episode;
  bool get isChapter => _isChapter;

  /// Computed property: whether compatible extensions are available
  /// Requirements: 7.5
  bool get hasCompatibleExtensions => _compatibleExtensions.isNotEmpty;

  /// Computed property: whether more results can be loaded
  /// Requirements: 3.4
  bool get canLoadMoreResults => _searchResults.isNotEmpty;

  // ============================================================================
  // Constructor
  // ============================================================================

  EpisodeSourceSelectionViewModel({
    required this.extensionSearchRepository,
    required this.recentExtensionsRepository,
    ExtensionsController? extensionsController,
  }) : extensionsController =
           extensionsController ?? Get.find<ExtensionsController>();

  // ============================================================================
  // Public Methods
  // ============================================================================

  /// Initialize the ViewModel with media and episode data
  /// Loads compatible extensions and recent extensions
  /// Requirements: 1.3, 7.1, 7.2, 7.3, 7.4, 8.2
  Future<void> initialize({
    required MediaEntity media,
    required EpisodeEntity episode,
    required bool isChapter,
  }) async {
    _media = media;
    _episode = episode;
    _isChapter = isChapter;

    Logger.info(
      'Initializing EpisodeSourceSelectionViewModel for ${media.title}',
      tag: 'EpisodeSourceSelectionViewModel',
    );

    _isLoadingExtensions = true;
    notifyListeners();

    try {
      // Load compatible extensions based on media type
      await _loadCompatibleExtensions(media.type);

      // Load recent extensions
      await _loadRecentExtensions();

      _error = null;
    } catch (e) {
      Logger.error(
        'Error initializing ViewModel',
        tag: 'EpisodeSourceSelectionViewModel',
        error: e,
      );
      _error = 'Failed to load extensions';
    } finally {
      _isLoadingExtensions = false;
      notifyListeners();
    }
  }

  List<ExtensionEntity> _dedupeExtensions(
    List<ExtensionEntity> extensions,
    MediaType mediaType,
  ) {
    final seen = <String>{};
    final preferred = <String, ExtensionEntity>{};
    final priorities = _itemTypePriorities(mediaType);
    for (final extension in extensions) {
      final identifier = _extensionIdentifier(extension);
      if (!seen.add(identifier)) {
        final existing = preferred[identifier]!;
        final existingPriority = priorities[existing.itemType] ?? 999;
        final candidatePriority = priorities[extension.itemType] ?? 999;
        if (candidatePriority < existingPriority) {
          preferred[identifier] = extension;
        }
        continue;
      }
      preferred[identifier] = extension;
    }
    return preferred.values.toList();
  }

  String _extensionIdentifier(ExtensionEntity extension) {
    final apk = extension.apkUrl;
    if (apk != null && apk.isNotEmpty) {
      return '${extension.type.name}:$apk';
    }
    if (extension.id.isNotEmpty) {
      return '${extension.type.name}:${extension.id}';
    }
    return '${extension.type.name}:${extension.name}-${extension.version}';
  }

  Map<ItemType, int> _itemTypePriorities(MediaType mediaType) {
    List<ItemType> ordered;
    switch (mediaType) {
      case MediaType.tvShow:
        ordered = const [
          ItemType.tvShow,
          ItemType.anime,
          ItemType.movie,
          ItemType.cartoon,
          ItemType.documentary,
          ItemType.livestream,
          ItemType.manga,
          ItemType.novel,
        ];
        break;
      case MediaType.movie:
        ordered = const [
          ItemType.movie,
          ItemType.tvShow,
          ItemType.anime,
          ItemType.cartoon,
          ItemType.documentary,
          ItemType.livestream,
          ItemType.manga,
          ItemType.novel,
        ];
        break;
      case MediaType.anime:
        ordered = const [
          ItemType.anime,
          ItemType.tvShow,
          ItemType.cartoon,
          ItemType.movie,
          ItemType.documentary,
          ItemType.livestream,
          ItemType.manga,
          ItemType.novel,
        ];
        break;
      case MediaType.manga:
      case MediaType.novel:
        ordered = const [
          ItemType.manga,
          ItemType.novel,
          ItemType.anime,
          ItemType.tvShow,
          ItemType.movie,
          ItemType.cartoon,
          ItemType.documentary,
          ItemType.livestream,
        ];
        break;
      case MediaType.cartoon:
        ordered = const [
          ItemType.cartoon,
          ItemType.anime,
          ItemType.tvShow,
          ItemType.movie,
          ItemType.documentary,
          ItemType.livestream,
          ItemType.manga,
          ItemType.novel,
        ];
        break;
      case MediaType.documentary:
        ordered = const [
          ItemType.documentary,
          ItemType.tvShow,
          ItemType.movie,
          ItemType.anime,
          ItemType.cartoon,
          ItemType.livestream,
          ItemType.manga,
          ItemType.novel,
        ];
        break;
      case MediaType.livestream:
        ordered = const [
          ItemType.livestream,
          ItemType.tvShow,
          ItemType.anime,
          ItemType.movie,
          ItemType.cartoon,
          ItemType.documentary,
          ItemType.manga,
          ItemType.novel,
        ];
        break;
      case MediaType.nsfw:
        ordered = const [
          ItemType.anime,
          ItemType.manga,
          ItemType.tvShow,
          ItemType.movie,
          ItemType.novel,
          ItemType.cartoon,
          ItemType.documentary,
          ItemType.livestream,
        ];
        break;
    }

    return {for (var i = 0; i < ordered.length; i++) ordered[i]: i};
  }

  /// Select an extension and trigger automatic search
  /// Requirements: 2.1, 8.1
  Future<void> selectExtension(ExtensionEntity extension) async {
    Logger.info(
      'Selecting extension: ${extension.name}',
      tag: 'EpisodeSourceSelectionViewModel',
    );

    _selectedExtension = extension;
    _searchResults = [];
    _selectedMedia = null;
    _availableSources = [];
    _currentSearchPage = 1;
    _error = null;

    // Add to recent extensions
    await _addToRecentExtensions(extension);

    // Trigger automatic search for media title
    await searchMedia(_media?.title ?? '', isAutomatic: true);

    notifyListeners();
  }

  /// Search for media in the selected extension
  /// Requirements: 3.2, 3.4
  Future<void> searchMedia(
    String query, {
    bool isAutomatic = false,
    bool nextPage = false,
  }) async {
    if (_selectedExtension == null) {
      _error = 'No extension selected';
      notifyListeners();
      return;
    }

    if (query.trim().isEmpty && !isAutomatic) {
      _error = 'Search query cannot be empty';
      notifyListeners();
      return;
    }

    Logger.info(
      'Searching for "$query" in ${_selectedExtension!.name}',
      tag: 'EpisodeSourceSelectionViewModel',
    );

    if (nextPage) {
      _isLoadingMoreResults = true;
      _currentSearchPage++;
    } else {
      _isSearchingMedia = true;
      _currentSearchPage = 1;
      _searchResults = [];
    }

    _searchQuery = query;
    _error = null;
    notifyListeners();

    try {
      final result = await extensionSearchRepository.searchMedia(
        query,
        _selectedExtension!,
        _currentSearchPage,
      );

      result.fold(
        (failure) {
          _error = _mapFailureToMessage(failure);
          _lastFailedOperation = _LastOperation(
            type: _OperationType.search,
            query: query,
            page: _currentSearchPage,
          );
          Logger.error(
            'Search failed: $_error',
            tag: 'EpisodeSourceSelectionViewModel',
            error: failure,
          );
        },
        (results) {
          if (nextPage) {
            _searchResults.addAll(results);
          } else {
            _searchResults = results;
          }

          // If automatic search and results found, select the first result
          if (isAutomatic && results.isNotEmpty) {
            _selectedMedia = results.first;
            _loadSources();
          }

          Logger.info(
            'Found ${results.length} results',
            tag: 'EpisodeSourceSelectionViewModel',
          );
        },
      );
    } catch (e) {
      _error = 'An unexpected error occurred';
      _lastFailedOperation = _LastOperation(
        type: _OperationType.search,
        query: query,
        page: _currentSearchPage,
      );
      Logger.error(
        'Unexpected error during search',
        tag: 'EpisodeSourceSelectionViewModel',
        error: e,
      );
    } finally {
      _isSearchingMedia = false;
      _isLoadingMoreResults = false;
      notifyListeners();
    }
  }

  Set<ItemType> _resolveDesiredItemTypes(MediaType mediaType) {
    const videoTypes = {
      ItemType.anime,
      ItemType.tvShow,
      ItemType.movie,
      ItemType.cartoon,
      ItemType.documentary,
      ItemType.livestream,
    };

    const readingTypes = {ItemType.manga, ItemType.novel};

    // Chapters or explicitly text-based media should only show reader extensions.
    if (_isChapter ||
        mediaType == MediaType.manga ||
        mediaType == MediaType.novel) {
      return readingTypes;
    }

    // All video media (anime, TV, movies, etc.) can use any CloudStream video type.
    if (mediaType == MediaType.anime ||
        mediaType == MediaType.tvShow ||
        mediaType == MediaType.movie) {
      return videoTypes;
    }

    // Fallback to both sets so niche categories (e.g., unknown) still show something.
    return {...videoTypes, ...readingTypes};
  }

  /// Select a media item and trigger source scraping
  /// Requirements: 3.5, 4.1
  Future<void> selectMedia(MediaEntity media) async {
    Logger.info(
      'Selecting media: ${media.title}',
      tag: 'EpisodeSourceSelectionViewModel',
    );

    _selectedMedia = media;
    _availableSources = [];
    _error = null;
    notifyListeners();

    await _loadSources();
  }

  /// Select a source and prepare for navigation
  /// Requirements: 4.5, 5.1, 5.2, 5.3, 5.4
  Future<void> selectSource(SourceEntity source) async {
    Logger.info(
      'Selecting source: ${source.name}',
      tag: 'EpisodeSourceSelectionViewModel',
    );

    if (_selectedMedia == null || _episode == null) {
      _error = 'Invalid state for source selection';
      notifyListeners();
      return;
    }

    // Navigation will be handled by the UI layer
    // This method just validates the selection
    _error = null;
    notifyListeners();
  }

  /// Retry the last failed operation
  /// Requirements: 6.5
  Future<void> retryLastOperation() async {
    if (_lastFailedOperation == null) {
      _error = 'No operation to retry';
      notifyListeners();
      return;
    }

    Logger.info(
      'Retrying last operation',
      tag: 'EpisodeSourceSelectionViewModel',
    );

    final operation = _lastFailedOperation!;

    switch (operation.type) {
      case _OperationType.search:
        await searchMedia(operation.query ?? '', nextPage: false);
        break;
      case _OperationType.loadSources:
        await _loadSources();
        break;
    }
  }

  /// Clear the error state
  /// Requirements: 6.4
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ============================================================================
  // Private Methods
  // ============================================================================

  /// Load compatible extensions based on media type
  Future<void> _loadCompatibleExtensions(MediaType mediaType) async {
    try {
      final installed = extensionsController.installedEntities;
      final desiredItemTypes = _resolveDesiredItemTypes(mediaType);
      final filtered = installed
          .where((extension) => desiredItemTypes.contains(extension.itemType))
          .toList();
      _compatibleExtensions = _dedupeExtensions(filtered, mediaType);

      Logger.info(
        'Loaded ${_compatibleExtensions.length} compatible extensions',
        tag: 'EpisodeSourceSelectionViewModel',
      );
    } catch (e) {
      Logger.error(
        'Error loading compatible extensions',
        tag: 'EpisodeSourceSelectionViewModel',
        error: e,
      );
      rethrow;
    }
  }

  /// Load recent extensions from storage
  Future<void> _loadRecentExtensions() async {
    try {
      final result = await recentExtensionsRepository.getRecentExtensions();

      result.fold(
        (failure) {
          Logger.warning(
            'Failed to load recent extensions',
            tag: 'EpisodeSourceSelectionViewModel',
          );
          _recentExtensions = [];
        },
        (extensions) {
          _recentExtensions = extensions;
          Logger.info(
            'Loaded ${extensions.length} recent extensions',
            tag: 'EpisodeSourceSelectionViewModel',
          );
        },
      );
    } catch (e) {
      Logger.error(
        'Error loading recent extensions',
        tag: 'EpisodeSourceSelectionViewModel',
        error: e,
      );
      _recentExtensions = [];
    }
  }

  /// Load sources for the selected media
  Future<void> _loadSources() async {
    if (_selectedExtension == null ||
        _selectedMedia == null ||
        _episode == null) {
      _error = 'Invalid state for loading sources';
      notifyListeners();
      return;
    }

    Logger.info(
      'Loading sources for ${_selectedMedia!.title}',
      tag: 'EpisodeSourceSelectionViewModel',
    );

    _isLoadingSources = true;
    _error = null;
    notifyListeners();

    try {
      final result = await extensionSearchRepository.getSources(
        _selectedMedia!,
        _selectedExtension!,
        _episode!,
      );

      result.fold(
        (failure) {
          _error = _mapFailureToMessage(failure);
          _lastFailedOperation = _LastOperation(
            type: _OperationType.loadSources,
          );
          Logger.error(
            'Failed to load sources: $_error',
            tag: 'EpisodeSourceSelectionViewModel',
            error: failure,
          );
        },
        (sources) {
          _availableSources = sources;
          Logger.info(
            'Loaded ${sources.length} sources',
            tag: 'EpisodeSourceSelectionViewModel',
          );
        },
      );
    } catch (e) {
      _error = 'An unexpected error occurred';
      _lastFailedOperation = _LastOperation(type: _OperationType.loadSources);
      Logger.error(
        'Unexpected error loading sources',
        tag: 'EpisodeSourceSelectionViewModel',
        error: e,
      );
    } finally {
      _isLoadingSources = false;
      notifyListeners();
    }
  }

  /// Add extension to recent extensions list
  Future<void> _addToRecentExtensions(ExtensionEntity extension) async {
    try {
      final result = await recentExtensionsRepository.addRecentExtension(
        extension,
      );

      result.fold(
        (failure) {
          Logger.warning(
            'Failed to add extension to recent',
            tag: 'EpisodeSourceSelectionViewModel',
          );
        },
        (_) {
          // Update local recent extensions list
          _recentExtensions.removeWhere((e) => e.id == extension.id);
          _recentExtensions.insert(0, extension);
          if (_recentExtensions.length > 5) {
            _recentExtensions = _recentExtensions.sublist(0, 5);
          }
          Logger.info(
            'Added extension to recent',
            tag: 'EpisodeSourceSelectionViewModel',
          );
        },
      );
    } catch (e) {
      Logger.error(
        'Error adding extension to recent',
        tag: 'EpisodeSourceSelectionViewModel',
        error: e,
      );
    }
  }

  /// Map Failure to user-friendly error message
  String _mapFailureToMessage(Failure failure) {
    if (failure is NetworkFailure) {
      return 'Network error. Please check your connection.';
    } else if (failure is ValidationFailure) {
      return failure.message;
    } else if (failure is UnknownFailure) {
      return failure.message;
    }
    return 'An error occurred. Please try again.';
  }
}

/// Enum for operation types that can fail and be retried
enum _OperationType { search, loadSources }

/// Data class for tracking the last failed operation
class _LastOperation {
  final _OperationType type;
  final String? query;
  final int? page;

  _LastOperation({required this.type, this.query, this.page});
}
