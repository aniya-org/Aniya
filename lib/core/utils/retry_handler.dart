import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import '../error/exceptions.dart';
import 'logger.dart';

/// Configuration for retry behavior
class RetryConfig {
  /// Maximum number of retry attempts
  final int maxAttempts;

  /// Initial delay before first retry (in milliseconds)
  final int initialDelayMs;

  /// Maximum delay between retries (in milliseconds)
  final int maxDelayMs;

  /// Multiplier for exponential backoff
  final double backoffMultiplier;

  /// Whether to add jitter to retry delays
  final bool useJitter;

  const RetryConfig({
    this.maxAttempts = 3,
    this.initialDelayMs = 1000,
    this.maxDelayMs = 30000,
    this.backoffMultiplier = 2.0,
    this.useJitter = true,
  });

  /// Default configuration for network retries
  static const RetryConfig defaultConfig = RetryConfig();

  /// Aggressive retry configuration for critical operations
  static const RetryConfig aggressive = RetryConfig(
    maxAttempts: 5,
    initialDelayMs: 500,
    maxDelayMs: 60000,
    backoffMultiplier: 2.0,
  );

  /// Conservative retry configuration for non-critical operations
  static const RetryConfig conservative = RetryConfig(
    maxAttempts: 2,
    initialDelayMs: 2000,
    maxDelayMs: 10000,
    backoffMultiplier: 1.5,
  );
}

/// Handles rate limiting for API providers
class RateLimiter {
  final Map<String, _ProviderRateLimit> _providerLimits = {};
  final Map<String, Queue<_QueuedRequest>> _requestQueues = {};

  /// Check if a provider is currently rate limited
  bool isRateLimited(String providerId) {
    final limit = _providerLimits[providerId];
    if (limit == null) return false;

    if (DateTime.now().isAfter(limit.resetTime)) {
      // Rate limit has expired
      _providerLimits.remove(providerId);
      return false;
    }

    return true;
  }

  /// Record a rate limit for a provider
  void recordRateLimit(String providerId, {Duration? retryAfter}) {
    final resetTime = DateTime.now().add(
      retryAfter ?? const Duration(minutes: 1),
    );

    _providerLimits[providerId] = _ProviderRateLimit(
      providerId: providerId,
      resetTime: resetTime,
    );

    Logger.warning(
      'RATE LIMIT: Provider $providerId rate limited, resets at $resetTime',
      tag: 'RateLimiter',
    );
  }

  /// Get the time until rate limit resets for a provider
  Duration? getTimeUntilReset(String providerId) {
    final limit = _providerLimits[providerId];
    if (limit == null) return null;

    final now = DateTime.now();
    if (now.isAfter(limit.resetTime)) {
      _providerLimits.remove(providerId);
      return null;
    }

    return limit.resetTime.difference(now);
  }

  /// Queue a request for a rate-limited provider
  Future<T> queueRequest<T>(
    String providerId,
    Future<T> Function() request,
  ) async {
    // If not rate limited, execute immediately
    if (!isRateLimited(providerId)) {
      return await request();
    }

    // Create queue if it doesn't exist
    _requestQueues[providerId] ??= Queue<_QueuedRequest>();

    // Create a completer for this request
    final completer = Completer<T>();

    // Add to queue
    _requestQueues[providerId]!.add(
      _QueuedRequest(
        execute: () async {
          try {
            final result = await request();
            completer.complete(result);
          } catch (e) {
            completer.completeError(e);
          }
        },
      ),
    );

    // Start processing queue if not already processing
    _processQueue(providerId);

    return completer.future;
  }

