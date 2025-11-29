import 'package:flutter/material.dart';
import '../../../../core/enums/tracking_service.dart';

/// A dialog that prompts the user to connect a tracking service.
///
/// This dialog is shown when a feature requires authentication with a
/// tracking service (e.g., MAL for chapter data, AniList for user lists).
class TrackingAuthPromptDialog extends StatelessWidget {
  /// The tracking service that requires authentication
  final TrackingService service;

  /// Optional custom title for the dialog
  final String? title;

  /// Optional custom message explaining why auth is needed
  final String? message;

  /// Callback when user chooses to connect
  final VoidCallback? onConnect;

  /// Callback when user dismisses the dialog
  final VoidCallback? onDismiss;

  const TrackingAuthPromptDialog({
    super.key,
    required this.service,
    this.title,
    this.message,
    this.onConnect,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final serviceName = _getServiceDisplayName(service);
    final serviceColor = _getServiceColor(service);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: serviceColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getServiceIcon(service),
              color: serviceColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title ?? 'Connect $serviceName',
              style: theme.textTheme.titleLarge,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message ?? _getDefaultMessage(service),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          _buildBenefitsList(context, service),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(false);
            onDismiss?.call();
          },
          child: const Text('Maybe Later'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(true);
            onConnect?.call();
          },
          style: FilledButton.styleFrom(backgroundColor: serviceColor),
          child: Text('Connect $serviceName'),
        ),
      ],
    );
  }

  Widget _buildBenefitsList(BuildContext context, TrackingService service) {
    final benefits = _getServiceBenefits(service);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Benefits:',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...benefits.map(
          (benefit) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(benefit, style: theme.textTheme.bodySmall),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getServiceDisplayName(TrackingService service) {
    switch (service) {
      case TrackingService.mal:
        return 'MyAnimeList';
      case TrackingService.anilist:
        return 'AniList';
      case TrackingService.simkl:
        return 'Simkl';
      case TrackingService.jikan:
        return 'Jikan';
    }
  }

  Color _getServiceColor(TrackingService service) {
    switch (service) {
      case TrackingService.mal:
        return const Color(0xFF2E51A2); // MAL blue
      case TrackingService.anilist:
        return const Color(0xFF02A9FF); // AniList blue
      case TrackingService.simkl:
        return const Color(0xFF0B0F10); // Simkl dark
      case TrackingService.jikan:
        return const Color(0xFF2E51A2); // Same as MAL
    }
  }

  IconData _getServiceIcon(TrackingService service) {
    switch (service) {
      case TrackingService.mal:
        return Icons.list_alt;
      case TrackingService.anilist:
        return Icons.analytics_outlined;
      case TrackingService.simkl:
        return Icons.movie_outlined;
      case TrackingService.jikan:
        return Icons.api;
    }
  }

  String _getDefaultMessage(TrackingService service) {
    switch (service) {
      case TrackingService.mal:
        return 'Connect your MyAnimeList account to access additional features and track your progress.';
      case TrackingService.anilist:
        return 'Connect your AniList account to sync your anime and manga lists.';
      case TrackingService.simkl:
        return 'Connect your Simkl account to track your watching history across all your devices.';
      case TrackingService.jikan:
        return 'Jikan is a public API and does not require authentication.';
    }
  }

  List<String> _getServiceBenefits(TrackingService service) {
    switch (service) {
      case TrackingService.mal:
        return [
          'Access complete chapter counts for manga',
          'Track your reading and watching progress',
          'Sync your anime and manga lists',
          'Get personalized recommendations',
        ];
      case TrackingService.anilist:
        return [
          'Sync your anime and manga lists',
          'Track episodes and chapters',
          'Access your activity feed',
          'View detailed statistics',
        ];
      case TrackingService.simkl:
        return [
          'Track TV shows, anime, and movies',
          'Sync across all your devices',
          'Get calendar notifications',
          'Discover new content',
        ];
      case TrackingService.jikan:
        return ['Access MyAnimeList data without an account'];
    }
  }

  /// Show the dialog and return true if user chose to connect
  static Future<bool> show(
    BuildContext context, {
    required TrackingService service,
    String? title,
    String? message,
    VoidCallback? onConnect,
    VoidCallback? onDismiss,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => TrackingAuthPromptDialog(
        service: service,
        title: title,
        message: message,
        onConnect: onConnect,
        onDismiss: onDismiss,
      ),
    );
    return result ?? false;
  }
}

/// A banner widget that shows when a feature requires authentication
class TrackingAuthRequiredBanner extends StatelessWidget {
  final TrackingService service;
  final String? message;
  final VoidCallback? onConnect;

  const TrackingAuthRequiredBanner({
    super.key,
    required this.service,
    this.message,
    this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final serviceName = _getServiceDisplayName(service);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message ?? 'Connect $serviceName for more features',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: onConnect, child: const Text('Connect')),
        ],
      ),
    );
  }

  String _getServiceDisplayName(TrackingService service) {
    switch (service) {
      case TrackingService.mal:
        return 'MyAnimeList';
      case TrackingService.anilist:
        return 'AniList';
      case TrackingService.simkl:
        return 'Simkl';
      case TrackingService.jikan:
        return 'Jikan';
    }
  }
}
