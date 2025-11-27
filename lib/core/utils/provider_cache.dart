import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../error/exceptions.dart';
import 'logger.dart';

/// Cache entry for cross-provider mappings
class CachedMapping {
  final String primaryProviderId;
  final String primaryMediaId;
  final Map<String, String> providerMappings;
  final DateTime cachedAt;

  CachedMapping({
    required this.primaryProviderId,
    required this.primaryMediaId,
    required this.providerMappings,
    required this.cachedAt,
  });

  Map<String, dynamic> toJson() => {
    'primaryProviderId': primaryProviderId,
    'primaryMediaId': primaryMediaId,
    'providerMappings': providerMappings,
    'cachedAt': cachedAt.toIso8601String(),
  };

  factory CachedMapping.fromJson(Map<String, dynamic> json) {
    return CachedMapping(
      primaryProviderId: json['primaryProviderId'] as String,
      primaryMediaId: json['primaryMediaId'] as String,
      providerMappings: Map<String, String>.from(
        json['providerMappings'] as Map,
      ),
      cachedAt: DateTime.parse(json['cachedAt'] as String),
    );
  }

  String get cacheKey => '${primaryProviderId}_$primaryMediaId';
}

/// Manages caching of cross-provider ID mappings
///
/// Stores mappings between provider IDs with timestamps for expiration tracking.
/// Implements LRU eviction when cache exceeds size limits.
class ProviderCache {
  static const String _boxName = 'provider_cache';
  static const String _metadataKey = 'cache_metadata';
  static const int _maxCacheSizeBytes = 10 * 1024 * 1024; // 10MB
  static const int _ttlDays = 7;

  Box<String>? _box;
  final Map<String, DateTime> _accessTimes = {};

  /// Initialize the cache
  Future<void> init() async {
    try {
      _box = await Hive.openBox<String>(_boxName);
      await _loadAccessTimes();
    } catch (e) {
      Logger.error('Failed to initialize ProviderCache', error: e);
      throw CacheException('Failed to initialize cache: $e');
    }
  }

  /// Store a provider mapping
  Future<void> storeMapping({
    required String primaryProviderId,
    required String primaryMediaId,
    required Map<String, String> providerMappings,
  }) async {
    if (_box == null) {
      throw CacheException('Cache not initialized. Call init() first.');
    }

    try {
      final mapping = CachedMapping(
        primaryProviderId: primaryProviderId,
        primaryMediaId: primaryMediaId,
        providerMappings: providerMappings,
        cachedAt: DateTime.now(),
      );

      final key = mapping.cacheKey;
      final jsonString = jsonEncode(mapping.toJson());

      // Check if adding this entry would exceed cache size
      final currentSize = await getCacheSize();
      final entrySize = jsonString.length;

      if (currentSize + entrySize > _maxCacheSizeBytes) {
        await _evictLRU(entrySize);
      }

      await _box!.put(key, jsonString);
      _accessTimes[key] = DateTime.now();
      await _saveAccessTimes();

      Logger.debug(
        'Cache STORE: Stored mapping for $key (${providerMappings.length} providers, ${entrySize} bytes)',
        tag: 'ProviderCache',
      );
    } catch (e) {
      Logger.error('Failed to store cache mapping', error: e);
      throw CacheException('Failed to store mapping: $e');
    }
  }

  /// Retrieve cached mappings
  Future<Map<String, String>?> getMappings({
    required String primaryProviderId,
    required String primaryMediaId,
  }) async {
    if (_box == null) {
      throw CacheException('Cache not initialized. Call init() first.');
    }

    try {
      final key = '${primaryProviderId}_$primaryMediaId';
      final jsonString = _box!.get(key);

      if (jsonString == null) {
        return null;
      }

      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final mapping = CachedMapping.fromJson(json);

      // Check if expired
      if (isExpired(mapping.cachedAt)) {
        final age = DateTime.now().difference(mapping.cachedAt).inDays;
        Logger.info(
          'Cache EXPIRED: Entry for $key is $age days old (TTL: $_ttlDays days)',
          tag: 'ProviderCache',
        );
        await _box!.delete(key);
        _accessTimes.remove(key);
        await _saveAccessTimes();
        return null;
      }

      // Update access time for LRU
      _accessTimes[key] = DateTime.now();
      await _saveAccessTimes();

      final age = DateTime.now().difference(mapping.cachedAt).inDays;
      Logger.info(
        'Cache HIT: Retrieved mapping for $key (${mapping.providerMappings.length} providers, age: $age days)',
        tag: 'ProviderCache',
      );
      return mapping.providerMappings;
    } catch (e) {
      Logger.error('Failed to retrieve cache mapping', error: e);
      // Return null on error to allow fallback to fresh search
      return null;
    }
  }

  /// Check if mapping is expired (> 7 days)
  bool isExpired(DateTime cachedAt) {
    final now = DateTime.now();
    final difference = now.difference(cachedAt);
    return difference.inDays > _ttlDays;
  }

