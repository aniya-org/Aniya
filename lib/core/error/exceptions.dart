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

/// MAL authentication required exception
/// Thrown when a MAL API request requires authentication but no token is available
class MalAuthRequiredException extends AppException {
  const MalAuthRequiredException([
    String message = 'MAL authentication required',
  ]) : super(message, 'MAL_AUTH_REQUIRED');
}

/// MAL token expired exception
/// Thrown when a MAL API request fails due to an expired token
class MalAuthExpiredException extends AppException {
  const MalAuthExpiredException([String message = 'MAL token expired'])
    : super(message, 'MAL_AUTH_EXPIRED');
}

/// Rate limit exception
/// Thrown when an API request is rate limited
class RateLimitException extends AppException {
  final Duration? retryAfter;

  const RateLimitException([
    String message = 'Rate limit exceeded',
    this.retryAfter,
  ]) : super(message, 'RATE_LIMIT');
}

/// Token refresh exception
/// Thrown when token refresh fails
class TokenRefreshException extends AppException {
  const TokenRefreshException([String message = 'Token refresh failed'])
    : super(message, 'TOKEN_REFRESH_ERROR');
}
