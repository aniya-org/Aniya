/// Base class for all failures in the application
abstract class Failure {
  final String message;
  final String? code;

  const Failure(this.message, [this.code]);

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
  const NetworkFailure(String message) : super(message, 'NETWORK_ERROR');
}

/// Extension-related failures
class ExtensionFailure extends Failure {
  const ExtensionFailure(String message) : super(message, 'EXTENSION_ERROR');
}

/// Storage-related failures
class StorageFailure extends Failure {
  const StorageFailure(String message) : super(message, 'STORAGE_ERROR');
}

/// Authentication-related failures
class AuthenticationFailure extends Failure {
  const AuthenticationFailure(String message) : super(message, 'AUTH_ERROR');
}

/// Validation-related failures
class ValidationFailure extends Failure {
  const ValidationFailure(String message) : super(message, 'VALIDATION_ERROR');
}

/// Server-related failures
class ServerFailure extends Failure {
  const ServerFailure(String message) : super(message, 'SERVER_ERROR');
}

/// Cache-related failures
class CacheFailure extends Failure {
  const CacheFailure(String message) : super(message, 'CACHE_ERROR');
}

/// Unknown failures
class UnknownFailure extends Failure {
  const UnknownFailure(String message) : super(message, 'UNKNOWN_ERROR');
}
