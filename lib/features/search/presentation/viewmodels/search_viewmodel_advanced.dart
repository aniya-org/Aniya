import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/domain/entities/media_entity.dart';
import '../../../../core/domain/entities/search_result_entity.dart';
import '../../../../core/utils/error_message_mapper.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/domain/usecases/search_media_usecase.dart';

class AdvancedSearchViewModel extends ChangeNotifier {
  final SearchMediaUseCase searchMedia;

  AdvancedSearchViewModel({required this.searchMedia});

  SearchResult<List<MediaEntity>>? _searchResults;
  String _query = '';
  MediaType? _typeFilter;
  String? _sourceFilter;
  bool _isLoading = false;
  bool _isAdvancedSearch = false;
  String? _error;
  Timer? _debounceTimer;

  // Advanced filter options
  List<String>? _selectedGenres;
  int? _startYear;
  int? _endYear;
  String? _season;
  String? _status;
  String? _format;
  int? _minScore;
  int? _maxScore;
  String? _sortOrder;

  // Getters
  SearchResult<List<MediaEntity>>? get searchResults => _searchResults;
  String get query => _query;
  MediaType? get typeFilter => _typeFilter;
  String? get sourceFilter => _sourceFilter;
  bool get isLoading => _isLoading;
  bool get isAdvancedSearch => _isAdvancedSearch;
  String? get error => _error;

  // Advanced filter getters
  List<String>? get selectedGenres => _selectedGenres;
  int? get startYear => _startYear;
  int? get endYear => _endYear;
  String? get season => _season;
  String? get status => _status;
  String? get format => _format;
  int? get minScore => _minScore;
  int? get maxScore => _maxScore;
  String? get sortOrder => _sortOrder;

  // Static data
  static const Duration _debounceDuration = Duration(milliseconds: 500);

  // Available options for UI
  final List<String> availableGenres = [
    'Action',
    'Adventure',
    'Comedy',
    'Drama',
    'Ecchi',
    'Fantasy',
    'Horror',
    'Mahou Shoujo',
    'Mecha',
    'Music',
    'Mystery',
    'Psychological',
    'Romance',
    'Sci-Fi',
    'Slice of Life',
    'Sports',
    'Supernatural',
    'Thriller',
  ];

  final List<String> availableSeasons = ['winter', 'spring', 'summer', 'fall'];
  final List<String> availableSortOptions = [
    'score_desc',
    'score_asc',
    'popularity_desc',
    'popularity_asc',
    'start_date_desc',
    'start_date_asc',
    'title_asc',
    'title_desc',
  ];

  final Map<String, String> statusOptions = {
    'finished': 'Completed',
    'airing': 'Currently Airing',
    'upcoming': 'Not Yet Aired',
    'publishing': 'Currently Publishing',
    'cancelled': 'Cancelled',
    'hiatus': 'On Hiatus',
  };

  final Map<String, String> formatOptions = {
    'tv': 'TV Series',
    'movie': 'Movie',
    'special': 'Special',
    'ova': 'OVA',
    'ona': 'ONA',
    'music': 'Music',
    'manga': 'Manga',
    'novel': 'Light Novel',
    'one_shot': 'One Shot',
  };

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

