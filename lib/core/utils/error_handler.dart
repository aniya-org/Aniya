import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'logger.dart';

/// Global error handler for the application
/// Ensures the app doesn't crash on unhandled errors
/// Validates: Requirements 13.6
class ErrorHandler {
  ErrorHandler._();

  /// Initialize global error handling
  static void initialize() {
    // Handle Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      Logger.error(
        'Flutter framework error',
        tag: 'ErrorHandler',
        error: details.exception,
        stackTrace: details.stack,
      );

      // In debug mode, show the error
      if (kDebugMode) {
        FlutterError.presentError(details);
      }
    };

    // Handle errors outside of Flutter framework
    PlatformDispatcher.instance.onError = (error, stack) {
      Logger.error(
        'Unhandled error',
        tag: 'ErrorHandler',
        error: error,
        stackTrace: stack,
      );

      // Return true to indicate the error was handled
      return true;
    };

    // Handle async errors
    runZonedGuarded(
      () {
        // App initialization will happen here
      },
      (error, stack) {
        Logger.error(
          'Async error',
          tag: 'ErrorHandler',
          error: error,
          stackTrace: stack,
        );
      },
    );
  }

  /// Show a user-friendly error dialog
  static void showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show a user-friendly error snackbar
  static void showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
}
