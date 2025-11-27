import 'package:flutter/material.dart';
import 'package:octo_image/octo_image.dart';
import '../../../../core/domain/entities/extension_entity.dart';

/// A Material Design 3 bottom sheet for displaying extension details
///
/// Shows comprehensive information about an extension including:
/// - Name, version, type, language, and installation status
/// - Extension icon if available
/// - NSFW indicator when applicable
/// - Action buttons for install/uninstall/update
///
/// Requirements: 8.1, 8.2, 8.3
class ExtensionDetailsSheet extends StatelessWidget {
  /// The extension to display details for
  final ExtensionEntity extension;

  /// Callback when install is tapped
  final VoidCallback? onInstall;

  /// Callback when uninstall is tapped
  final VoidCallback? onUninstall;

  /// Callback when update is tapped
  final VoidCallback? onUpdate;

  /// Whether an operation is in progress
  final bool isLoading;

  const ExtensionDetailsSheet({
    super.key,
    required this.extension,
    this.onInstall,
    this.onUninstall,
    this.onUpdate,
    this.isLoading = false,
  });

  /// Shows the ExtensionDetailsSheet as a modal bottom sheet
  static Future<void> show({
    required BuildContext context,
    required ExtensionEntity extension,
    VoidCallback? onInstall,
    VoidCallback? onUninstall,
    VoidCallback? onUpdate,
    bool isLoading = false,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => ExtensionDetailsSheet(
        extension: extension,
        onInstall: onInstall,
        onUninstall: onUninstall,
        onUpdate: onUpdate,
        isLoading: isLoading,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with icon and name
                      _buildHeader(context),

                      const SizedBox(height: 24),

                      // Badges row
                      _buildBadgesRow(context),

                      const SizedBox(height: 24),

                      // Details section
                      _buildDetailsSection(context),

                      // Description if available
                      if (extension.description != null &&
                          extension.description!.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildDescriptionSection(context),
                      ],

                      const SizedBox(height: 32),

                      // Action buttons
                      _buildActionButtons(context),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Extension icon (Requirement 8.3)
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: extension.iconUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: OctoImage(
                    image: NetworkImage(extension.iconUrl!),
                    fit: BoxFit.cover,
                    placeholderBuilder: (context) =>
                        _buildIconPlaceholder(context),
                    errorBuilder: OctoError.icon(
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                )
              : _buildIconPlaceholder(context),
        ),

        const SizedBox(width: 16),

        // Name and version
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                extension.name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'Version ${extension.version}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (extension.hasUpdate && extension.versionLast != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '→ ${extension.versionLast}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onTertiaryContainer,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIconPlaceholder(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Icon(
        Icons.extension,
        size: 36,
        color: colorScheme.onPrimaryContainer,
      ),
    );
  }

  Widget _buildBadgesRow(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Extension type badge
        _buildBadge(
          context,
          label: _getTypeLabel(extension.type),
          color: _getTypeColor(extension.type, colorScheme),
          textColor: colorScheme.onPrimary,
        ),

        // Item type badge
        _buildBadge(
          context,
          label: extension.itemType.toString(),
          color: colorScheme.secondaryContainer,
          textColor: colorScheme.onSecondaryContainer,
        ),

        // Language badge
        _buildBadge(
          context,
          label: extension.language.toUpperCase(),
          color: colorScheme.surfaceContainerHighest,
          textColor: colorScheme.onSurface,
        ),

        // Status badge
        _buildBadge(
          context,
          label: extension.isInstalled ? 'Installed' : 'Not Installed',
          color: extension.isInstalled
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          textColor: extension.isInstalled
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurface,
          icon: extension.isInstalled
              ? Icons.check_circle
              : Icons.circle_outlined,
        ),

        // NSFW badge (Requirement 8.4)
        if (extension.isNsfw)
          _buildBadge(
            context,
            label: '18+ NSFW',
            color: colorScheme.errorContainer,
            textColor: colorScheme.onErrorContainer,
            icon: Icons.warning_amber_rounded,
          ),

        // Update available badge
        if (extension.hasUpdate)
          _buildBadge(
            context,
            label: 'Update Available',
            color: colorScheme.tertiaryContainer,
            textColor: colorScheme.onTertiaryContainer,
            icon: Icons.system_update,
          ),
      ],
    );
  }

  Widget _buildBadge(
    BuildContext context, {
    required String label,
    required Color color,
    required Color textColor,
    IconData? icon,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildDetailRow(
            context,
            icon: Icons.category_outlined,
            label: 'Type',
            value: _getTypeLabel(extension.type),
          ),
          const Divider(height: 24),
          _buildDetailRow(
            context,
            icon: Icons.video_library_outlined,
            label: 'Content',
            value: extension.itemType.toString(),
          ),
          const Divider(height: 24),
          _buildDetailRow(
            context,
            icon: Icons.language,
            label: 'Language',
            value: extension.language.toUpperCase(),
          ),
          const Divider(height: 24),
          _buildDetailRow(
            context,
            icon: Icons.info_outline,
            label: 'Status',
            value: extension.isInstalled ? 'Installed' : 'Not Installed',
          ),
          if (extension.hasUpdate && extension.versionLast != null) ...[
            const Divider(height: 24),
            _buildDetailRow(
              context,
              icon: Icons.system_update,
              label: 'Latest Version',
              value: extension.versionLast!,
              valueColor: colorScheme.tertiary,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: valueColor ?? colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          extension.description!,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(color: colorScheme.primary),
      );
    }

    // Show update and uninstall for installed extensions with updates
    if (extension.isInstalled && extension.hasUpdate) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onUninstall?.call();
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Uninstall'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.error,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onUpdate?.call();
              },
              icon: const Icon(Icons.system_update),
              label: const Text('Update'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      );
    }

    // Show uninstall for installed extensions
    if (extension.isInstalled) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            onUninstall?.call();
          },
          icon: const Icon(Icons.delete_outline),
          label: const Text('Uninstall'),
          style: OutlinedButton.styleFrom(
            foregroundColor: colorScheme.error,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      );
    }

    // Show install for available extensions
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () {
          Navigator.of(context).pop();
          onInstall?.call();
        },
        icon: const Icon(Icons.download),
        label: const Text('Install'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
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
