import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../../../../core/domain/entities/media_entity.dart';
import '../../../../core/domain/usecases/search_media_usecase.dart';
import '../../../../core/domain/repositories/media_repository.dart';
import '../../../../core/utils/error_message_mapper.dart';
import '../../../../core/utils/logger.dart';

class SearchViewModel extends ChangeNotifier {
  final SearchMediaUseCase searchMedia;

  SearchViewModel({required this.searchMedia});

  List<MediaEntity> _searchResults = [];
  String _query = '';
  MediaType? _typeFilter;
  String? _sourceFilter;
  bool _isLoading = false;
  String? _error;
  Timer? _debounceTimer;
  final LinkedHashMap<String, SourceResultGroup> _sourceGroups =
      LinkedHashMap();

  List<MediaEntity> get searchResults => _searchResults;
  String get query => _query;
  MediaType? get typeFilter => _typeFilter;
  String? get sourceFilter => _sourceFilter;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<SourceResultGroup> get sourceGroups => _sourceGroups.values.toList();
  bool get hasResults =>
      _sourceGroups.values.any((group) => group.items.isNotEmpty);
  bool get hasActiveSources => _sourceGroups.isNotEmpty;

  // Debounce duration for search queries
  static const Duration _debounceDuration = Duration(milliseconds: 500);

  Future<void> search(String query) async {
    _query = query;

    // Cancel previous timer if it exists
    _debounceTimer?.cancel();

    if (query.isEmpty) {
      clearResults();
      return;
    }

    // Set loading state immediately
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Create new debounce timer
    _debounceTimer = Timer(_debounceDuration, () async {
      await _performSearch();
    });
  }

  Future<void> _performSearch() async {
    if (_query.isEmpty) {
      clearResults();
      return;
    }

    Logger.info(
      'Performing search: query="$_query", typeFilter=$_typeFilter, sourceFilter=$_sourceFilter',
      tag: 'SearchViewModel',
    );

    try {
      _resetSourceGroups();

      final typesToSearch = _typeFilter != null
          ? <MediaType>[_typeFilter!]
          : _computeTypesForCurrentSource();

      final aggregatedResults = <MediaEntity>[];

      for (final type in typesToSearch) {
        Logger.debug(
          'Searching type: $type with sourceId: $_sourceFilter',
          tag: 'SearchViewModel',
        );

        final result = await searchMedia(
          SearchMediaParams(
            query: _query,
            type: type,
            sourceId: _sourceFilter,
            onSourceProgress: _handleSourceProgress,
          ),
        );

        final handled = result.fold(
          (failure) {
            final errorMsg = ErrorMessageMapper.mapFailureToMessage(failure);
            Logger.error(
              'Failed to search for type: $type - $errorMsg',
              tag: 'SearchViewModel',
              error: failure,
            );
            return <MediaEntity>[];
          },
          (results) {
            Logger.debug(
              'Found ${results.length} results for type: $type',
              tag: 'SearchViewModel',
            );
            return results;
          },
        );

        aggregatedResults.addAll(handled);
      }

      _searchResults = aggregatedResults;
      _error = null;
      Logger.info(
        'Search completed: ${_searchResults.length} total results (types searched: ${typesToSearch.length})',
        tag: 'SearchViewModel',
      );
    } catch (e, stackTrace) {
      _error = 'An unexpected error occurred. Please try again.';
      Logger.error(
        'Unexpected error in search',
        tag: 'SearchViewModel',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setTypeFilter(MediaType? type) {
    _typeFilter = type;
    // Re-run search with new filter if there's a query
    if (_query.isNotEmpty) {
      search(_query);
    } else {
      notifyListeners();
    }
  }

  void setSourceFilter(String? source) {
    _sourceFilter = source;
    // Re-run search with new filter if there's a query
    if (_query.isNotEmpty) {
      search(_query);
    } else {
      notifyListeners();
    }
  }

  void clearResults() {
    _searchResults = [];
    _query = '';
    _error = null;
    _isLoading = false;
    _debounceTimer?.cancel();
    _sourceGroups.clear();
    notifyListeners();
  }

  void _resetSourceGroups() {
    _sourceGroups.clear();
    _searchResults = [];
  }

  void _handleSourceProgress(SourceSearchProgress progress) {
    final existing = _sourceGroups[progress.sourceId];
    List<MediaEntity> mergedItems;

    if (progress.isLoading || progress.results.isEmpty) {
      mergedItems = progress.isLoading ? const [] : (existing?.items ?? []);
    } else {
      final currentItems = List<MediaEntity>.from(existing?.items ?? []);
      final seen = currentItems
          .map((item) => '${item.sourceId}:${item.id}')
          .toSet();
      for (final item in progress.results) {
        final key = '${item.sourceId}:${item.id}';
        if (seen.add(key)) {
          currentItems.add(item);
        }
      }
      mergedItems = currentItems;
    }

    final updated = SourceResultGroup(
      sourceId: progress.sourceId,
      displayName: progress.sourceName,
      items: mergedItems,
      isLoading: progress.isLoading,
      hasError: progress.hasError,
      errorMessage: progress.errorMessage,
    );

    _sourceGroups[progress.sourceId] = updated;
    _searchResults = _sourceGroups.values
        .expand((group) => group.items)
        .toList();
    notifyListeners();
  }

  List<MediaType> _computeTypesForCurrentSource() {
    if (_sourceFilter == null) {
      return MediaType.values;
    }

    final supported = _getSupportedTypesForSource(_sourceFilter!);
    return supported.isEmpty ? MediaType.values : supported;
  }

  List<MediaType> _getSupportedTypesForSource(String sourceId) {
    switch (sourceId.toLowerCase()) {
      case 'tmdb':
        return const [MediaType.movie, MediaType.tvShow];
      case 'anilist':
      case 'jikan':
      case 'mal':
      case 'myanimelist':
      case 'kitsu':
        return const [MediaType.anime, MediaType.manga, MediaType.novel];
      case 'simkl':
        return const [
          MediaType.anime,
          MediaType.manga,
          MediaType.movie,
          MediaType.tvShow,
        ];
      default:
        return MediaType.values;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

class SourceResultGroup {
  final String sourceId;
  final String displayName;
  final List<MediaEntity> items;
  final bool isLoading;
  final bool hasError;
  final String? errorMessage;

  const SourceResultGroup({
    required this.sourceId,
    required this.displayName,
    required this.items,
    required this.isLoading,
    required this.hasError,
    this.errorMessage,
  });
}
