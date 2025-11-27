import 'media_entity.dart';
import 'user_entity.dart';

class MediaDetailsEntity {
  final String id;
  final String title;
  final String? englishTitle;
  final String? romajiTitle;
  final String? nativeTitle;
  final String coverImage;
  final String? bannerImage;
  final String? description;
  final MediaType type;
  final MediaStatus status;
  final double? rating;
  final int? averageScore;
  final int? meanScore;
  final int? popularity;
  final int? favorites;
  final List<String> genres;
  final List<String> tags;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? episodes;
  final int? chapters;
  final int? volumes;
  final int? duration; // in minutes
  final String? season;
  final int? seasonYear;
  final bool isAdult;
  final String? siteUrl;
  final String sourceId;
  final String sourceName;

  // Rich metadata
  final List<CharacterEntity>? characters;
  final List<StaffEntity>? staff;
  final List<ReviewEntity>? reviews;
  final List<RecommendationEntity>? recommendations;
  final List<MediaRelationEntity>? relations;
  final List<StudioEntity>? studios;
  final List<RankingEntity>? rankings;
  final TrailerEntity? trailer;

  // Cross-provider attribution fields
  /// Map of data field to source provider (e.g., {'episodes': 'kitsu', 'coverImage': 'tmdb'})
  final Map<String, String>? dataSourceAttribution;

  /// List of all providers that contributed data to this entity
  final List<String>? contributingProviders;

  /// Confidence scores for cross-provider matches (e.g., {'anilist': 0.95, 'kitsu': 0.87})
  final Map<String, double>? matchConfidences;

  const MediaDetailsEntity({
    required this.id,
    required this.title,
    this.englishTitle,
    this.romajiTitle,
    this.nativeTitle,
    required this.coverImage,
    this.bannerImage,
    this.description,
    required this.type,
    this.status = MediaStatus.upcoming,
    this.rating,
    this.averageScore,
    this.meanScore,
    this.popularity,
    this.favorites,
    required this.genres,
    required this.tags,
    this.startDate,
    this.endDate,
    this.episodes,
    this.chapters,
    this.volumes,
    this.duration,
    this.season,
    this.seasonYear,
    this.isAdult = false,
    this.siteUrl,
    required this.sourceId,
    required this.sourceName,
    this.characters,
    this.staff,
    this.reviews,
    this.recommendations,
    this.relations,
    this.studios,
    this.rankings,
    this.trailer,
    this.dataSourceAttribution,
    this.contributingProviders,
    this.matchConfidences,
  });

