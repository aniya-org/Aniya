import 'package:equatable/equatable.dart';

/// Search result wrapper containing pagination metadata and items
class SearchResult<T> extends Equatable {
  /// The actual search results
  final T items;

  /// Total number of available results across all pages
  final int totalCount;

  /// Current page number (1-based)
  final int currentPage;

  /// Whether there are more pages available
  final bool hasNextPage;

  /// Number of items per page
  final int perPage;

  const SearchResult({
    required this.items,
    required this.totalCount,
    required this.currentPage,
    required this.hasNextPage,
    required this.perPage,
  });

  @override
  List<Object?> get props => [
    items,
    totalCount,
    currentPage,
    hasNextPage,
    perPage,
  ];

  @override
  String toString() {
    return 'SearchResult(items: $items, totalCount: $totalCount, currentPage: $currentPage, hasNextPage: $hasNextPage, perPage: $perPage)';
  }

  /// Create a copy with modified fields
  SearchResult<T> copyWith({
    T? items,
    int? totalCount,
    int? currentPage,
    bool? hasNextPage,
    int? perPage,
  }) {
    return SearchResult<T>(
      items: items ?? this.items,
      totalCount: totalCount ?? this.totalCount,
      currentPage: currentPage ?? this.currentPage,
      hasNextPage: hasNextPage ?? this.hasNextPage,
      perPage: perPage ?? this.perPage,
    );
  }
}