  /// Process queued requests for a provider
  Future<void> _processQueue(String providerId) async {
    final queue = _requestQueues[providerId];
    if (queue == null || queue.isEmpty) return;

    // Wait for rate limit to reset
    final timeUntilReset = getTimeUntilReset(providerId);
    if (timeUntilReset != null) {
      Logger.info(
        'RATE LIMIT WAIT: Waiting ${timeUntilReset.inSeconds}s for rate limit reset on $providerId',
        tag: 'RateLimiter',
      );
      await Future.delayed(timeUntilReset);
    }

    // Process all queued requests
    while (queue.isNotEmpty) {
      final request = queue.removeFirst();
      try {
        await request.execute();
      } catch (e) {
        Logger.error('Queued request failed for $providerId', error: e);
      }

      // Small delay between requests to avoid immediate re-rate-limiting
      if (queue.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    // Clean up empty queue
    if (queue.isEmpty) {
      _requestQueues.remove(providerId);
    }
  }

  /// Clear all rate limits (useful for testing)
  void clearAll() {
    _providerLimits.clear();
    _requestQueues.clear();
  }
}

/// Simple queue implementation
class Queue<T> {
  final List<T> _items = [];

  void add(T item) => _items.add(item);
  T removeFirst() => _items.removeAt(0);
  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;
  int get length => _items.length;
}

/// Represents a rate limit for a provider
class _ProviderRateLimit {
  final String providerId;
  final DateTime resetTime;

  _ProviderRateLimit({required this.providerId, required this.resetTime});
}

/// Represents a queued request
class _QueuedRequest {
  final Future<void> Function() execute;

  _QueuedRequest({required this.execute});
}

/// Handles retry logic with exponential backoff
class RetryHandler {
  final RetryConfig config;
  final RateLimiter rateLimiter;

  RetryHandler({RetryConfig? config, RateLimiter? rateLimiter})
    : config = config ?? RetryConfig.defaultConfig,
      rateLimiter = rateLimiter ?? RateLimiter();

  /// Execute a function with retry logic and exponential backoff
  ///
  /// This method will retry the operation on transient failures (network errors,
  /// timeouts, 5xx server errors) using exponential backoff. It handles rate
  /// limiting by detecting 429 responses and queuing requests appropriately.
  ///
  /// Parameters:
  /// - [operation]: The async operation to execute
  /// - [providerId]: Optional provider ID for rate limiting
  /// - [operationName]: Optional name for logging
  /// - [shouldRetry]: Optional function to determine if an error should trigger a retry
  ///
  /// Returns the result of the operation
  /// Throws the last error if all retries are exhausted
  Future<T> execute<T>({
    required Future<T> Function() operation,
    String? providerId,
    String? operationName,
    bool Function(Object error)? shouldRetry,
  }) async {
    final opName = operationName ?? 'operation';
    int attempt = 0;
    Object? lastError;

    while (attempt < config.maxAttempts) {
      attempt++;

      try {
        if (attempt > 1) {
          Logger.info(
            'RETRY: Executing $opName (attempt $attempt/${config.maxAttempts})',
            tag: 'RetryHandler',
          );
        }

        // If provider is rate limited, queue the request
        if (providerId != null && rateLimiter.isRateLimited(providerId)) {
          Logger.info(
            'RATE LIMIT QUEUE: Provider $providerId is rate limited, queuing request',
            tag: 'RetryHandler',
          );
          return await rateLimiter.queueRequest(providerId, operation);
        }

        // Execute the operation
        final result = await operation();

        // Success! Log if this wasn't the first attempt
        if (attempt > 1) {
          Logger.info(
            'RETRY SUCCESS: $opName succeeded on attempt $attempt',
            tag: 'RetryHandler',
          );
        }

        return result;
      } on DioException catch (e) {
        lastError = e;

        // Handle rate limiting (429 status code)
        if (e.response?.statusCode == 429) {
          Logger.warning(
            'RATE LIMIT DETECTED: Rate limit (429) detected for $opName',
            tag: 'RetryHandler',
          );

          if (providerId != null) {
            // Extract retry-after header if available
            final retryAfterHeader = e.response?.headers.value('retry-after');
            Duration? retryAfter;

            if (retryAfterHeader != null) {
              // Try to parse as seconds
              final seconds = int.tryParse(retryAfterHeader);
              if (seconds != null) {
                retryAfter = Duration(seconds: seconds);
              }
            }

            // Record the rate limit
            rateLimiter.recordRateLimit(providerId, retryAfter: retryAfter);

            // Queue this request
            return await rateLimiter.queueRequest(providerId, operation);
          }

          // If no provider ID, just wait and retry
          if (attempt < config.maxAttempts) {
            final delay = _calculateDelay(attempt);
            Logger.info('Waiting ${delay.inMilliseconds}ms before retry');
            await Future.delayed(delay);
            continue;
          }
        }

        // Check if this is a retryable error
        final isRetryable = shouldRetry?.call(e) ?? _isRetryableError(e);

        if (!isRetryable) {
          Logger.error(
            'RETRY FAILED: $opName failed with non-retryable error',
            tag: 'RetryHandler',
            error: e,
          );
          rethrow;
        }

        // Log the error
        Logger.warning(
          'RETRY ATTEMPT: $opName failed on attempt $attempt: ${e.message}',
          tag: 'RetryHandler',
        );

        // If we've exhausted retries, throw
        if (attempt >= config.maxAttempts) {
          Logger.error(
            'RETRY EXHAUSTED: $opName failed after $attempt attempts',
            tag: 'RetryHandler',
            error: e,
          );
          rethrow;
        }

        // Calculate delay with exponential backoff
        final delay = _calculateDelay(attempt);
        Logger.info(
          'EXPONENTIAL BACKOFF: Retrying $opName in ${delay.inMilliseconds}ms (attempt ${attempt + 1}/${config.maxAttempts})',
          tag: 'RetryHandler',
        );

        await Future.delayed(delay);
      } on TimeoutException catch (e) {
        lastError = e;

        Logger.warning(
          'TIMEOUT: $opName timed out on attempt $attempt',
          tag: 'RetryHandler',
        );

        // Timeouts are always retryable
        if (attempt >= config.maxAttempts) {
          Logger.error(
            'TIMEOUT EXHAUSTED: $opName timed out after $attempt attempts',
            tag: 'RetryHandler',
            error: e,
          );
          throw NetworkException('Operation timed out after $attempt attempts');
        }

        final delay = _calculateDelay(attempt);
        Logger.info(
          'EXPONENTIAL BACKOFF: Retrying $opName in ${delay.inMilliseconds}ms after timeout',
          tag: 'RetryHandler',
        );

        await Future.delayed(delay);
      } catch (e) {
        lastError = e;

        // Check if this is a retryable error
        final isRetryable = shouldRetry?.call(e) ?? false;

        if (!isRetryable) {
          Logger.error(
            'RETRY FAILED: $opName failed with non-retryable error',
            tag: 'RetryHandler',
            error: e,
          );
          rethrow;
        }

        Logger.warning(
          'RETRY ATTEMPT: $opName failed on attempt $attempt: $e',
          tag: 'RetryHandler',
        );

        if (attempt >= config.maxAttempts) {
          Logger.error(
            'RETRY EXHAUSTED: $opName failed after $attempt attempts',
            tag: 'RetryHandler',
            error: e,
          );
          rethrow;
        }

        final delay = _calculateDelay(attempt);
        await Future.delayed(delay);
      }
    }

    // This should never be reached, but just in case
    throw lastError ??
        Exception('Operation failed after ${config.maxAttempts} attempts');
  }

  /// Calculate delay for exponential backoff
  ///
  /// The delay increases exponentially with each attempt:
  /// - Attempt 1: initialDelayMs
  /// - Attempt 2: initialDelayMs * backoffMultiplier
  /// - Attempt 3: initialDelayMs * backoffMultiplier^2
  /// - etc.
  ///
  /// Optionally adds jitter to prevent thundering herd problem.
  Duration _calculateDelay(int attempt) {
    // Calculate exponential delay
    final exponentialDelay =
        config.initialDelayMs *
        pow(config.backoffMultiplier, attempt - 1).toDouble();

    // Cap at max delay
    var delayMs = min(exponentialDelay, config.maxDelayMs.toDouble());

    // Add jitter if enabled (random value between 0 and 25% of delay)
    if (config.useJitter) {
      final jitter = Random().nextDouble() * delayMs * 0.25;
      delayMs += jitter;
    }

    return Duration(milliseconds: delayMs.round());
  }

  /// Determine if a DioException is retryable
  ///
  /// Retryable errors include:
  /// - Network errors (connection timeout, send timeout, receive timeout)
  /// - 5xx server errors (temporary server issues)
  /// - 408 Request Timeout
  /// - 429 Too Many Requests (handled separately with rate limiting)
  ///
  /// Non-retryable errors include:
  /// - 4xx client errors (except 408 and 429)
  /// - Cancellation
  bool _isRetryableError(DioException error) {
    // Network errors are retryable
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return true;
    }

    // Cancellation is not retryable
    if (error.type == DioExceptionType.cancel) {
      return false;
    }

    // Check status code
    final statusCode = error.response?.statusCode;
    if (statusCode == null) {
      // No response means network error, retryable
      return true;
    }

    // 5xx errors are retryable (server errors)
    if (statusCode >= 500 && statusCode < 600) {
      return true;
    }

    // 408 Request Timeout is retryable
    if (statusCode == 408) {
      return true;
    }

    // 429 Too Many Requests is retryable (handled with rate limiting)
    if (statusCode == 429) {
      return true;
    }

    // 4xx errors (except 408 and 429) are not retryable
    if (statusCode >= 400 && statusCode < 500) {
      return false;
    }

    // Default to not retryable for unknown cases
    return false;
  }
}