    try {
      // Determine if this should be an advanced search
      _isAdvancedSearch = _shouldUseAdvancedSearch();
      print('Using advanced search: $_isAdvancedSearch');

      if (_isAdvancedSearch && _sourceFilter != null) {
        // Use advanced search when we have source selected and filters
        final result = await searchMedia.call(
          SearchMediaParamsAdvanced(
            query: _query,
            type: _typeFilter ?? MediaType.anime,
            sourceId: _sourceFilter!,
            genres: _selectedGenres,
            year: _startYear, // Use start year as primary filter
            season: _season,
            status: _status,
            format: _format,
            minScore: _minScore,
            maxScore: _maxScore,
            sort: _sortOrder,
          ),
        );

        result.fold(
          (failure) {
            _error = ErrorMessageMapper.mapFailureToMessage(failure);
            Logger.error('Advanced search failed', error: failure);
            _searchResults = null;
          },
          (searchResult) {
            _searchResults = searchResult;
          },
        );
      } else {
        // Fallback to basic search across all sources (would need extension for multi-source)
        // For now, return empty results
        _searchResults = SearchResult(
          items: [],
          totalCount: 0,
          currentPage: 1,
          hasNextPage: false,
          perPage: 20,
        );
        _error =
            'Advanced filters require selecting a specific source (AniList, Jikan, or Simkl)';
      }
    } catch (e, stackTrace) {
      _error = 'An unexpected error occurred. Please try again.';
      Logger.error(
        'Unexpected error in advanced search',
        error: e,
        stackTrace: stackTrace,
      );
      _searchResults = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool _shouldUseAdvancedSearch() {
    // Use advanced search if any filters are applied and a source is selected
    if (_sourceFilter == null) return false;

    return (_selectedGenres?.isNotEmpty == true) ||
        (_startYear != null) ||
        (_season != null) ||
        (_status != null) ||
        (_format != null) ||
        (_minScore != null) ||
        (_maxScore != null) ||
        (_sortOrder != null);
  }

  // Filter setters
  void setTypeFilter(MediaType? type) {
    _typeFilter = type;
    if (_query.isNotEmpty) {
      search(_query);
    } else {
      notifyListeners();
    }
  }

  void setSourceFilter(String? source) {
    _sourceFilter = source;
    if (_query.isNotEmpty) {
      search(_query);
    } else {
      notifyListeners();
    }
  }

  void setGenres(List<String>? genres) {
    _selectedGenres = genres;
    if (_query.isNotEmpty && _sourceFilter != null) {
      search(_query);
    }
  }

  void setYearRange(int? startYear, int? endYear) {
    _startYear = startYear;
    _endYear = endYear;
    if (_query.isNotEmpty && _sourceFilter != null) {
      search(_query);
    }
  }

  void setSeason(String? season) {
    _season = season;
    if (_query.isNotEmpty && _sourceFilter != null) {
      search(_query);
    }
  }

  void setStatus(String? status) {
    _status = status;
    if (_query.isNotEmpty && _sourceFilter != null) {
      search(_query);
    }
  }

  void setFormat(String? format) {
    _format = format;
    if (_query.isNotEmpty && _sourceFilter != null) {
      search(_query);
    }
  }

  void setScoreRange(int? minScore, int? maxScore) {
    _minScore = minScore;
    _maxScore = maxScore;
    if (_query.isNotEmpty && _sourceFilter != null) {
      search(_query);
    }
  }

  void setSortOrder(String? sortOrder) {
    _sortOrder = sortOrder;
    if (_query.isNotEmpty && _sourceFilter != null) {
      search(_query);
    }
  }

  void toggleAdvancedMode() {
    _isAdvancedSearch = !_isAdvancedSearch;
    notifyListeners();
  }

  void clearAdvancedFilters() {
    _selectedGenres = null;
    _startYear = null;
    _endYear = null;
    _season = null;
    _status = null;
    _format = null;
    _minScore = null;
    _maxScore = null;
    _sortOrder = null;
    _isAdvancedSearch = false;

    if (_query.isNotEmpty) {
      search(_query);
    } else {
      notifyListeners();
    }
  }

  void clearResults() {
    _searchResults = null;
    _query = '';
    _error = null;
    _isLoading = false;
    _debounceTimer?.cancel();
    notifyListeners();
  }

  // Helper method to check if any filters are active
  bool get hasActiveFilters {
    return (_selectedGenres?.isNotEmpty == true) ||
        (_startYear != null) ||
        (_season != null) ||
        (_status != null) ||
        (_format != null) ||
        (_minScore != null) ||
        (_maxScore != null) ||
        (_sortOrder != null);
  }

  // Helper method to get active filter count
  int get activeFilterCount {
    int count = 0;
    if (_selectedGenres?.isNotEmpty == true) count++;
    if (_startYear != null) count++;
    if (_season != null) count++;
    if (_status != null) count++;
    if (_format != null) count++;
    if (_minScore != null) count++;
    if (_maxScore != null) count++;
    if (_sortOrder != null) count++;
    return count;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
