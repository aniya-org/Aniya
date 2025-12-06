import 'package:flutter/material.dart';
import '../../../../core/services/responsive_layout_manager.dart';
import '../../../../core/widgets/poster_card.dart';
import '../../../../core/domain/entities/entities.dart';
import '../../../details/presentation/screens/tmdb_details_screen.dart';

mixin HomeScreenTmdbMethods {
  Widget buildTmdbHorizontalList(
    BuildContext context,
    List<Map> tmdbList,
    ScreenType screenType, {
    required bool isMovie,
  }) {
    final padding = ResponsiveLayoutManager.getPadding(
      MediaQuery.of(context).size.width,
    );
    final itemWidth = screenType == ScreenType.mobile ? 140.0 : 180.0;

    return SliverToBoxAdapter(
      child: SizedBox(
        height: screenType == ScreenType.mobile ? 240 : 280,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: padding.left),
          itemCount: tmdbList.length > 20 ? 20 : tmdbList.length,
          itemBuilder: (context, index) {
            final tmdbData = tmdbList[index];
            final media = _convertTmdbDataToMediaEntity(tmdbData, isMovie);
            return PosterCard(
              media: media,
              width: itemWidth,
              height: screenType == ScreenType.mobile ? 210.0 : 250.0,
              onTap: () => navigateToTmdbDetails(context, tmdbData, isMovie),
            );
          },
        ),
      ),
    );
  }

  MediaEntity _convertTmdbDataToMediaEntity(Map tmdbData, bool isMovie) {
    final String title = isMovie
        ? (tmdbData['title'] as String? ?? 'Unknown')
        : (tmdbData['name'] as String? ?? 'Unknown');
    final String? posterPath = tmdbData['poster_path'] as String?;
    final double rating = (tmdbData['vote_average'] as num?)?.toDouble() ?? 0.0;
    final String? releaseDate = isMovie
        ? (tmdbData['release_date'] as String?)
        : (tmdbData['first_air_date'] as String?);

    return MediaEntity(
      id: (tmdbData['id'] as int?)?.toString() ?? 'unknown',
      title: title,
      coverImage: posterPath != null
          ? 'https://image.tmdb.org/t/p/w500$posterPath'
          : null,
      bannerImage: posterPath != null
          ? 'https://image.tmdb.org/t/p/w500$posterPath'
          : null,
      description: tmdbData['overview'] as String? ?? '',
      type: isMovie ? MediaType.movie : MediaType.tvShow,
      rating: rating > 0 ? rating : null,
      genres: const [],
      status: MediaStatus.ongoing,
      totalEpisodes: null,
      totalChapters: null,
      startDate: releaseDate != null && releaseDate.isNotEmpty
          ? DateTime.tryParse(releaseDate)
          : null,
      sourceId: 'tmdb',
      sourceName: 'TMDB',
      sourceType: isMovie ? MediaType.movie : MediaType.tvShow,
    );
  }

  void navigateToTmdbDetails(BuildContext context, Map tmdbData, bool isMovie) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            TmdbDetailsScreen(tmdbData: tmdbData, isMovie: isMovie),
      ),
    );
  }
}
