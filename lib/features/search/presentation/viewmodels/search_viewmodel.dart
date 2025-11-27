import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/domain/entities/media_entity.dart';
import '../../../../core/domain/usecases/search_media_usecase.dart';
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

  List<MediaEntity> get searchResults => _searchResults;
  String get query => _query;
  MediaType? get typeFilter => _typeFilter;
  String? get sourceFilter => _sourceFilter;
  bool get isLoading => _isLoading;
  String? get error => _error;

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
      // If no type filter is set, search all types
      if (_typeFilter == null) {
        List<MediaEntity> allResults = [];

        // Search across all media types
        for (final type in MediaType.values) {
          Logger.debug(
            'Searching type: $type with sourceId: $_sourceFilter',
            tag: 'SearchViewModel',
          );

          final result = await searchMedia(
            SearchMediaParams(
              query: _query,
              type: type,
              sourceId: _sourceFilter, // Pass sourceId even when no type filter
            ),
          );

          result.fold(
            (failure) {
              final errorMsg = ErrorMessageMapper.mapFailureToMessage(failure);
              Logger.error(
                'Failed to search for type: $type - $errorMsg',
                tag: 'SearchViewModel',
                error: failure,
              );
              // Don't set _error here for "all types" search, just log it
              // Only set error if ALL types fail
            },
            (results) {
              Logger.debug(
                'Found ${results.length} results for type: $type',
                tag: 'SearchViewModel',
              );
              allResults.addAll(results);
            },
          );
        }

        _searchResults = allResults;
        Logger.info(
          'Search completed: ${_searchResults.length} total results',
          tag: 'SearchViewModel',
        );
      } else {
        // Search with specific type filter
        Logger.debug(
          'Searching with type filter: $_typeFilter, sourceId: $_sourceFilter',
          tag: 'SearchViewModel',
        );

        final result = await searchMedia(
          SearchMediaParams(
            query: _query,
            type: _typeFilter!,
            sourceId: _sourceFilter,
          ),
        );

        result.fold(
          (failure) {
            _error = ErrorMessageMapper.mapFailureToMessage(failure);
            Logger.error(
              'Failed to search with type filter $_typeFilter and source $_sourceFilter: $_error',
              tag: 'SearchViewModel',
              error: failure,
            );
            _searchResults = []; // Clear results on error
          },
          (results) {
            _searchResults = results;
            _error = null; // Clear any previous errors
            Logger.info(
              'Search completed: ${_searchResults.length} results',
              tag: 'SearchViewModel',
            );
          },
        );
      }
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
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
