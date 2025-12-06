import 'package:flutter/material.dart';
import 'package:octo_image/octo_image.dart';
import 'package:aniya/core/domain/entities/entities.dart';

/// A poster-style card widget that displays media items with overlay text and badges
/// Similar to the Continue Watching/Reading cards in the home screen
class PosterCard extends StatelessWidget {
  final MediaEntity media;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final LibraryStatus? libraryStatus;
  final double? width;
  final double? height;
  final bool showProgress;
  final double? progress;
  final String? progressText;
  final String? tooltipMessage;
  final bool showMoreOptionsIndicator;

  const PosterCard({
    super.key,
    required this.media,
    this.onTap,
    this.onLongPress,
    this.libraryStatus,
    this.width,
    this.height,
    this.showProgress = false,
    this.progress,
    this.progressText,
    this.tooltipMessage,
    this.showMoreOptionsIndicator = false,
  });

  @override
  Widget build(BuildContext context) {
    final cardWidth = width ?? 140.0;

    final content = Container(
      width: cardWidth,
      margin: const EdgeInsets.only(right: 12),
      child: Tooltip(
        message: tooltipMessage ?? 'Tap to view details',
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                // Cover image
                Positioned.fill(child: _buildCoverImage(context)),

                // Gradient overlay
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                ),

                // Media type badge
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getTypeLabel(media.type),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // Library status badge (if available)
                if (libraryStatus != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _getLibraryStatusLabel(libraryStatus!)!,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSecondaryContainer,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),

                // Progress indicator (if enabled and progress available)
                if (showProgress && progress != null && progress! > 0)
                  Positioned(
                    bottom: 60,
                    left: 8,
                    right: 8,
                    child: LinearProgressIndicator(
                      value: progress! / 100,
                      backgroundColor: Colors.white.withValues(alpha: 0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),

                // More options indicator (if enabled)
                if (showMoreOptionsIndicator)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.more_vert,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),

                // Title and info
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          media.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        if (progressText != null &&
                            progressText!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            progressText!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return content;
  }

  Widget _buildCoverImage(BuildContext context) {
    if (media.coverImage != null && media.coverImage!.isNotEmpty) {
      return OctoImage(
        image: NetworkImage(media.coverImage!),
        fit: BoxFit.cover,
        placeholderBuilder: (context) {
          return Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Center(
              child: Icon(
                _getTypeIcon(media.type),
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        },
        errorBuilder: OctoError.icon(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    } else {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(
          child: Icon(
            _getTypeIcon(media.type),
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
  }

  IconData _getTypeIcon(MediaType type) {
    switch (type) {
      case MediaType.anime:
        return Icons.movie;
      case MediaType.manga:
        return Icons.book;
      case MediaType.novel:
        return Icons.auto_stories;
      case MediaType.movie:
        return Icons.theaters;
      case MediaType.tvShow:
        return Icons.tv;
      case MediaType.cartoon:
        return Icons.animation;
      case MediaType.documentary:
        return Icons.video_library;
      case MediaType.livestream:
        return Icons.live_tv;
      case MediaType.nsfw:
        return Icons.eighteen_up_rating;
    }
  }

  String _getTypeLabel(MediaType type) {
    switch (type) {
      case MediaType.anime:
        return 'ANIME';
      case MediaType.manga:
        return 'MANGA';
      case MediaType.novel:
        return 'NOVEL';
      case MediaType.movie:
        return 'MOVIE';
      case MediaType.tvShow:
        return 'TV';
      case MediaType.cartoon:
        return 'CARTOON';
      case MediaType.documentary:
        return 'DOC';
      case MediaType.livestream:
        return 'LIVE';
      case MediaType.nsfw:
        return 'NSFW';
    }
  }

  String? _getLibraryStatusLabel(LibraryStatus status) {
    switch (status) {
      case LibraryStatus.currentlyWatching:
      case LibraryStatus.watching:
        return 'WATCHING';
      case LibraryStatus.completed:
      case LibraryStatus.finished:
        return 'COMPLETED';
      case LibraryStatus.onHold:
        return 'ON HOLD';
      case LibraryStatus.dropped:
        return 'DROPPED';
      case LibraryStatus.planToWatch:
      case LibraryStatus.wantToWatch:
        return 'PLANNED';
      case LibraryStatus.watched:
        return 'WATCHED';
    }
  }
}
