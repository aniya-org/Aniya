import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aniya/core/utils/retry_handler.dart';
import 'package:aniya/core/error/exceptions.dart';

void main() {
  group('RetryConfig', () {
    test('default config has expected values', () {
      const config = RetryConfig.defaultConfig;

      expect(config.maxAttempts, 3);
      expect(config.initialDelayMs, 1000);
      expect(config.maxDelayMs, 30000);
      expect(config.backoffMultiplier, 2.0);
      expect(config.useJitter, true);
    });

    test('aggressive config has more retries', () {
      const config = RetryConfig.aggressive;

      expect(config.maxAttempts, 5);
      expect(config.initialDelayMs, 500);
    });

    test('conservative config has fewer retries', () {
      const config = RetryConfig.conservative;

      expect(config.maxAttempts, 2);
      expect(config.initialDelayMs, 2000);
    });
  });

  group('RateLimiter', () {
    late RateLimiter rateLimiter;

    setUp(() {
      rateLimiter = RateLimiter();
    });

    test('provider is not rate limited initially', () {
      expect(rateLimiter.isRateLimited('test-provider'), false);
    });

    test('provider is rate limited after recording', () {
      rateLimiter.recordRateLimit('test-provider');

      expect(rateLimiter.isRateLimited('test-provider'), true);
    });

    test('rate limit expires after duration', () async {
      rateLimiter.recordRateLimit(
        'test-provider',
        retryAfter: const Duration(milliseconds: 100),
      );

      expect(rateLimiter.isRateLimited('test-provider'), true);

      // Wait for rate limit to expire
      await Future.delayed(const Duration(milliseconds: 150));

      expect(rateLimiter.isRateLimited('test-provider'), false);
    });

    test('getTimeUntilReset returns correct duration', () {
      rateLimiter.recordRateLimit(
        'test-provider',
        retryAfter: const Duration(seconds: 10),
      );

      final timeUntilReset = rateLimiter.getTimeUntilReset('test-provider');

      expect(timeUntilReset, isNotNull);
      expect(timeUntilReset!.inSeconds, greaterThanOrEqualTo(9));
      expect(timeUntilReset.inSeconds, lessThanOrEqualTo(10));
    });

    test('queueRequest executes immediately when not rate limited', () async {
      var executed = false;

      final result = await rateLimiter.queueRequest('test-provider', () async {
        executed = true;
        return 'success';
      });

      expect(executed, true);
      expect(result, 'success');
    });

    test('queueRequest waits when rate limited', () async {
      rateLimiter.recordRateLimit(
        'test-provider',
        retryAfter: const Duration(milliseconds: 100),
      );

      var executed = false;
      final startTime = DateTime.now();

      final resultFuture = rateLimiter.queueRequest('test-provider', () async {
        executed = true;
        return 'success';
      });

      // Should not execute immediately
      await Future.delayed(const Duration(milliseconds: 50));
      expect(executed, false);

      // Wait for result
      final result = await resultFuture;
      final elapsed = DateTime.now().difference(startTime);

      expect(executed, true);
      expect(result, 'success');
      expect(elapsed.inMilliseconds, greaterThanOrEqualTo(100));
    });

    test('clearAll removes all rate limits', () {
      rateLimiter.recordRateLimit('provider1');
      rateLimiter.recordRateLimit('provider2');

      expect(rateLimiter.isRateLimited('provider1'), true);
      expect(rateLimiter.isRateLimited('provider2'), true);

      rateLimiter.clearAll();

      expect(rateLimiter.isRateLimited('provider1'), false);
      expect(rateLimiter.isRateLimited('provider2'), false);
    });
  });

  group('RetryHandler', () {
    late RetryHandler retryHandler;
    late RateLimiter rateLimiter;

    setUp(() {
      rateLimiter = RateLimiter();
      retryHandler = RetryHandler(
        config: const RetryConfig(
          maxAttempts: 3,
          initialDelayMs: 10, // Short delays for testing
          maxDelayMs: 100,
          backoffMultiplier: 2.0,
          useJitter: false, // Disable jitter for predictable tests
        ),
        rateLimiter: rateLimiter,
      );
    });

    test('execute succeeds on first attempt', () async {
      var attempts = 0;

      final result = await retryHandler.execute(
        operation: () async {
          attempts++;
          return 'success';
        },
        operationName: 'test-operation',
      );

      expect(result, 'success');
      expect(attempts, 1);
    });

    test('execute retries on network error', () async {
      var attempts = 0;

      final result = await retryHandler.execute(
        operation: () async {
          attempts++;
          if (attempts < 3) {
            throw DioException(
              requestOptions: RequestOptions(path: '/test'),
              type: DioExceptionType.connectionTimeout,
            );
          }
          return 'success';
        },
        operationName: 'test-operation',
      );

      expect(result, 'success');
      expect(attempts, 3);
    });

    test('execute retries on 5xx server error', () async {
      var attempts = 0;

      final result = await retryHandler.execute(
        operation: () async {
          attempts++;
          if (attempts < 2) {
            throw DioException(
              requestOptions: RequestOptions(path: '/test'),
              response: Response(
                requestOptions: RequestOptions(path: '/test'),
                statusCode: 503,
              ),
            );
          }
          return 'success';
        },
        operationName: 'test-operation',
      );

      expect(result, 'success');
      expect(attempts, 2);
    });

    test('execute does not retry on 4xx client error', () async {
      var attempts = 0;

      expect(
        () => retryHandler.execute(
          operation: () async {
            attempts++;
            throw DioException(
              requestOptions: RequestOptions(path: '/test'),
              response: Response(
                requestOptions: RequestOptions(path: '/test'),
                statusCode: 404,
              ),
            );
          },
          operationName: 'test-operation',
        ),
        throwsA(isA<DioException>()),
      );

      await Future.delayed(const Duration(milliseconds: 50));
      expect(attempts, 1); // Should not retry
    });

    test('execute retries on timeout', () async {
      var attempts = 0;

      final result = await retryHandler.execute(
        operation: () async {
          attempts++;
          if (attempts < 2) {
            throw TimeoutException('Operation timed out');
          }
          return 'success';
        },
        operationName: 'test-operation',
      );

      expect(result, 'success');
      expect(attempts, 2);
    });

    test('execute handles rate limiting with 429 status', () async {
      var attempts = 0;

      final result = await retryHandler.execute(
        operation: () async {
          attempts++;
          if (attempts == 1) {
            throw DioException(
              requestOptions: RequestOptions(path: '/test'),
              response: Response(
                requestOptions: RequestOptions(path: '/test'),
                statusCode: 429,
                headers: Headers.fromMap({
                  'retry-after': ['1'], // 1 second
                }),
              ),
            );
          }
          return 'success';
        },
        providerId: 'test-provider',
        operationName: 'test-operation',
      );

      expect(result, 'success');
      expect(attempts, greaterThanOrEqualTo(2));
    });

    test('execute throws after max attempts', () async {
      var attempts = 0;

      expect(
        () => retryHandler.execute(
          operation: () async {
            attempts++;
            throw DioException(
              requestOptions: RequestOptions(path: '/test'),
              type: DioExceptionType.connectionTimeout,
            );
          },
          operationName: 'test-operation',
        ),
        throwsA(isA<DioException>()),
      );

      await Future.delayed(const Duration(milliseconds: 200));
      expect(attempts, 3); // Should try maxAttempts times
    });

    test('execute uses exponential backoff', () async {
      var attempts = 0;
      final attemptTimes = <DateTime>[];

      try {
        await retryHandler.execute(
          operation: () async {
            attempts++;
            attemptTimes.add(DateTime.now());
            throw DioException(
              requestOptions: RequestOptions(path: '/test'),
              type: DioExceptionType.connectionTimeout,
            );
          },
          operationName: 'test-operation',
        );
      } catch (e) {
        // Expected to fail
      }

      expect(attempts, 3);
      expect(attemptTimes.length, 3);

      // Check that delays increase exponentially
      // First retry: ~10ms delay
      // Second retry: ~20ms delay
      if (attemptTimes.length >= 3) {
        final delay1 = attemptTimes[1].difference(attemptTimes[0]);
        final delay2 = attemptTimes[2].difference(attemptTimes[1]);

        expect(delay1.inMilliseconds, greaterThanOrEqualTo(8));
        expect(
          delay2.inMilliseconds,
          greaterThanOrEqualTo(delay1.inMilliseconds),
        );
      }
    });

    test('execute respects custom shouldRetry function', () async {
      var attempts = 0;

      final result = await retryHandler.execute(
        operation: () async {
          attempts++;
          if (attempts < 2) {
            throw Exception('Custom error');
          }
          return 'success';
        },
        operationName: 'test-operation',
        shouldRetry: (error) => error is Exception,
      );

      expect(result, 'success');
      expect(attempts, 2);
    });

    test('execute logs errors without blocking', () async {
      // This test verifies that errors are logged but don't prevent
      // the operation from continuing with other providers

      var attempts = 0;

      try {
        await retryHandler.execute(
          operation: () async {
            attempts++;
            throw DioException(
              requestOptions: RequestOptions(path: '/test'),
              type: DioExceptionType.connectionTimeout,
            );
          },
          operationName: 'test-operation',
        );
      } catch (e) {
        // Expected to fail after retries
      }

      // Verify that all retry attempts were made
      expect(attempts, 3);
    });
  });

  group('RetryHandler - Integration', () {
    test('handles multiple providers with different rate limits', () async {
      final rateLimiter = RateLimiter();
      final retryHandler = RetryHandler(
        config: const RetryConfig(
          maxAttempts: 2,
          initialDelayMs: 10,
          maxDelayMs: 100,
          useJitter: false,
        ),
        rateLimiter: rateLimiter,
      );

      // Simulate provider1 being rate limited
      rateLimiter.recordRateLimit(
        'provider1',
        retryAfter: const Duration(milliseconds: 100),
      );

      var provider1Executed = false;
      var provider2Executed = false;

      // Execute requests for both providers in parallel
      final futures = [
        retryHandler.execute(
          operation: () async {
            provider1Executed = true;
            return 'provider1-result';
          },
          providerId: 'provider1',
          operationName: 'provider1-operation',
        ),
        retryHandler.execute(
          operation: () async {
            provider2Executed = true;
            return 'provider2-result';
          },
          providerId: 'provider2',
          operationName: 'provider2-operation',
        ),
      ];

      // Provider2 should execute immediately
      await Future.delayed(const Duration(milliseconds: 20));
      expect(provider2Executed, true);
      expect(provider1Executed, false);

      // Wait for all to complete
      final results = await Future.wait(futures);

      expect(results[0], 'provider1-result');
      expect(results[1], 'provider2-result');
      expect(provider1Executed, true);
    });
  });
}
