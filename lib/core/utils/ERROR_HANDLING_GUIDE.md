# Error Handling and Retry Logic Guide

This guide explains the error handling and retry logic implementation for the cross-provider data aggregation system.

## Overview

The system implements robust error handling with:
- **Exponential backoff** for transient network errors
- **Rate limit detection and queuing** for API rate limits
- **Timeout handling** for slow provider responses
- **Graceful degradation** when providers fail

## Components

### 1. RetryHandler

The `RetryHandler` class provides automatic retry logic with exponential backoff for network operations.

#### Features

- Configurable retry attempts (default: 3)
- Exponential backoff with jitter
- Automatic rate limit detection (429 status codes)
- Timeout handling
- Provider-specific error tracking

#### Usage

```dart
final retryHandler = RetryHandler();

final result = await retryHandler.execute(
  operation: () => fetchDataFromProvider(),
  providerId: 'anilist',
  operationName: 'Fetch anime details',
);
```

#### Configuration

```dart
// Default configuration
final handler = RetryHandler(
  config: RetryConfig.defaultConfig, // 3 attempts, 1s initial delay
);

// Aggressive retry for critical operations
final handler = RetryHandler(
  config: RetryConfig.aggressive, // 5 attempts, 500ms initial delay
);

// Conservative retry for non-critical operations
final handler = RetryHandler(
  config: RetryConfig.conservative, // 2 attempts, 2s initial delay
);

// Custom configuration
final handler = RetryHandler(
  config: RetryConfig(
    maxAttempts: 4,
    initialDelayMs: 1500,
    maxDelayMs: 60000,
    backoffMultiplier: 2.5,
    useJitter: true,
  ),
);
```

### 2. RateLimiter

The `RateLimiter` class manages API rate limits across multiple providers.

#### Features

- Per-provider rate limit tracking
- Automatic request queuing when rate limited
- Retry-After header parsing
- Automatic rate limit expiration

#### Usage

```dart
final rateLimiter = RateLimiter();

// Check if provider is rate limited
if (rateLimiter.isRateLimited('anilist')) {
  print('AniList is currently rate limited');
}

// Queue a request for a rate-limited provider
final result = await rateLimiter.queueRequest(
  'anilist',
  () => fetchFromAniList(),
);
```

#### Rate Limit Detection

The system automatically detects rate limits from:
- HTTP 429 (Too Many Requests) status codes
- `Retry-After` response headers (seconds or HTTP date)

When a rate limit is detected:
1. The provider is marked as rate limited
2. Subsequent requests are queued
3. Requests execute after the rate limit expires

### 3. Exponential Backoff

The retry handler implements exponential backoff to avoid overwhelming failing services.

#### Backoff Formula

```
delay = min(initialDelay * (multiplier ^ attempt), maxDelay)
```

With jitter (default):
```
delay = delay + random(0, delay * 0.25)
```

#### Example Delays

With default config (initialDelay=1000ms, multiplier=2.0):
- Attempt 1: 1000ms
- Attempt 2: 2000ms
- Attempt 3: 4000ms

With jitter, actual delays vary by ±25% to prevent thundering herd.

## Error Classification

### Retryable Errors

These errors trigger automatic retry:

1. **Network Errors**
   - Connection timeout
   - Send timeout
   - Receive timeout
   - Connection errors

2. **Server Errors (5xx)**
   - 500 Internal Server Error
   - 502 Bad Gateway
   - 503 Service Unavailable
   - 504 Gateway Timeout

3. **Specific Client Errors**
   - 408 Request Timeout
   - 429 Too Many Requests (with rate limiting)

### Non-Retryable Errors

These errors fail immediately without retry:

1. **Client Errors (4xx, except 408 and 429)**
   - 400 Bad Request
   - 401 Unauthorized
   - 403 Forbidden
   - 404 Not Found

2. **Cancellation**
   - User-initiated cancellation
   - Programmatic cancellation

## Integration with Cross-Provider System

### CrossProviderMatcher

The `CrossProviderMatcher` uses retry logic for provider searches:

```dart
final matcher = CrossProviderMatcher(
  retryHandler: RetryHandler(),
);

final matches = await matcher.findMatches(
  title: 'Naruto',
  type: MediaType.anime,
  primarySourceId: 'anilist',
  searchFunction: searchProvider,
);
```

**Behavior:**
- Each provider search has a 10-second timeout
- Failed searches are retried up to 3 times
- Provider failures don't block other providers
- Rate limits are respected automatically

### DataAggregator

The `DataAggregator` uses retry logic for data fetching:

```dart
final aggregator = DataAggregator(
  retryHandler: RetryHandler(),
);

final episodes = await aggregator.aggregateEpisodes(
  primaryMedia: media,
  matches: providerMatches,
  episodeFetcher: fetchEpisodes,
);
```

