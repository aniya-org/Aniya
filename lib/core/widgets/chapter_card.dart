import 'package:flutter/material.dart';
import 'package:aniya/core/domain/entities/entities.dart';

/// A Material Design 3 card for displaying chapter items
class ChapterCard extends StatelessWidget {
  final ChapterEntity chapter;
  final VoidCallback? onTap;
  final bool isRead;
  final double? progress;

  const ChapterCard({
    super.key,
    required this.chapter,
    this.onTap,
    this.isRead = false,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Chapter indicator
              Container(
                width: 120,
                height: 68,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Placeholder background
                    Container(
                      color: colorScheme.surfaceContainerHighest,
                      child: Center(
                        child: Icon(
                          Icons.menu_book,
                          size: 32,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),

                    // Progress indicator
                    if (progress != null && progress! > 0)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.transparent,
                          minHeight: 3,
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Chapter Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'CH ${chapter.number.toStringAsFixed(chapter.number % 1 == 0 ? 0 : 1)}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (isRead) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: colorScheme.primary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      chapter.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (chapter.releaseDate != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(chapter.releaseDate!),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    // Show source provider if available
                    if (chapter.sourceProvider != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.source,
                            size: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getProviderName(chapter.sourceProvider!),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _getProviderName(String providerId) {
    switch (providerId.toLowerCase()) {
      case 'tmdb':
        return 'TMDB';
      case 'anilist':
        return 'AniList';
      case 'jikan':
        return 'MAL';
      case 'kitsu':
        return 'Kitsu';
      case 'simkl':
        return 'Simkl';
      default:
        return providerId.toUpperCase();
    }
  }
}
