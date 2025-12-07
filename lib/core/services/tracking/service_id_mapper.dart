import 'dart:convert';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/entities/entities.dart';
import '../tracking/tracking_service_interface.dart';
import '../../utils/logger.dart';
import 'simkl_search_fix.dart';

/// Service for mapping and caching IDs across different tracking services
/// Handles cross-service ID resolution and caching
class ServiceIdMapper {
  static const String _boxName = 'service_id_mappings';
  static Box<String>? _cacheBox;
  static const int _cacheExpirationDays = 7;

  /// Initialize the cache box
  static Future<void> initialize() async {
    _cacheBox ??= await Hive.openBox<String>(_boxName);
  }

  /// Get the service-specific ID for a media item
  /// Will search the service if ID not found in cache
  /// [releaseYear] - Optional release year for better matching accuracy
  static Future<String?> getServiceId(
    MediaEntity media,
    TrackingService targetService, {
    required List<TrackingServiceInterface> availableServices,
    int? releaseYear,
  }) async {
    await initialize();

    // Debug: Print authentication status
    Logger.info('ServiceIdMapper: Auth status check:');
    for (final service in availableServices) {
      Logger.info(
        '  ${service.serviceType.name}: authenticated=${service.isAuthenticated}',
      );
    }

    // Check cache first
    final cacheKey = _getCacheKey(media.id, targetService);
    final cachedData = _cacheBox?.get(cacheKey);

    if (cachedData != null) {
      try {
        final cacheEntry = jsonDecode(cachedData);
        final cachedAt = DateTime.parse(cacheEntry['cached_at']);

        // Check if cache is still valid
        if (DateTime.now().difference(cachedAt).inDays < _cacheExpirationDays) {
          Logger.info(
            'ServiceIdMapper: Using cached ID for ${media.title} from $targetService',
          );
          return cacheEntry['service_id'];
        } else {
          // Remove expired entry
          await _cacheBox?.delete(cacheKey);
        }
      } catch (e) {
        Logger.error('ServiceIdMapper: Failed to parse cache entry', error: e);
        await _cacheBox?.delete(cacheKey);
      }
    }

    // Find a service to search with - try in order of preference
    final searchServices = <TrackingServiceInterface>[];

    // 1. Prefer the target service directly (if authenticated)
    final targetServiceInterface = availableServices
        .where((s) => s.isAuthenticated && s.serviceType == targetService)
        .firstOrNull;

    if (targetServiceInterface != null) {
      searchServices.add(targetServiceInterface);
    }

    // 2. Try Simkl (might have cross-service IDs)
    final simklService = availableServices
        .where(
          (s) => s.isAuthenticated && s.serviceType == TrackingService.simkl,
        )
        .firstOrNull;

    if (simklService != null && simklService != targetServiceInterface) {
      searchServices.add(simklService);
    }

    // 3. Add any other authenticated services as fallback
    for (final service in availableServices) {
      if (service.isAuthenticated &&
          !searchServices.contains(service) &&
          service.serviceType != TrackingService.local) {
        searchServices.add(service);
      }
    }

    if (searchServices.isEmpty) {
      Logger.error('ServiceIdMapper: No authenticated services available');
      return null;
    }

    // Try each service in order of preference
    for (final searchService in searchServices) {
      Logger.info(
        'ServiceIdMapper: Trying ${searchService.serviceType} for search',
      );

      final serviceId = await _searchForServiceId(
        media,
        targetService,
        searchService,
        releaseYear: releaseYear,
      );

      if (serviceId != null) {
        // Cache the result if found
        await _cacheServiceId(media.id, targetService, serviceId);
        return serviceId;
      }

      Logger.info(
        'ServiceIdMapper: Search failed on ${searchService.serviceType}, trying next',
      );
    }

    // Return null if no ID found
    Logger.warning(
      'ServiceIdMapper: Could not find ID for ${media.title} on any service',
    );
    return null;
  }

