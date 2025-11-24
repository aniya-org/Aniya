import 'package:flutter/material.dart';

/// A Material Design 3 error view for displaying errors
class ErrorView extends StatelessWidget {
  final String message;
  final String? title;
  final IconData? icon;
  final VoidCallback? onRetry;
  final String? retryLabel;

  const ErrorView({
    super.key,
    required this.message,
    this.title,
    this.icon,
    this.onRetry,
    this.retryLabel,
  });

  /// Factory constructor for network errors
  factory ErrorView.network({String? message, VoidCallback? onRetry}) {
    return ErrorView(
      title: 'Network Error',
      message:
          message ??
          'Unable to connect to the server. Please check your internet connection.',
      icon: Icons.wifi_off,
      onRetry: onRetry,
      retryLabel: 'Retry',
    );
  }

  /// Factory constructor for not found errors
  factory ErrorView.notFound({String? message, VoidCallback? onRetry}) {
    return ErrorView(
      title: 'Not Found',
      message: message ?? 'The content you are looking for could not be found.',
      icon: Icons.search_off,
      onRetry: onRetry,
      retryLabel: 'Go Back',
    );
  }

  /// Factory constructor for generic errors
  factory ErrorView.generic({String? message, VoidCallback? onRetry}) {
    return ErrorView(
      title: 'Something Went Wrong',
      message: message ?? 'An unexpected error occurred. Please try again.',
      icon: Icons.error_outline,
      onRetry: onRetry,
      retryLabel: 'Retry',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Error Icon
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon ?? Icons.error_outline,
                size: 64,
                color: colorScheme.onErrorContainer,
              ),
            ),

            const SizedBox(height: 24),

            // Error Title
            if (title != null)
              Text(
                title!,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),

            const SizedBox(height: 12),

            // Error Message
            Text(
              message,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),

            // Retry Button
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(retryLabel ?? 'Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A compact error message widget for inline errors
class ErrorMessage extends StatelessWidget {
  final String message;
  final VoidCallback? onDismiss;

  const ErrorMessage({super.key, required this.message, this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
          if (onDismiss != null)
            IconButton(
              icon: Icon(Icons.close, color: colorScheme.onErrorContainer),
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}

/// A snackbar for showing error messages
class ErrorSnackBar extends SnackBar {
  ErrorSnackBar({super.key, required String message, VoidCallback? onRetry})
    : super(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        action: onRetry != null
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      );
}
