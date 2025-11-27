import 'package:flutter/material.dart';

/// Empty state widget for when no compatible extensions are available
///
/// Requirements: 7.5
class NoCompatibleExtensionsWidget extends StatelessWidget {
  const NoCompatibleExtensionsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.extension_off,
            size: 64,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 24),
          Text(
            'No Compatible Extensions',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'No extensions are available for this media type. Please install a compatible extension to continue.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              // Navigate to extensions screen
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.extension),
            label: const Text('Browse Extensions'),
          ),
        ],
      ),
    );
  }
}

/// Empty state widget for when search returns no results
///
/// Requirements: 2.4
class NoSearchResultsWidget extends StatelessWidget {
  /// The search query that returned no results
  final String query;

  /// Callback to clear search and try again
  final VoidCallback? onClear;

  const NoSearchResultsWidget({required this.query, this.onClear, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 24),
          Text(
            'No Results Found',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                Text(
                  'No results for "$query"',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Try a different search term or check the spelling',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          if (onClear != null) ...[
            const SizedBox(height: 24),
            FilledButton.tonal(
              onPressed: onClear,
              child: const Text('Clear Search'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Empty state widget for when no sources are available for selected media
///
/// Requirements: 4.4
class NoSourcesAvailableWidget extends StatelessWidget {
  /// Callback to retry loading sources
  final VoidCallback? onRetry;

  const NoSourcesAvailableWidget({this.onRetry, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.link_off, size: 64, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 24),
          Text(
            'No Sources Available',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'This media is not available in the selected extension. Try searching for a different title or select another extension.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Generic error state widget with retry option
///
/// Used for displaying various error conditions
class ErrorStateWidget extends StatelessWidget {
  /// The error message to display
  final String message;

  /// Optional detailed error description
  final String? description;

  /// Callback to retry the failed operation
  final VoidCallback? onRetry;

  /// Icon to display (defaults to error icon)
  final IconData icon;

  const ErrorStateWidget({
    required this.message,
    this.description,
    this.onRetry,
    this.icon = Icons.error_outline,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: colorScheme.error),
          const SizedBox(height: 24),
          Text(
            message,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (description != null) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                description!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }
}
