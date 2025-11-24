import 'package:flutter/material.dart';
import 'package:octo_image/octo_image.dart';
import 'package:aniya/core/domain/entities/entities.dart';

/// A Material Design 3 card for displaying media items
class MediaCard extends StatelessWidget {
  final MediaEntity media;
  final VoidCallback? onTap;
  final bool showSource;

  const MediaCard({
    super.key,
    required this.media,
    this.onTap,
    this.showSource = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image - Flexible to prevent overflow
            SizedBox(
              height: 200,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (media.coverImage != null)
                    OctoImage(
                      image: NetworkImage(media.coverImage!),
                      fit: BoxFit.cover,
                      placeholderBuilder: (context) {
                        return Container(
                          color: colorScheme.surfaceContainerHighest,
                          child: Center(
                            child: Icon(
                              _getTypeIcon(media.type),
                              size: 48,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      },
                      errorBuilder: OctoError.icon(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    _buildPlaceholder(context),

                  // Rating badge
                  if (media.rating != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star,
                              size: 14,
                              color: colorScheme.onPrimaryContainer,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              media.rating!.toStringAsFixed(1),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Type badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getTypeColor(media.type, colorScheme),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getTypeLabel(media.type),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Media Info - Fixed height
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    media.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (showSource) ...[
                    const SizedBox(height: 4),
                    Text(
                      media.sourceName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          _getTypeIcon(media.type),
          size: 48,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  IconData _getTypeIcon(MediaType type) {
    switch (type) {
      case MediaType.anime:
        return Icons.movie;
      case MediaType.manga:
        return Icons.book;
      case MediaType.movie:
        return Icons.theaters;
      case MediaType.tvShow:
        return Icons.tv;
    }
  }

  String _getTypeLabel(MediaType type) {
    switch (type) {
      case MediaType.anime:
        return 'ANIME';
      case MediaType.manga:
        return 'MANGA';
      case MediaType.movie:
        return 'MOVIE';
      case MediaType.tvShow:
        return 'TV';
    }
  }

  Color _getTypeColor(MediaType type, ColorScheme colorScheme) {
    switch (type) {
      case MediaType.anime:
        return colorScheme.primary;
      case MediaType.manga:
        return colorScheme.secondary;
      case MediaType.movie:
        return colorScheme.tertiary;
      case MediaType.tvShow:
        return colorScheme.tertiary;
    }
  }
}