  /// Search for a media item's ID on a specific service
  /// [releaseYear] - Optional release year for better matching accuracy
  static Future<String?> _searchForServiceId(
    MediaEntity media,
    TrackingService targetService,
    TrackingServiceInterface searchService, {
    int? releaseYear,
  }) async {
    Logger.info(
      'ServiceIdMapper: Searching for ${media.title} on $targetService using ${searchService.serviceType}',
    );

    try {
      // Special handling for Simkl
      if (targetService == TrackingService.simkl &&
          searchService.serviceType == TrackingService.simkl) {
        // Use the enhanced Simkl search
        final simklResult = await _searchSimklDirectly(media, searchService);
        if (simklResult != null) {
          Logger.info('ServiceIdMapper: Found Simkl ID: ${simklResult.id}');
          return simklResult.id;
        }
      }

      // If we're searching on the same service, we can use the media's ID directly
      if (searchService.serviceType == targetService) {
        // First, check if the media exists on this service
        final watchlist = await searchService.getWatchlist();
        final exists = watchlist.any(
          (item) =>
              item.id == media.id ||
              item.title.toLowerCase() == media.title.toLowerCase(),
        );

        if (exists) {
          return media.id;
        }

        // If not in watchlist, try searching by title
        Logger.info(
          'ServiceIdMapper: Media not in watchlist, searching by title...',
        );
        final titleResults = await searchService.searchMedia(
          media.title,
          media.type,
        );
        if (titleResults.isNotEmpty) {
          Logger.info(
            'ServiceIdMapper: Found ${titleResults.length} results by title',
          );
          return titleResults.first.id;
        }
      }

      // Search for the media by title
      Logger.info(
        'ServiceIdMapper: Searching "${media.title}" (${media.type}) on ${searchService.serviceType}',
      );

      final searchResults = await searchService.searchMedia(
        media.title,
        media.type,
      );
      Logger.info(
        'ServiceIdMapper: Got ${searchResults.length} results from ${searchService.serviceType}',
      );

      // Try to find the best match
      TrackingSearchResult? bestMatch;

      Logger.info(
        'ServiceIdMapper: Looking for match for "${media.title}" (year: $releaseYear)',
      );

      for (int i = 0; i < searchResults.length; i++) {
        final result = searchResults[i];
        Logger.info(
          'ServiceIdMapper: Result $i: "${result.title}" (year: ${result.year})',
        );

        // Check for exact title match first
        if (result.title.toLowerCase() == media.title.toLowerCase()) {
          // If releaseYear is provided, verify year match
          if (releaseYear != null && result.year != null) {
            if (result.year == releaseYear) {
              Logger.info(
                'ServiceIdMapper: Found exact match with year: "${result.title}" ($releaseYear)',
              );
              bestMatch = result;
              break;
            } else {
              Logger.info(
                'ServiceIdMapper: Title match but year mismatch: "${result.title}" (expected $releaseYear, got ${result.year})',
              );
              // Keep as fallback but continue searching
              if (bestMatch == null) bestMatch = result;
              continue;
            }
          } else {
            Logger.info(
              'ServiceIdMapper: Found exact title match: "${result.title}"',
            );
            bestMatch = result;
            break;
          }
        }

        // Check alternative titles
        if (result.alternativeTitles != null) {
          Logger.info(
            'ServiceIdMapper: Alternative titles: ${result.alternativeTitles}',
          );
          for (final altTitle in result.alternativeTitles!.values) {
            if (altTitle != null &&
                altTitle.toLowerCase() == media.title.toLowerCase()) {
              // If releaseYear is provided, verify year match
              if (releaseYear != null && result.year != null) {
                if (result.year == releaseYear) {
                  Logger.info(
                    'ServiceIdMapper: Found exact match in alternative titles with year: "$altTitle" ($releaseYear)',
                  );
                  bestMatch = result;
                  break;
                }
              } else {
                Logger.info(
                  'ServiceIdMapper: Found exact match in alternative titles: "$altTitle"',
                );
                bestMatch = result;
                break;
              }
            }
          }
          if (bestMatch != null &&
              (releaseYear == null || bestMatch.year == releaseYear))
            break;
        }
      }

      // If no exact match, try fuzzy matching
      if (bestMatch == null && searchResults.isNotEmpty) {
        bestMatch = searchResults.first;
        Logger.info(
          'ServiceIdMapper: No exact match found for "${media.title}", using first result: "${bestMatch.title}" (year: ${bestMatch.year})',
        );
      }

      if (bestMatch != null) {
        // Return the appropriate service ID
        final serviceIds = bestMatch.serviceIds;
        Logger.info('ServiceIdMapper: Best match serviceIds: $serviceIds');
        Logger.info(
          'ServiceIdMapper: Looking for target: ${targetService.name}',
        );

        // First, check if the serviceIds contains the target service ID
        if (serviceIds.containsKey(targetService.name)) {
          final id = serviceIds[targetService.name]?.toString();
          Logger.info('ServiceIdMapper: Found ${targetService.name} ID: $id');
          return id;
        }

        // Check serviceIds for common key names (mal, anilist, simkl)
        final serviceKey = _getServiceKey(targetService);
        Logger.info('ServiceIdMapper: Checking serviceKey: $serviceKey');
        if (serviceIds.containsKey(serviceKey)) {
          final id = serviceIds[serviceKey]?.toString();
          Logger.info(
            'ServiceIdMapper: Found ${targetService.name} ID via serviceKey: $id',
          );
          return id;
        }

        // If the search result is from the target service, use its ID
        if (searchService.serviceType == targetService) {
          Logger.info(
            'ServiceIdMapper: Using search service ID: ${bestMatch.id}',
          );
          return bestMatch.id;
        }

        // Last resort: if we're searching from one service to another, we need to store the mapping
        // but return the ID of the service we're searching on
        Logger.warning(
          'ServiceIdMapper: Found match on ${searchService.serviceType} but need ID for $targetService',
        );
        Logger.warning(
          'ServiceIdMapper: This requires cross-service mapping which is not fully implemented',
        );
        return null;
      }

      Logger.warning(
        'ServiceIdMapper: Could not find ID for "${media.title}" on $targetService',
      );
      return null;
    } catch (e) {
      Logger.error(
        'ServiceIdMapper: Failed to search for "${media.title}" on $targetService',
        error: e,
      );
      return null;
    }
  }

