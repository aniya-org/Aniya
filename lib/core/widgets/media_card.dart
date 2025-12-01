import 'package:flutter/material.dart';
import 'package:octo_image/octo_image.dart';
import 'package:aniya/core/domain/entities/entities.dart';

/// A Material Design 3 card for displaying media items
class MediaCard extends StatelessWidget {
  static const double _defaultImageHeight = 300;
  static const double _defaultInfoSectionHeight = 76;
  static const double _libraryInfoSectionHeight = 85;
  static const double _libraryTitleCompensation = 28;
  final MediaEntity media;
  final VoidCallback? onTap;
  final bool showSource;
  final LibraryStatus? libraryStatus;

  const MediaCard({
    super.key,
    required this.media,
    this.onTap,
    this.showSource = true,
    this.libraryStatus,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final hasTightHeight =
            constraints.hasBoundedHeight && constraints.maxHeight.isFinite;
        final isLibraryCard = libraryStatus != null;
        final titleMaxLines = isLibraryCard ? 2 : 1;
        final imageHeight =
            _defaultImageHeight +
            (isLibraryCard ? _libraryTitleCompensation : 0);
        final infoSectionHeight = isLibraryCard
            ? _libraryInfoSectionHeight
            : _defaultInfoSectionHeight;
        final targetHeight = imageHeight + infoSectionHeight;

        final imageSection = _buildCoverImage(
          context,
          colorScheme,
          expand: hasTightHeight,
          fixedHeight: hasTightHeight ? null : imageHeight,
        );
        final infoSection = SizedBox(
          height: infoSectionHeight,
          child: _buildInfoSection(
            theme,
            colorScheme,
            titleMaxLines: titleMaxLines,
          ),
        );

        final children = <Widget>[
          hasTightHeight ? Expanded(child: imageSection) : imageSection,
          infoSection,
        ];

        final cardContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: hasTightHeight ? MainAxisSize.max : MainAxisSize.min,
          children: children,
        );

        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: hasTightHeight
                ? cardContent
                : SizedBox(height: targetHeight, child: cardContent),
          ),
        );
      },
    );
  }

  Widget _buildCoverImage(
    BuildContext context,
    ColorScheme colorScheme, {
    required bool expand,
    double? fixedHeight,
  }) {
    final imageContent = Stack(
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
            errorBuilder: OctoError.icon(color: colorScheme.onSurfaceVariant),
          )
        else
          _buildPlaceholder(context),

        if (media.rating != null)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

        if (libraryStatus != null)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getLibraryStatusColor(libraryStatus!, colorScheme),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getLibraryStatusIcon(libraryStatus!),
                    size: 12,
                    color: _getLibraryStatusTextColor(
                      libraryStatus!,
                      colorScheme,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _getLibraryStatusLabel(libraryStatus!),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: _getLibraryStatusTextColor(
                        libraryStatus!,
                        colorScheme,
                      ),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getTypeColor(media.type, colorScheme),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getTypeLabel(media.type),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );

    if (expand) {
      return SizedBox.expand(child: imageContent);
    }

    return SizedBox(height: fixedHeight, child: imageContent);
  }

  Widget _buildInfoSection(
    ThemeData theme,
    ColorScheme colorScheme, {
    required int titleMaxLines,
  }) {
    return Padding(
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
            maxLines: titleMaxLines,
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

  Color _getTypeColor(MediaType type, ColorScheme colorScheme) {
    switch (type) {
      case MediaType.anime:
        return colorScheme.primary;
      case MediaType.manga:
        return colorScheme.secondary;
      case MediaType.novel:
        return colorScheme.secondary;
      case MediaType.movie:
        return colorScheme.tertiary;
      case MediaType.tvShow:
        return colorScheme.tertiary;
      case MediaType.cartoon:
        return colorScheme.primary;
      case MediaType.documentary:
        return colorScheme.tertiary;
      case MediaType.livestream:
        return colorScheme.error;
      case MediaType.nsfw:
        return colorScheme.error;
    }
  }

  IconData _getLibraryStatusIcon(LibraryStatus status) {
    switch (status) {
      case LibraryStatus.currentlyWatching:
      case LibraryStatus.watching:
        return Icons.play_circle_filled;
      case LibraryStatus.completed:
      case LibraryStatus.finished:
        return Icons.check_circle;
      case LibraryStatus.onHold:
        return Icons.pause_circle_filled;
      case LibraryStatus.dropped:
        return Icons.cancel;
      case LibraryStatus.planToWatch:
      case LibraryStatus.wantToWatch:
        return Icons.bookmark;
      case LibraryStatus.watched:
        return Icons.visibility;
    }
  }

  String _getLibraryStatusLabel(LibraryStatus status) {
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

  Color _getLibraryStatusColor(LibraryStatus status, ColorScheme colorScheme) {
    switch (status) {
      case LibraryStatus.currentlyWatching:
      case LibraryStatus.watching:
        return colorScheme.primaryContainer;
      case LibraryStatus.completed:
      case LibraryStatus.finished:
        return colorScheme.secondaryContainer;
      case LibraryStatus.onHold:
        return colorScheme.surfaceContainerHighest;
      case LibraryStatus.dropped:
        return colorScheme.errorContainer;
      case LibraryStatus.planToWatch:
      case LibraryStatus.wantToWatch:
        return colorScheme.surfaceContainerHighest;
      case LibraryStatus.watched:
        return colorScheme.secondaryContainer;
    }
  }

  Color _getLibraryStatusTextColor(
    LibraryStatus status,
    ColorScheme colorScheme,
  ) {
    switch (status) {
      case LibraryStatus.currentlyWatching:
      case LibraryStatus.watching:
        return colorScheme.onPrimaryContainer;
      case LibraryStatus.completed:
      case LibraryStatus.finished:
        return colorScheme.onSecondaryContainer;
      case LibraryStatus.onHold:
        return colorScheme.onSurfaceVariant;
      case LibraryStatus.dropped:
        return colorScheme.onErrorContainer;
      case LibraryStatus.planToWatch:
      case LibraryStatus.wantToWatch:
        return colorScheme.onSurfaceVariant;
      case LibraryStatus.watched:
        return colorScheme.onSecondaryContainer;
    }
  }
}
