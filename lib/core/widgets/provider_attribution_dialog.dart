import 'package:flutter/material.dart';
import 'package:aniya/core/widgets/provider_badge.dart';

/// A dialog that shows detailed provider attribution information
class ProviderAttributionDialog extends StatelessWidget {
  final Map<String, String>? dataSourceAttribution;
  final List<String>? contributingProviders;
  final Map<String, double>? matchConfidences;
  final String primaryProvider;

  const ProviderAttributionDialog({
    super.key,
    this.dataSourceAttribution,
    this.contributingProviders,
    this.matchConfidences,
    required this.primaryProvider,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAttribution =
        dataSourceAttribution != null && dataSourceAttribution!.isNotEmpty;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Data Sources',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Primary Provider Section
                    _buildSectionTitle(context, 'Primary Source'),
                    const SizedBox(height: 8),
                    ProviderBadge(providerId: primaryProvider),
                    const SizedBox(height: 8),
                    Text(
                      'This is the main provider where this media was discovered.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Contributing Providers Section
                    if (contributingProviders != null &&
                        contributingProviders!.isNotEmpty) ...[
                      _buildSectionTitle(context, 'Contributing Providers'),
                      const SizedBox(height: 8),
                      ProviderBadgeList(providers: contributingProviders!),
                      const SizedBox(height: 8),
                      Text(
                        'These providers contributed additional data to enhance this view.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Match Confidence Section
                    if (matchConfidences != null &&
                        matchConfidences!.isNotEmpty) ...[
                      _buildSectionTitle(context, 'Match Confidence'),
                      const SizedBox(height: 12),
                      ...matchConfidences!.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildConfidenceRow(
                            context,
                            entry.key,
                            entry.value,
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      Text(
                        'Confidence scores indicate how certain we are that the matched content is the same across providers.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Data Attribution Section
                    if (hasAttribution) ...[
                      _buildSectionTitle(context, 'Data Attribution'),
                      const SizedBox(height: 8),
                      Text(
                        'Each piece of data comes from a specific provider:',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...dataSourceAttribution!.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildAttributionRow(
                            context,
                            entry.key,
                            entry.value,
                          ),
                        );
                      }),
                    ] else ...[
                      _buildSectionTitle(context, 'Data Attribution'),
                      const SizedBox(height: 8),
                      Text(
                        'All data for this media comes from the primary source.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Footer
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.primary,
      ),
    );
  }

  Widget _buildConfidenceRow(
    BuildContext context,
    String providerId,
    double confidence,
  ) {
    final theme = Theme.of(context);
    final percentage = (confidence * 100).toInt();

    Color confidenceColor;
    if (confidence >= 0.9) {
      confidenceColor = Colors.green;
    } else if (confidence >= 0.8) {
      confidenceColor = Colors.orange;
    } else {
      confidenceColor = Colors.red;
    }

    return Row(
      children: [
        SizedBox(
          width: 80,
          child: ProviderBadge(providerId: providerId, isSmall: true),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: confidence,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          confidenceColor,
                        ),
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$percentage%',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: confidenceColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAttributionRow(
    BuildContext context,
    String dataField,
    String providerId,
  ) {
    final theme = Theme.of(context);

    // Format the data field name for display
    final displayName = _formatDataFieldName(dataField);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            displayName,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Icon(
          Icons.arrow_forward,
          size: 16,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
        ),
        const SizedBox(width: 12),
        ProviderBadge(providerId: providerId, isSmall: true),
      ],
    );
  }

  String _formatDataFieldName(String fieldName) {
    // Convert camelCase or snake_case to Title Case
    final words = fieldName
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
        .replaceAll('_', ' ')
        .trim()
        .split(' ');

    return words
        .map(
          (word) => word.isEmpty
              ? ''
              : word[0].toUpperCase() + word.substring(1).toLowerCase(),
        )
        .join(' ');
  }
}

/// Helper function to show the provider attribution dialog
void showProviderAttributionDialog(
  BuildContext context, {
  Map<String, String>? dataSourceAttribution,
  List<String>? contributingProviders,
  Map<String, double>? matchConfidences,
  required String primaryProvider,
}) {
  showDialog(
    context: context,
    builder: (context) => ProviderAttributionDialog(
      dataSourceAttribution: dataSourceAttribution,
      contributingProviders: contributingProviders,
      matchConfidences: matchConfidences,
      primaryProvider: primaryProvider,
    ),
  );
}