  MediaDetailsEntity copyWith({
    String? id,
    String? title,
    String? englishTitle,
    String? romajiTitle,
    String? nativeTitle,
    String? coverImage,
    String? bannerImage,
    String? description,
    MediaType? type,
    MediaStatus? status,
    double? rating,
    int? averageScore,
    int? meanScore,
    int? popularity,
    int? favorites,
    List<String>? genres,
    List<String>? tags,
    DateTime? startDate,
    DateTime? endDate,
    int? episodes,
    int? chapters,
    int? volumes,
    int? duration,
    String? season,
    int? seasonYear,
    bool? isAdult,
    String? siteUrl,
    String? sourceId,
    String? sourceName,
    List<CharacterEntity>? characters,
    List<StaffEntity>? staff,
    List<ReviewEntity>? reviews,
    List<RecommendationEntity>? recommendations,
    List<MediaRelationEntity>? relations,
    List<StudioEntity>? studios,
    List<RankingEntity>? rankings,
    TrailerEntity? trailer,
    Map<String, String>? dataSourceAttribution,
    List<String>? contributingProviders,
    Map<String, double>? matchConfidences,
  }) {
    return MediaDetailsEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      englishTitle: englishTitle ?? this.englishTitle,
      romajiTitle: romajiTitle ?? this.romajiTitle,
      nativeTitle: nativeTitle ?? this.nativeTitle,
      coverImage: coverImage ?? this.coverImage,
      bannerImage: bannerImage ?? this.bannerImage,
      description: description ?? this.description,
      type: type ?? this.type,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      averageScore: averageScore ?? this.averageScore,
      meanScore: meanScore ?? this.meanScore,
      popularity: popularity ?? this.popularity,
      favorites: favorites ?? this.favorites,
      genres: genres ?? this.genres,
      tags: tags ?? this.tags,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      episodes: episodes ?? this.episodes,
      chapters: chapters ?? this.chapters,
      volumes: volumes ?? this.volumes,
      duration: duration ?? this.duration,
      season: season ?? this.season,
      seasonYear: seasonYear ?? this.seasonYear,
      isAdult: isAdult ?? this.isAdult,
      siteUrl: siteUrl ?? this.siteUrl,
      sourceId: sourceId ?? this.sourceId,
      sourceName: sourceName ?? this.sourceName,
      characters: characters ?? this.characters,
      staff: staff ?? this.staff,
      reviews: reviews ?? this.reviews,
      recommendations: recommendations ?? this.recommendations,
      relations: relations ?? this.relations,
      studios: studios ?? this.studios,
      rankings: rankings ?? this.rankings,
      trailer: trailer ?? this.trailer,
      dataSourceAttribution:
          dataSourceAttribution ?? this.dataSourceAttribution,
      contributingProviders:
          contributingProviders ?? this.contributingProviders,
      matchConfidences: matchConfidences ?? this.matchConfidences,
    );
  }
}

class CharacterEntity {
  final String id;
  final String name;
  final String? nativeName;
  final String? image;
  final String role;

  const CharacterEntity({
    required this.id,
    required this.name,
    this.nativeName,
    this.image,
    required this.role,
  });
}

class StaffEntity {
  final String id;
  final String name;
  final String? nativeName;
  final String? image;
  final String role;

  const StaffEntity({
    required this.id,
    required this.name,
    this.nativeName,
    this.image,
    required this.role,
  });
}

class ReviewEntity {
  final String id;
  final int score;
  final String? summary;
  final String? body;
  final UserEntity? user;

  const ReviewEntity({
    required this.id,
    required this.score,
    this.summary,
    this.body,
    this.user,
  });
}

class RecommendationEntity {
  final String id;
  final String title;
  final String? englishTitle;
  final String? romajiTitle;
  final String coverImage;
  final int rating;

  const RecommendationEntity({
    required this.id,
    required this.title,
    this.englishTitle,
    this.romajiTitle,
    required this.coverImage,
    required this.rating,
  });
}

class MediaRelationEntity {
  final String relationType;
  final String id;
  final String title;
  final String? englishTitle;
  final String? romajiTitle;
  final MediaType type;

  const MediaRelationEntity({
    required this.relationType,
    required this.id,
    required this.title,
    this.englishTitle,
    this.romajiTitle,
    required this.type,
  });
}

class StudioEntity {
  final String id;
  final String name;
  final bool isMain;
  final bool isAnimationStudio;

  const StudioEntity({
    required this.id,
    required this.name,
    this.isMain = false,
    this.isAnimationStudio = false,
  });
}

class RankingEntity {
  final int rank;
  final String type;
  final int? year;
  final String? season;

  const RankingEntity({
    required this.rank,
    required this.type,
    this.year,
    this.season,
  });
}

class TrailerEntity {
  final String id;
  final String site;

  const TrailerEntity({required this.id, required this.site});
}

class SearchResult<T> {
  final T items;
  final int totalCount;
  final int currentPage;
  final bool hasNextPage;
  final int perPage;

  const SearchResult({
    required this.items,
    required this.totalCount,
    required this.currentPage,
    required this.hasNextPage,
    required this.perPage,
  });

  bool get hasPrevPage => currentPage > 1;
  int get totalPages => (totalCount / perPage).ceil();

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