  /// Direct search for Simkl using multiple endpoint formats
  static Future<TrackingSearchResult?> _searchSimklDirectly(
    MediaEntity media,
    TrackingServiceInterface simklService,
  ) async {
    Logger.info('ServiceIdMapper: Direct Simkl search for "${media.title}"');

    // Get the access token from storage
    final getIt = GetIt.instance;
    if (getIt.isRegistered<Box>(instanceName: 'authBox')) {
      final storage = getIt<Box>(instanceName: 'authBox');
      final accessToken = await storage.get('simkl_auth_token');

      if (accessToken == null) {
        Logger.error('ServiceIdMapper: No Simkl access token available');
        return null;
      }

      return await SimklSearchHelper.searchSimklWithCrossIds(
        media.title,
        media.type,
        accessToken,
      );
    }

    Logger.error('ServiceIdMapper: Auth box not available');
    return null;
  }

  /// Cache a service ID mapping
  static Future<void> _cacheServiceId(
    String anilistId,
    TrackingService service,
    String serviceId,
  ) async {
    try {
      final cacheKey = _getCacheKey(anilistId, service);
      final cacheData = {
        'service_id': serviceId,
        'cached_at': DateTime.now().toIso8601String(),
      };

      await _cacheBox?.put(cacheKey, jsonEncode(cacheData));
      Logger.info(
        'ServiceIdMapper: Cached mapping $anilistId -> $serviceId for $service',
      );
    } catch (e) {
      Logger.error('ServiceIdMapper: Failed to cache service ID', error: e);
    }
  }

  /// Generate a cache key for a media item and service
  static String _getCacheKey(String anilistId, TrackingService service) {
    return '${anilistId}_${service.name}';
  }

  /// Get the standard key name for a service in serviceIds map
  static String _getServiceKey(TrackingService service) {
    switch (service) {
      case TrackingService.anilist:
        return 'anilist';
      case TrackingService.mal:
        return 'mal';
      case TrackingService.simkl:
        return 'simkl';
      default:
        return service.name.toLowerCase();
    }
  }

  /// Preload service IDs for a media item on all authenticated services
  static Future<Map<TrackingService, String>> preloadServiceIds(
    MediaEntity media,
    List<TrackingServiceInterface> availableServices,
  ) async {
    final Map<TrackingService, String> serviceIds = {};

    for (final service in availableServices) {
      if (service.isAuthenticated) {
        final serviceId = await getServiceId(
          media,
          service.serviceType,
          availableServices: availableServices,
        );
        if (serviceId != null) {
          serviceIds[service.serviceType] = serviceId;
        }
      }
    }

    return serviceIds;
  }

  /// Clear all cached mappings
  static Future<void> clearCache() async {
    await initialize();
    await _cacheBox?.clear();
    Logger.info('ServiceIdMapper: Cache cleared');
  }

  /// Clear expired entries from cache
  static Future<void> clearExpiredEntries() async {
    await initialize();

    final keys = _cacheBox?.keys.toList() ?? [];
    final now = DateTime.now();

    for (final key in keys) {
      final cachedData = _cacheBox?.get(key);
      if (cachedData != null) {
        try {
          final cacheEntry = jsonDecode(cachedData);
          final cachedAt = DateTime.parse(cacheEntry['cached_at']);

          if (now.difference(cachedAt).inDays >= _cacheExpirationDays) {
            await _cacheBox?.delete(key);
          }
        } catch (e) {
          // Remove invalid entries
          await _cacheBox?.delete(key);
        }
      }
    }

    Logger.info('ServiceIdMapper: Expired entries cleared');
  }

  /// Get cache statistics
  static Future<Map<String, dynamic>> getCacheStats() async {
    await initialize();

    final keys = _cacheBox?.keys.toList() ?? [];
    int expiredCount = 0;
    final now = DateTime.now();

    for (final key in keys) {
      final cachedData = _cacheBox?.get(key);
      if (cachedData != null) {
        try {
          final cacheEntry = jsonDecode(cachedData);
          final cachedAt = DateTime.parse(cacheEntry['cached_at']);

          if (now.difference(cachedAt).inDays >= _cacheExpirationDays) {
            expiredCount++;
          }
        } catch (e) {
          expiredCount++;
        }
      }
    }

    return {
      'total_entries': keys.length,
      'expired_entries': expiredCount,
      'valid_entries': keys.length - expiredCount,
    };
  }
}
