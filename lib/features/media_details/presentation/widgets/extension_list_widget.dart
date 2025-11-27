import 'package:flutter/material.dart';
import 'package:aniya/core/domain/entities/extension_entity.dart';
import 'package:aniya/core/widgets/extension_card.dart';

/// Widget displaying available extensions with recent extensions at top
///
/// Shows recently used extensions in a separate section at the top,
/// followed by all compatible extensions. Handles loading state and
/// displays extension name, icon, and type.
///
/// Requirements: 1.3, 1.4, 8.2
class ExtensionListWidget extends StatelessWidget {
  /// List of all compatible extensions
  final List<ExtensionEntity> extensions;

  /// List of recently used extensions (up to 5)
  final List<ExtensionEntity> recentExtensions;

  /// Whether the extension list is currently loading
  final bool isLoading;

  /// Callback when an extension is selected
  final Function(ExtensionEntity) onExtensionSelected;

  const ExtensionListWidget({
    required this.extensions,
    required this.recentExtensions,
    required this.isLoading,
    required this.onExtensionSelected,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Show loading state
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Loading extensions...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    // Show empty state if no extensions available
    if (extensions.isEmpty && recentExtensions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.extension_off,
              size: 48,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No compatible extensions',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Install an extension to get started',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recent extensions section
          if (recentExtensions.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Recent',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  for (int i = 0; i < recentExtensions.length; i++) ...[
                    _buildExtensionCard(context, recentExtensions[i]),
                    if (i < recentExtensions.length - 1)
                      const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Divider(height: 1, color: colorScheme.outlineVariant),
          ],

          // All extensions section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'All Extensions',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (int i = 0; i < extensions.length; i++) ...[
                  _buildExtensionCard(context, extensions[i]),
                  if (i < extensions.length - 1) const SizedBox(height: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// Build an extension card with tap handler
  Widget _buildExtensionCard(BuildContext context, ExtensionEntity extension) {
    return GestureDetector(
      onTap: () => onExtensionSelected(extension),
      child: ExtensionCard(
        extension: extension,
        onTap: () => onExtensionSelected(extension),
      ),
    );
  }
}
