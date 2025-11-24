import 'package:flutter_test/flutter_test.dart';
import 'package:aniya/core/error/exceptions.dart';

void main() {
  group('Exception', () {
    test('NetworkException should have correct message and code', () {
      const exception = NetworkException('Network error occurred');

      expect(exception.message, 'Network error occurred');
      expect(exception.code, 'NETWORK_ERROR');
    });

    test('ExtensionException should have correct message and code', () {
      const exception = ExtensionException('Extension failed to load');

      expect(exception.message, 'Extension failed to load');
      expect(exception.code, 'EXTENSION_ERROR');
    });

    test('StorageException should have correct message and code', () {
      const exception = StorageException('Storage operation failed');

      expect(exception.message, 'Storage operation failed');
      expect(exception.code, 'STORAGE_ERROR');
    });

    test('AuthenticationException should have correct message and code', () {
      const exception = AuthenticationException('Authentication failed');

      expect(exception.message, 'Authentication failed');
      expect(exception.code, 'AUTH_ERROR');
    });

    test('ValidationException should have correct message and code', () {
      const exception = ValidationException('Validation failed');

      expect(exception.message, 'Validation failed');
      expect(exception.code, 'VALIDATION_ERROR');
    });

    test('toString should return formatted string', () {
      const exception = NetworkException('Network error');

      expect(
        exception.toString(),
        'AppException(message: Network error, code: NETWORK_ERROR)',
      );
    });
  });
}
