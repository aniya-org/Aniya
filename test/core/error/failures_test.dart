import 'package:flutter_test/flutter_test.dart';
import 'package:aniya/core/error/failures.dart';

void main() {
  group('Failure', () {
    test('NetworkFailure should have correct message and code', () {
      const failure = NetworkFailure('Network error occurred');

      expect(failure.message, 'Network error occurred');
      expect(failure.code, 'NETWORK_ERROR');
    });

    test('ExtensionFailure should have correct message and code', () {
      const failure = ExtensionFailure('Extension failed to load');

      expect(failure.message, 'Extension failed to load');
      expect(failure.code, 'EXTENSION_ERROR');
    });

    test('StorageFailure should have correct message and code', () {
      const failure = StorageFailure('Storage operation failed');

      expect(failure.message, 'Storage operation failed');
      expect(failure.code, 'STORAGE_ERROR');
    });

    test('AuthenticationFailure should have correct message and code', () {
      const failure = AuthenticationFailure('Authentication failed');

      expect(failure.message, 'Authentication failed');
      expect(failure.code, 'AUTH_ERROR');
    });

    test('ValidationFailure should have correct message and code', () {
      const failure = ValidationFailure('Validation failed');

      expect(failure.message, 'Validation failed');
      expect(failure.code, 'VALIDATION_ERROR');
    });

    test('Failures with same message and code should be equal', () {
      const failure1 = NetworkFailure('Network error');
      const failure2 = NetworkFailure('Network error');

      expect(failure1, equals(failure2));
      expect(failure1.hashCode, equals(failure2.hashCode));
    });

    test('Failures with different messages should not be equal', () {
      const failure1 = NetworkFailure('Network error 1');
      const failure2 = NetworkFailure('Network error 2');

      expect(failure1, isNot(equals(failure2)));
    });

    test('toString should return formatted string', () {
      const failure = NetworkFailure('Network error');

      expect(
        failure.toString(),
        'Failure(message: Network error, code: NETWORK_ERROR)',
      );
    });
  });
}
