/// Base class for all exceptions in the application
class AppException implements Exception {
  final String message;
  final String? code;

  const AppException(this.message, [this.code]);

  @override
  String toString() => 'AppException(message: $message, code: $code)';
}

/// Network-related exceptions
class NetworkException extends AppException {
  const NetworkException(String message) : super(message, 'NETWORK_ERROR');
}

/// Extension-related exceptions
class ExtensionException extends AppException {
  const ExtensionException(String message) : super(message, 'EXTENSION_ERROR');
}

/// Storage-related exceptions
class StorageException extends AppException {
  const StorageException(String message) : super(message, 'STORAGE_ERROR');
}

/// Authentication-related exceptions
class AuthenticationException extends AppException {
  const AuthenticationException(String message) : super(message, 'AUTH_ERROR');
}

/// Validation-related exceptions
class ValidationException extends AppException {
  const ValidationException(String message)
    : super(message, 'VALIDATION_ERROR');
}

/// Server-related exceptions
class ServerException extends AppException {
  const ServerException(String message) : super(message, 'SERVER_ERROR');
}

/// Cache-related exceptions
class CacheException extends AppException {
  const CacheException(String message) : super(message, 'CACHE_ERROR');
}

/// Not found exceptions
class NotFoundException extends AppException {
  const NotFoundException(String message) : super(message, 'NOT_FOUND');
}
