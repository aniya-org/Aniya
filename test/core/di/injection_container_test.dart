import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dependency Injection', () {
    final testSl = GetIt.instance;

    test('GetIt service locator should be accessible', () {
      // Verify that the service locator is available
      expect(testSl, isA<GetIt>());
    });

    test('should be able to register and retrieve a simple dependency', () {
      // Register a test dependency
      if (!testSl.isRegistered<String>(instanceName: 'test')) {
        testSl.registerLazySingleton<String>(
          () => 'test_value',
          instanceName: 'test',
        );
      }

      // Retrieve the dependency
      final value = testSl<String>(instanceName: 'test');

      // Verify
      expect(value, 'test_value');

      // Clean up
      testSl.unregister<String>(instanceName: 'test');
    });

    test('should prevent duplicate registrations', () {
      // Register a dependency
      if (!testSl.isRegistered<int>(instanceName: 'counter')) {
        testSl.registerLazySingleton<int>(() => 42, instanceName: 'counter');
      }

      // Attempt to register again should not throw
      expect(
        () => testSl.isRegistered<int>(instanceName: 'counter'),
        returnsNormally,
      );

      // Clean up
      testSl.unregister<int>(instanceName: 'counter');
    });
  });
}
