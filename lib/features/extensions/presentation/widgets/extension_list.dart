import 'package:flutter/material.dart';
import '../../../../core/domain/entities/extension_entity.dart';
import '../../../../core/widgets/extension_card.dart';
import '../../../../core/widgets/skeleton_screen.dart';

/// A Material Design 3 list widget for displaying extensions with grouping
///
/// Groups extensions by language with headers, shows an Update Pending section
/// at the top for installed extensions with updates, and a Recommended section
/// for available extensions.
///
/// Requirements: 1.3, 6.2
class ExtensionList extends StatelessWidget {
  /// List of extensions to display
  final List<ExtensionEntity> extensions;

  /// Whether this is showing installed extensions
  final bool installed;

  /// Item type filter (anime, manga, novel)
  final ItemType? itemType;

  /// Search query for filtering
  final String query;

  /// Selected language filter
  final String selectedLanguage;

  /// Whether to show recommended section (for available tab)
  final bool showRecommended;

  /// Whether the list is loading
  final bool isLoading;

  /// Extensions with pending updates (for installed tab)
  final List<ExtensionEntity> updatePendingExtensions;

  /// Callback when install is tapped
  final void Function(ExtensionEntity extension)? onInstall;

  /// Callback when uninstall is tapped
  final void Function(ExtensionEntity extension)? onUninstall;

  /// Callback when update is tapped
  final void Function(ExtensionEntity extension)? onUpdate;

  /// Callback when extension is tapped for details
  final void Function(ExtensionEntity extension)? onTap;

  /// Whether an operation is in progress
  final bool isOperationInProgress;

  /// ID of the extension currently being installed
  final String? installingExtensionId;

  /// ID of the extension currently being uninstalled
  final String? uninstallingExtensionId;

  const ExtensionList({
    super.key,
    required this.extensions,
    this.installed = false,
    this.itemType,
    this.query = '',
    this.selectedLanguage = 'All',
    this.showRecommended = false,
    this.isLoading = false,
    this.updatePendingExtensions = const [],
    this.onInstall,
    this.onUninstall,
    this.onUpdate,
    this.onTap,
    this.isOperationInProgress = false,
    this.installingExtensionId,
    this.uninstallingExtensionId,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && extensions.isEmpty) {
      return _buildSkeletonList(context);
    }

    // Filter extensions
    final filteredExtensions = _filterExtensions(extensions);

    if (filteredExtensions.isEmpty) {
      return _buildEmptyState(context);
    }

    // Group extensions by language
    final groupedByLanguage = _groupByLanguage(filteredExtensions);

    // Build sections
    final sections = <_ExtensionSection>[];

    // Add Update Pending section at top for installed tab (Requirement 6.2)
    if (installed && updatePendingExtensions.isNotEmpty) {
      final filteredPending = _filterExtensions(updatePendingExtensions);
      if (filteredPending.isNotEmpty) {
        sections.add(
          _ExtensionSection(
            title: 'Update Pending',
            icon: Icons.system_update,
            extensions: filteredPending,
            isHighlighted: true,
          ),
        );
      }
    }

    // Add Recommended section for available tab
    if (showRecommended && !installed) {
      final recommended = filteredExtensions.take(5).toList();
      if (recommended.isNotEmpty) {
        sections.add(
          _ExtensionSection(
            title: 'Recommended',
            icon: Icons.star_outline,
            extensions: recommended,
            isHighlighted: true,
          ),
        );
      }
    }

    // Add language-grouped sections
    final sortedLanguages = groupedByLanguage.keys.toList()..sort();
    for (final language in sortedLanguages) {
      sections.add(
        _ExtensionSection(
          title: _getLanguageDisplayName(language),
          extensions: groupedByLanguage[language]!,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sections.length,
      itemBuilder: (context, index) {
        final section = sections[index];
        return _buildSection(context, section, index > 0);
      },
    );
  }

  List<ExtensionEntity> _filterExtensions(List<ExtensionEntity> exts) {
    var filtered = exts;

    // Filter by item type if specified
    if (itemType != null) {
      filtered = filtered.where((e) => e.itemType == itemType).toList();
    }

    // Filter by language
    if (selectedLanguage != 'All') {
      filtered = filtered
          .where(
            (e) => e.language.toLowerCase() == selectedLanguage.toLowerCase(),
          )
          .toList();
    }

    // Filter by search query
    if (query.isNotEmpty) {
      final lowerQuery = query.toLowerCase();
      filtered = filtered
          .where((e) => e.name.toLowerCase().contains(lowerQuery))
          .toList();
    }

    return filtered;
  }

  Map<String, List<ExtensionEntity>> _groupByLanguage(
    List<ExtensionEntity> exts,
  ) {
    final grouped = <String, List<ExtensionEntity>>{};
    for (final ext in exts) {
      final lang = ext.language.toLowerCase();
      grouped.putIfAbsent(lang, () => []).add(ext);
    }
    return grouped;
  }

  String _getLanguageDisplayName(String languageCode) {
    // Common language codes to display names
    const languageNames = {
      'en': 'English',
      'ja': 'Japanese',
      'ko': 'Korean',
      'zh': 'Chinese',
      'es': 'Spanish',
      'fr': 'French',
      'de': 'German',
      'it': 'Italian',
      'pt': 'Portuguese',
      'ru': 'Russian',
      'ar': 'Arabic',
      'hi': 'Hindi',
      'th': 'Thai',
      'vi': 'Vietnamese',
      'id': 'Indonesian',
      'tr': 'Turkish',
      'pl': 'Polish',
      'all': 'All Languages',
      'multi': 'Multi-language',
    };

    return languageNames[languageCode.toLowerCase()] ??
        languageCode.toUpperCase();
  }

  Widget _buildSection(
    BuildContext context,
    _ExtensionSection section,
    bool showTopPadding,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTopPadding) const SizedBox(height: 24),

        // Section header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              if (section.icon != null) ...[
                Icon(
                  section.icon,
                  size: 20,
                  color: section.isHighlighted
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                section.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: section.isHighlighted
                      ? colorScheme.primary
                      : colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: section.isHighlighted
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${section.extensions.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: section.isHighlighted
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Extension cards
        ...section.extensions.map((extension) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ExtensionCard(
              extension: extension,
              onInstall: onInstall != null ? () => onInstall!(extension) : null,
              onUninstall: onUninstall != null
                  ? () => onUninstall!(extension)
                  : null,
              onUpdate: onUpdate != null ? () => onUpdate!(extension) : null,
              onTap: onTap != null ? () => onTap!(extension) : null,
              isInstalling: installingExtensionId == extension.id && !extension.hasUpdate,
              isUpdating: installingExtensionId == extension.id && extension.hasUpdate,
              isUninstalling: uninstallingExtensionId == extension.id,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final hasFilters = query.isNotEmpty || selectedLanguage != 'All';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasFilters
                  ? Icons.search_off
                  : (installed
                        ? Icons.extension_off
                        : Icons.check_circle_outline),
              size: 64,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              hasFilters
                  ? 'No extensions found'
                  : (installed
                        ? 'No extensions installed'
                        : 'All extensions installed'),
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hasFilters
                  ? 'Try adjusting your search or filters'
                  : (installed
                        ? 'Install extensions to access content'
                        : 'You have installed all available extensions'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonList(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SkeletonListItem(
          height: 88,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

/// Internal class representing a section of extensions
class _ExtensionSection {
  final String title;
  final IconData? icon;
  final List<ExtensionEntity> extensions;
  final bool isHighlighted;

  const _ExtensionSection({
    required this.title,
    this.icon,
    required this.extensions,
    this.isHighlighted = false,
  });
}
