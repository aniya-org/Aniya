import 'package:flutter/material.dart';
import 'package:octo_image/octo_image.dart';
import 'package:aniya/core/domain/entities/entities.dart';

/// A Material Design 3 card for displaying extension items
class ExtensionCard extends StatelessWidget {
  final ExtensionEntity extension;
  final VoidCallback? onInstall;
  final VoidCallback? onUninstall;
  final VoidCallback? onTap;
  final bool isInstalling;

  const ExtensionCard({
    super.key,
    required this.extension,
    this.onInstall,
    this.onUninstall,
    this.onTap,
    this.isInstalling = false,
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
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Extension Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: extension.iconUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: OctoImage(
                          image: NetworkImage(extension.iconUrl!),
                          fit: BoxFit.cover,
                          placeholderBuilder: (context) {
                            return Container(
                              color: colorScheme.primaryContainer,
                              child: Center(
                                child: Icon(
                                  Icons.extension,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                            );
                          },
                          errorBuilder: OctoError.icon(
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      )
                    : _buildIconPlaceholder(context),
              ),

              const SizedBox(width: 16),

              // Extension Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            extension.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (extension.isNsfw)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'NSFW',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onErrorContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getTypeColor(extension.type, colorScheme),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getTypeLabel(extension.type),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'v${extension.version}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          extension.language.toUpperCase(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Action Button
              if (isInstalling)
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (extension.isInstalled)
                IconButton(
                  icon: Icon(Icons.delete_outline),
                  onPressed: onUninstall,
                  tooltip: 'Uninstall',
                  color: colorScheme.error,
                )
              else
                FilledButton.icon(
                  onPressed: onInstall,
                  icon: Icon(Icons.download),
                  label: Text('Install'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconPlaceholder(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Icon(
        Icons.extension,
        size: 32,
        color: colorScheme.onPrimaryContainer,
      ),
    );
  }

  String _getTypeLabel(ExtensionType type) {
    switch (type) {
      case ExtensionType.cloudstream:
        return 'CloudStream';
      case ExtensionType.aniyomi:
        return 'Aniyomi';
      case ExtensionType.mangayomi:
        return 'Mangayomi';
      case ExtensionType.lnreader:
        return 'LnReader';
    }
  }

  Color _getTypeColor(ExtensionType type, ColorScheme colorScheme) {
    switch (type) {
      case ExtensionType.cloudstream:
        return colorScheme.primary;
      case ExtensionType.aniyomi:
        return colorScheme.secondary;
      case ExtensionType.mangayomi:
        return colorScheme.tertiary;
      case ExtensionType.lnreader:
        return colorScheme.tertiary;
    }
  }
}