  /// Clear expired entries
  Future<void> clearExpired() async {
    if (_box == null) {
      throw CacheException('Cache not initialized. Call init() first.');
    }

    try {
      final keysToDelete = <String>[];

      for (final key in _box!.keys) {
        final jsonString = _box!.get(key);
        if (jsonString == null || key == _metadataKey) continue;

        try {
          final json = jsonDecode(jsonString) as Map<String, dynamic>;
          final mapping = CachedMapping.fromJson(json);

          if (isExpired(mapping.cachedAt)) {
            keysToDelete.add(key);
          }
        } catch (e) {
          // If we can't parse it, delete it
          keysToDelete.add(key);
        }
      }

      for (final key in keysToDelete) {
        await _box!.delete(key);
        _accessTimes.remove(key);
      }

      await _saveAccessTimes();
      Logger.info(
        'Cache CLEANUP: Cleared ${keysToDelete.length} expired entries',
        tag: 'ProviderCache',
      );
    } catch (e) {
      Logger.error('Failed to clear expired entries', error: e);
      throw CacheException('Failed to clear expired entries: $e');
    }
  }

  /// Clear all cache
  Future<void> clearAll() async {
    if (_box == null) {
      throw CacheException('Cache not initialized. Call init() first.');
    }

    try {
      final entryCount = _box!.length;
      await _box!.clear();
      _accessTimes.clear();
      Logger.info(
        'Cache CLEAR: Cleared all $entryCount cache entries',
        tag: 'ProviderCache',
      );
    } catch (e) {
      Logger.error('Failed to clear cache', error: e);
      throw CacheException('Failed to clear cache: $e');
    }
  }

  /// Get cache size in bytes
  Future<int> getCacheSize() async {
    if (_box == null) {
      throw CacheException('Cache not initialized. Call init() first.');
    }

    try {
      int totalSize = 0;

      for (final key in _box!.keys) {
        if (key == _metadataKey) continue;

        final value = _box!.get(key);
        if (value != null) {
          totalSize += value.length;
        }
      }

      return totalSize;
    } catch (e) {
      Logger.error('Failed to calculate cache size', error: e);
      return 0;
    }
  }

  /// Get number of cached entries
  Future<int> getEntryCount() async {
    if (_box == null) {
      throw CacheException('Cache not initialized. Call init() first.');
    }

    try {
      // Subtract 1 for metadata key if it exists
      final count = _box!.keys.length;
      return _box!.containsKey(_metadataKey) ? count - 1 : count;
    } catch (e) {
      Logger.error('Failed to get entry count', error: e);
      return 0;
    }
  }

  /// Evict least recently used entries to free up space
  Future<void> _evictLRU(int requiredSpace) async {
    final currentSize = await getCacheSize();
    Logger.info(
      'Cache LRU EVICTION: Size limit reached (${currentSize} bytes), evicting entries to free ${requiredSpace} bytes',
      tag: 'ProviderCache',
    );

    // Sort entries by access time (oldest first)
    final sortedEntries = _accessTimes.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    int freedSpace = 0;
    final keysToDelete = <String>[];

    for (final entry in sortedEntries) {
      final key = entry.key;
      final value = _box!.get(key);

      if (value != null) {
        freedSpace += value.length;
        keysToDelete.add(key);

        // Check if we've freed enough space
        final currentSize = await getCacheSize();
        if (currentSize - freedSpace + requiredSpace <= _maxCacheSizeBytes) {
          break;
        }
      }
    }

    // Delete the selected entries
    for (final key in keysToDelete) {
      await _box!.delete(key);
      _accessTimes.remove(key);
    }

    await _saveAccessTimes();
    final newSize = await getCacheSize();
    Logger.info(
      'Cache LRU EVICTION: Evicted ${keysToDelete.length} entries, freed $freedSpace bytes (new size: $newSize bytes)',
      tag: 'ProviderCache',
    );
  }

  /// Load access times from metadata
  Future<void> _loadAccessTimes() async {
    try {
      final metadataJson = _box!.get(_metadataKey);
      if (metadataJson != null) {
        final metadata = jsonDecode(metadataJson) as Map<String, dynamic>;
        final accessTimesData =
            metadata['accessTimes'] as Map<String, dynamic>?;

        if (accessTimesData != null) {
          _accessTimes.clear();
          accessTimesData.forEach((key, value) {
            _accessTimes[key] = DateTime.parse(value as String);
          });
        }
      }
    } catch (e) {
      Logger.error('Failed to load access times', error: e);
      // Continue with empty access times
    }
  }

  /// Save access times to metadata
  Future<void> _saveAccessTimes() async {
    try {
      final accessTimesData = <String, String>{};
      _accessTimes.forEach((key, value) {
        accessTimesData[key] = value.toIso8601String();
      });

      final metadata = {'accessTimes': accessTimesData};

      await _box!.put(_metadataKey, jsonEncode(metadata));
    } catch (e) {
      Logger.error('Failed to save access times', error: e);
      // Non-critical error, continue
    }
  }

  /// Close the cache
  Future<void> close() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
      _box = null;
      _accessTimes.clear();
    }
  }
}
