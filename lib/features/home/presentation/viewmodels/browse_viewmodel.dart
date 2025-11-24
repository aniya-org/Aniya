import 'package:flutter/foundation.dart';
import '../../../../core/domain/entities/media_entity.dart';
import '../../../../core/domain/usecases/get_popular_media_usecase.dart';
import '../../../../core/domain/usecases/get_trending_media_usecase.dart';
import '../../../../core/error/failures.dart';

enum SortOption { popularity, rating, releaseDate }

class BrowseViewModel extends ChangeNotifier {
  final GetPopularMediaUseCase getPopularMedia;
  final GetTrendingMediaUseCase getTrendingMedia;

  BrowseViewModel({
    required this.getPopularMedia,
    required this.getTrendingMedia,
  });

  List<MediaEntity> _mediaList = [];
  MediaType _mediaType = MediaType.anime;
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  bool _hasMorePages = true;
  SortOption _sortOption = SortOption.popularity;
  List<String> _genreFilters = [];
  MediaStatus? _statusFilter;

  List<MediaEntity> get mediaList => _mediaList;
  MediaType get mediaType => _mediaType;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMorePages => _hasMorePages;
  SortOption get sortOption => _sortOption;
  List<String> get genreFilters => _genreFilters;
  MediaStatus? get statusFilter => _statusFilter;

  void setMediaType(MediaType type) {
    if (_mediaType != type) {
      _mediaType = type;
      _resetAndLoad();
    }
  }

  void setSortOption(SortOption option) {
    if (_sortOption != option) {
      _sortOption = option;
      _resetAndLoad();
    }
  }

  void setGenreFilters(List<String> genres) {
    _genreFilters = genres;
    _resetAndLoad();
  }

  void setStatusFilter(MediaStatus? status) {
    _statusFilter = status;
    _resetAndLoad();
  }

  Future<void> loadMedia({bool loadMore = false}) async {
    if (_isLoading) return;

    if (loadMore) {
      if (!_hasMorePages) return;
      _currentPage++;
    } else {
      _currentPage = 1;
      _mediaList = [];
      _hasMorePages = true;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Use trending or popular based on sort option
      final result = _sortOption == SortOption.popularity
          ? await getPopularMedia(
              GetPopularMediaParams(type: _mediaType, page: _currentPage),
            )
          : await getTrendingMedia(
              GetTrendingMediaParams(type: _mediaType, page: _currentPage),
            );

      result.fold(
        (failure) {
          _error = _mapFailureToMessage(failure);
          if (!loadMore) {
            _mediaList = [];
          }
        },
        (media) {
          var filteredMedia = media;

          // Apply genre filters
          if (_genreFilters.isNotEmpty) {
            filteredMedia = filteredMedia.where((m) {
              return _genreFilters.any((genre) => m.genres.contains(genre));
            }).toList();
          }

          // Apply status filter
          if (_statusFilter != null) {
            filteredMedia = filteredMedia.where((m) {
              return m.status == _statusFilter;
            }).toList();
          }

          // Apply sorting
          filteredMedia = _sortMedia(filteredMedia);

          if (loadMore) {
            _mediaList.addAll(filteredMedia);
          } else {
            _mediaList = filteredMedia;
          }

          // Check if there are more pages (simple heuristic)
          _hasMorePages = media.isNotEmpty;
        },
      );
    } catch (e) {
      _error = 'An unexpected error occurred: ${e.toString()}';
      if (!loadMore) {
        _mediaList = [];
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<MediaEntity> _sortMedia(List<MediaEntity> media) {
    final sorted = List<MediaEntity>.from(media);

    switch (_sortOption) {
      case SortOption.popularity:
        // Already sorted by popularity from API
        break;
      case SortOption.rating:
        sorted.sort((a, b) {
          final ratingA = a.rating ?? 0;
          final ratingB = b.rating ?? 0;
          return ratingB.compareTo(ratingA);
        });
        break;
      case SortOption.releaseDate:
        // Note: MediaEntity doesn't have releaseDate, so this is a placeholder
        // In a real implementation, you'd need to add this field
        break;
    }

    return sorted;
  }

  Future<void> refresh() async {
    await loadMedia(loadMore: false);
  }

  void _resetAndLoad() {
    _currentPage = 1;
    _mediaList = [];
    _hasMorePages = true;
    loadMedia();
  }

  String _mapFailureToMessage(Failure failure) {
    if (failure is NetworkFailure) {
      return 'Network error: ${failure.message}';
    } else if (failure is ExtensionFailure) {
      return 'Extension error: ${failure.message}';
    } else if (failure is StorageFailure) {
      return 'Storage error: ${failure.message}';
    } else {
      return 'Error: ${failure.message}';
    }
  }
}
