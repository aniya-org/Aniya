import 'package:flutter/material.dart';
import '../../../../core/services/responsive_layout_manager.dart';
import '../widgets/tmdb_media_card.dart';
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
    // Calculate height based on aspect ratio (2:3) plus text space
    final posterHeight = itemWidth * 1.5; // 2:3 aspect ratio
    final itemHeight =
        posterHeight + 70; // Add space for title, year, and padding

    return SliverToBoxAdapter(
      child: SizedBox(
        height: itemHeight,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: padding.left),
          itemCount: tmdbList.length > 20 ? 20 : tmdbList.length,
          itemBuilder: (context, index) {
            final tmdbData = tmdbList[index];
            return Container(
              width: itemWidth,
              margin: const EdgeInsets.only(right: 12),
              child: TmdbMediaCard(
                tmdbData: tmdbData,
                isMovie: isMovie,
                onTap: () => navigateToTmdbDetails(context, tmdbData, isMovie),
              ),
            );
          },
        ),
      ),
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
