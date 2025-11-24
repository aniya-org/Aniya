import '../error/failures.dart';

/// Utility class for converting Failures to user-friendly error messages
class ErrorMessageMapper {
  ErrorMessageMapper._();

  /// Convert a Failure to a user-friendly error message
  /// Validates: Requirements 13.1, 13.4
  static String mapFailureToMessage(Failure failure) {
    if (failure is NetworkFailure) {
      return _mapNetworkFailure(failure);
    } else if (failure is ExtensionFailure) {
      return _mapExtensionFailure(failure);
    } else if (failure is StorageFailure) {
      return _mapStorageFailure(failure);
    } else if (failure is AuthenticationFailure) {
      return _mapAuthenticationFailure(failure);
    } else if (failure is ValidationFailure) {
      return _mapValidationFailure(failure);
    } else if (failure is ServerFailure) {
      return _mapServerFailure(failure);
    } else if (failure is CacheFailure) {
      return _mapCacheFailure(failure);
    } else {
      return _mapUnknownFailure(failure);
    }
  }

  static String _mapNetworkFailure(NetworkFailure failure) {
    final message = failure.message.toLowerCase();

    if (message.contains('timeout') || message.contains('timed out')) {
      return 'Connection timed out. Please check your internet connection and try again.';
    } else if (message.contains('no internet') ||
        message.contains('no connection') ||
        message.contains('offline')) {
      return 'No internet connection. Please check your network settings.';
    } else if (message.contains('dns') || message.contains('host')) {
      return 'Unable to reach the server. Please try again later.';
    } else if (message.contains('ssl') || message.contains('certificate')) {
      return 'Secure connection failed. Please check your device date and time settings.';
    } else {
      return 'Network error: ${failure.message}';
    }
  }

  static String _mapExtensionFailure(ExtensionFailure failure) {
    final message = failure.message.toLowerCase();

    if (message.contains('not found')) {
      return 'Extension not found. It may have been removed or is no longer available.';
    } else if (message.contains('incompatible') ||
        message.contains('version')) {
      return 'Extension is incompatible with this version of the app. Please check for updates.';
    } else if (message.contains('install')) {
      return 'Failed to install extension. Please try again.';
    } else if (message.contains('load')) {
      return 'Failed to load extension. The extension may be corrupted.';
    } else {
      return 'Extension error: ${failure.message}';
    }
  }

  static String _mapStorageFailure(StorageFailure failure) {
    final message = failure.message.toLowerCase();

    if (message.contains('space') || message.contains('full')) {
      return 'Not enough storage space. Please free up some space and try again.';
    } else if (message.contains('permission')) {
      return 'Storage permission denied. Please grant storage access in settings.';
    } else if (message.contains('corrupt')) {
      return 'Storage data is corrupted. You may need to clear app data.';
    } else {
      return 'Storage error: ${failure.message}';
    }
  }

  static String _mapAuthenticationFailure(AuthenticationFailure failure) {
    final message = failure.message.toLowerCase();

    if (message.contains('invalid') && message.contains('token')) {
      return 'Your session has expired. Please sign in again.';
    } else if (message.contains('invalid') && message.contains('credentials')) {
      return 'Invalid username or password. Please check your credentials and try again.';
    } else if (message.contains('unauthorized')) {
      return 'Authentication failed. Please sign in again.';
    } else if (message.contains('expired')) {
      return 'Your session has expired. Please sign in again.';
    } else if (message.contains('forbidden')) {
      return 'You do not have permission to access this resource.';
    } else {
      return 'Authentication error: ${failure.message}';
    }
  }

  static String _mapValidationFailure(ValidationFailure failure) {
    return 'Validation error: ${failure.message}';
  }

  static String _mapServerFailure(ServerFailure failure) {
    final message = failure.message.toLowerCase();

    if (message.contains('500') || message.contains('internal server')) {
      return 'Server error. Please try again later.';
    } else if (message.contains('503') || message.contains('unavailable')) {
      return 'Service temporarily unavailable. Please try again later.';
    } else if (message.contains('404') || message.contains('not found')) {
      return 'The requested content was not found.';
    } else if (message.contains('429') || message.contains('rate limit')) {
      return 'Too many requests. Please wait a moment and try again.';
    } else {
      return 'Server error: ${failure.message}';
    }
  }

  static String _mapCacheFailure(CacheFailure failure) {
    return 'Cache error: ${failure.message}';
  }

  static String _mapUnknownFailure(Failure failure) {
    return 'An unexpected error occurred: ${failure.message}';
  }
}
