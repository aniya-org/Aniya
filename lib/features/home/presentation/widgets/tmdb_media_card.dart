import 'package:flutter/material.dart';
import '../../../../core/services/tmdb_service.dart';

/// Card widget for displaying TMDB movie or TV show
class TmdbMediaCard extends StatelessWidget {
  final Map tmdbData;
  final VoidCallback? onTap;
  final bool isMovie;

  const TmdbMediaCard({
    required this.tmdbData,
    this.onTap,
    this.isMovie = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final String title = isMovie
        ? (tmdbData['title'] as String? ?? 'Unknown')
        : (tmdbData['name'] as String? ?? 'Unknown');
    final String? posterPath = tmdbData['poster_path'] as String?;
    final double rating = (tmdbData['vote_average'] as num?)?.toDouble() ?? 0.0;
    final String? releaseDate = isMovie
        ? (tmdbData['release_date'] as String?)
        : (tmdbData['first_air_date'] as String?);

    final String year = releaseDate != null && releaseDate.isNotEmpty
        ? releaseDate.split('-').first
        : '';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poster with fixed aspect ratio
          AspectRatio(
            aspectRatio: 2 / 3, // Standard movie poster ratio
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  // Poster image
                  if (posterPath != null)
                    Image.network(
                      TmdbService.getPosterUrl(posterPath),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.movie_outlined,
                          size: 48,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    Container(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.movie_outlined,
                        size: 48,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),

                  // Rating badge
                  if (rating > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              size: 12,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Title and year section - flexible to prevent overflow
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),

                // Year
                if (year.isNotEmpty)
                  Text(
                    year,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