**Behavior:**
- Episode/chapter/details fetches are retried on failure
- Each provider has a 10-second timeout
- Failed providers return empty results
- Successful providers continue normally

## Logging

The system logs all retry attempts and errors:

```
INFO: Executing Search anilist for "Naruto" (attempt 1/3)
WARNING: Search anilist for "Naruto" failed on attempt 1: Connection timeout
INFO: Retrying Search anilist for "Naruto" in 1000ms (attempt 2/3)
INFO: Search anilist for "Naruto" succeeded on attempt 2
```

Rate limit events:
```
WARNING: Rate limit detected for Fetch episodes from kitsu
WARNING: Rate limit recorded for kitsu, resets at 2024-01-01 12:00:00
INFO: Waiting 60s for rate limit reset on kitsu
```

## Best Practices

### 1. Use Appropriate Retry Configs

```dart
// Critical user-facing operations
final handler = RetryHandler(config: RetryConfig.aggressive);

// Background sync operations
final handler = RetryHandler(config: RetryConfig.defaultConfig);

// Optional enhancements
final handler = RetryHandler(config: RetryConfig.conservative);
```

### 2. Provide Operation Names

```dart
await retryHandler.execute(
  operation: () => fetchData(),
  operationName: 'Fetch anime details from AniList', // Helps with debugging
  providerId: 'anilist',
);
```

### 3. Handle Final Failures Gracefully

```dart
try {
  final result = await retryHandler.execute(
    operation: () => fetchData(),
    providerId: 'anilist',
  );
  return result;
} catch (e) {
  // All retries exhausted
  Logger.error('Failed to fetch data after retries', error: e);
  return fallbackData; // Provide fallback or partial data
}
```

### 4. Custom Retry Logic

```dart
await retryHandler.execute(
  operation: () => customOperation(),
  shouldRetry: (error) {
    // Custom retry logic
    if (error is CustomException) {
      return error.isRetryable;
    }
    return false;
  },
);
```

## Testing

### Unit Tests

Test retry behavior with mock failures:

```dart
test('retries on network error', () async {
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
  );
  
  expect(result, 'success');
  expect(attempts, 3);
});
```

### Integration Tests

Test with real provider failures:

```dart
test('handles provider failure gracefully', () async {
  final matches = await matcher.findMatches(
    title: 'Test Anime',
    type: MediaType.anime,
    primarySourceId: 'anilist',
    searchFunction: (query, providerId, type) async {
      if (providerId == 'kitsu') {
        throw Exception('Provider error');
      }
      return mockResults;
    },
  );
  
  // Should have results from other providers
  expect(matches.containsKey('kitsu'), false);
  expect(matches.containsKey('jikan'), true);
});
```

## Performance Considerations

### Timeout Management

- Each provider has a 10-second timeout
- Parallel provider queries minimize total latency
- Timeouts prevent hanging on slow providers

### Rate Limit Efficiency

- Requests are queued, not dropped
- Rate limits are tracked per-provider
- Automatic retry after rate limit expires

### Memory Usage

- Request queues are cleaned up after processing
- Rate limit records expire automatically
- No unbounded growth of internal state

## Troubleshooting

### Issue: Too Many Retries

**Symptom:** Operations take too long due to excessive retries

**Solution:** Use conservative retry config or reduce max attempts

```dart
final handler = RetryHandler(
  config: RetryConfig(maxAttempts: 2),
);
```

### Issue: Rate Limits Not Respected

**Symptom:** Provider returns 429 errors repeatedly

**Solution:** Ensure providerId is passed to retry handler

```dart
await retryHandler.execute(
  operation: () => fetchData(),
  providerId: 'anilist', // Required for rate limiting
);
```

### Issue: Errors Not Logged

**Symptom:** Silent failures without logs

**Solution:** Check Logger configuration and ensure operation names are provided

```dart
await retryHandler.execute(
  operation: () => fetchData(),
  operationName: 'Descriptive operation name',
);
```

## Future Enhancements

Potential improvements to the error handling system:

1. **Adaptive Retry Delays**: Adjust delays based on provider response times
2. **Circuit Breaker Pattern**: Temporarily disable failing providers
3. **Metrics Collection**: Track retry rates and success rates per provider
4. **Custom Rate Limit Strategies**: Provider-specific rate limit handling
5. **Retry Budget**: Limit total retry time across all operations

## References

- Requirements: 7.1, 7.2, 7.3, 7.4, 7.5
- Design Document: Error Handling section
- Implementation: `lib/core/utils/retry_handler.dart`
- Tests: `test/core/utils/retry_handler_test.dart`
