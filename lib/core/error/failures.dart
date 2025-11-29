/// Base class for all failures in the application
abstract class Failure {
  final String message;
  final String? code;

  const Failure(this.message, {this.code});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Failure && other.message == message && other.code == code;
  }

  @override
  int get hashCode => message.hashCode ^ code.hashCode;

  @override
  String toString() => 'Failure(message: $message, code: $code)';
}

/// Network-related failures
class NetworkFailure extends Failure {
  const NetworkFailure(super.message) : super(code: 'NETWORK_ERROR');
}

/// Extension-related failures
class ExtensionFailure extends Failure {
  const ExtensionFailure(super.message) : super(code: 'EXTENSION_ERROR');
}

/// Storage-related failures
class StorageFailure extends Failure {
  const StorageFailure(super.message) : super(code: 'STORAGE_ERROR');
}

/// Authentication-related failures
class AuthenticationFailure extends Failure {
  const AuthenticationFailure(super.message) : super(code: 'AUTH_ERROR');
}

/// Alias for backward compatibility
class AuthFailure extends AuthenticationFailure {
  const AuthFailure(super.message);
}

/// Validation-related failures
class ValidationFailure extends Failure {
  const ValidationFailure(super.message) : super(code: 'VALIDATION_ERROR');
}

/// Server-related failures
class ServerFailure extends Failure {
  const ServerFailure(super.message) : super(code: 'SERVER_ERROR');
}

/// Cache-related failures
class CacheFailure extends Failure {
  const CacheFailure(super.message) : super(code: 'CACHE_ERROR');
}

/// Unknown failures
class UnknownFailure extends Failure {
  const UnknownFailure(super.message) : super(code: 'UNKNOWN_ERROR');
}

/// Token refresh failures
class TokenRefreshFailure extends Failure {
  const TokenRefreshFailure(super.message) : super(code: 'TOKEN_REFRESH_ERROR');
}

/// Rate limit failures
class RateLimitFailure extends Failure {
  final Duration? retryAfter;

  const RateLimitFailure(super.message, {this.retryAfter})
    : super(code: 'RATE_LIMIT');
}

/// MAL authentication required failure
class MalAuthRequiredFailure extends AuthenticationFailure {
  const MalAuthRequiredFailure([String message = 'MAL authentication required'])
    : super(message);
}
