import 'package:flutter/material.dart';
import 'package:octo_image/octo_image.dart';
import 'package:aniya/core/domain/entities/entities.dart';

/// A Material Design 3 card for displaying extension items
///
/// Displays extension information with rounded corners, appropriate elevation,
/// and action buttons for Install/Uninstall/Update operations.
/// Shows an NSFW indicator when the extension contains adult content.
///
/// Requirements: 8.4, 9.2
class ExtensionCard extends StatelessWidget {
  final ExtensionEntity extension;
  final VoidCallback? onInstall;
  final VoidCallback? onUninstall;
  final VoidCallback? onUpdate;
  final VoidCallback? onTap;
  final bool isInstalling;
  final bool isUpdating;
  final bool isUninstalling;

  const ExtensionCard({
    super.key,
    required this.extension,
    this.onInstall,
    this.onUninstall,
    this.onUpdate,
    this.onTap,
    this.isInstalling = false,
    this.isUpdating = false,
    this.isUninstalling = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Extension Icon with MD3 styling
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
                        // NSFW indicator (Requirement 8.4)
                        if (extension.isNsfw) _buildNsfwIndicator(context),
                        // Update available indicator
                        if (extension.hasUpdate)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'UPDATE',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onTertiaryContainer,
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
                        if (extension.hasUpdate &&
                            extension.versionLast != null) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward,
                            size: 12,
                            color: colorScheme.tertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'v${extension.versionLast}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.tertiary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
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

              const SizedBox(width: 12),

              // Action Buttons
              _buildActionButton(context),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the NSFW indicator badge (Requirement 8.4)
  Widget _buildNsfwIndicator(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: colorScheme.error.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 12,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 2),
          Text(
            '18+',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onErrorContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the appropriate action button based on extension state
  Widget _buildActionButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Show loading indicator when installing, updating, or uninstalling
    if (isInstalling || isUpdating || isUninstalling) {
      return SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: colorScheme.primary,
        ),
      );
    }

    // Show update button if update is available
    if (extension.isInstalled && extension.hasUpdate) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton.tonal(
            onPressed: onUpdate,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 36),
            ),
            child: const Text('Update'),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: onUninstall,
            tooltip: 'Uninstall',
            color: colorScheme.error,
            visualDensity: VisualDensity.compact,
          ),
        ],
      );
    }

    // Show uninstall button for installed extensions
    if (extension.isInstalled) {
      return IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: onUninstall,
        tooltip: 'Uninstall',
        color: colorScheme.error,
      );
    }

    // Show install button for available extensions
    return FilledButton.icon(
      onPressed: onInstall,
      icon: const Icon(Icons.download, size: 18),
      label: const Text('Install'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        minimumSize: const Size(0, 36),
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
