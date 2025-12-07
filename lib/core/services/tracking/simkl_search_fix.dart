/// Enhanced Simkl search implementation that dynamically finds IDs
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../utils/logger.dart';
import '../../domain/entities/entities.dart';
import 'tracking_service_interface.dart';

class SimklSearchHelper {
  /// Search for media on Simkl and return the best match with cross-service IDs
  static Future<TrackingSearchResult?> searchSimklWithCrossIds(
    String query,
    MediaType mediaType,
    String accessToken,
  ) async {
    Logger.info('SimklSearchHelper: Searching for "$query"');

    // Try multiple search approaches
    final searchTerms = [
      query.toLowerCase(),
      query,
      // Remove common suffixes/prefixes
      query
          .replaceAll(RegExp(r'\s*(?:\(.*?\)|\[.*?\]|\{.*?\})\s*$'), '')
          .toLowerCase(),
    ];

    for (final searchTerm in searchTerms) {
      // Try different endpoint formats
      final endpoints = [
        // Format 1: Search with query parameter
        () => _searchWithQueryParam(searchTerm, mediaType, accessToken),
        // Format 2: Search in path
        () => _searchWithPath(searchTerm, mediaType, accessToken),
        // Format 3: Search without type filter
        () => _searchWithoutType(searchTerm, accessToken),
      ];

      for (final endpointFunc in endpoints) {
        try {
          final result = await endpointFunc();
          if (result != null) {
            Logger.info(
              'SimklSearchHelper: Found match: "${result.title}" with ID ${result.id}',
            );
            return result;
          }
        } catch (e) {
          Logger.warning('SimklSearchHelper: Endpoint failed: $e');
        }
      }
    }

    Logger.warning('SimklSearchHelper: No results found for "$query"');
    return null;
  }

  static Future<TrackingSearchResult?> _searchWithQueryParam(
    String query,
    MediaType mediaType,
    String accessToken,
  ) async {
    final url = Uri.parse('https://api.simkl.com/search').replace(
      queryParameters: {
        'q': query,
        'type': mediaType == MediaType.anime ? 'anime' : 'manga',
      },
    );

    return await _makeSearchRequest(url, accessToken);
  }

  static Future<TrackingSearchResult?> _searchWithPath(
    String query,
    MediaType mediaType,
    String accessToken,
  ) async {
    final url =
        Uri.parse(
          'https://api.simkl.com/search/${Uri.encodeComponent(query)}',
        ).replace(
          queryParameters: {
            'type': mediaType == MediaType.anime ? 'anime' : 'manga',
          },
        );

    return await _makeSearchRequest(url, accessToken);
  }

  static Future<TrackingSearchResult?> _searchWithoutType(
    String query,
    String accessToken,
  ) async {
    final url = Uri.parse(
      'https://api.simkl.com/search',
    ).replace(queryParameters: {'q': query});

    return await _makeSearchRequest(url, accessToken);
  }

  static Future<TrackingSearchResult?> _makeSearchRequest(
    Uri url,
    String accessToken,
  ) async {
    Logger.info('SimklSearchHelper: Trying URL: $url');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'simkl-api-key': dotenv.env['SIMKL_CLIENT_ID'] ?? '',
        'Content-Type': 'application/json',
      },
    );

    Logger.info('SimklSearchHelper: Response status: ${response.statusCode}');

    if (response.statusCode == 200) {
      if (response.body.isEmpty || response.body == 'null') {
        Logger.warning('SimklSearchHelper: Empty response');
        return null;
      }

      try {
        final data = json.decode(response.body);
        Logger.info('SimklSearchHelper: Response type: ${data.runtimeType}');

        // Handle different response formats
        List<dynamic> results = [];

        if (data is List) {
          results = data;
        } else if (data is Map) {
          // Check for different possible response structures
          if (data['data'] is List) {
            results = data['data'];
          } else if (data['anime'] is List) {
            results = data['anime'];
          } else if (data['shows'] is List) {
            results = data['shows'];
          } else if (data['results'] is List) {
            results = data['results'];
          }
        }

        Logger.info('SimklSearchHelper: Found ${results.length} results');

        if (results.isNotEmpty) {
          // Return the first result
          final item = results.first;

          // Extract title from various possible fields
          String title = '';
          if (item['title'] != null) {
            title = item['title'].toString();
          } else if (item['name'] != null) {
            title = item['name'].toString();
          }

          // Extract IDs
          final ids = item['ids'] as Map<String, dynamic>? ?? {};

          return TrackingSearchResult(
            id: ids['simkl_id']?.toString() ?? item['id']?.toString() ?? '',
            title: title,
            alternativeTitles: {
              'english': item['title']?.toString(),
              'romaji': item['title_romanji']?.toString(),
              'japanese': item['title_jp']?.toString(),
            },
            coverImage: item['poster']?.toString() ?? item['image']?.toString(),
            mediaType: MediaType.anime, // Default to anime for Simkl
            year: item['year'] != null
                ? int.tryParse(item['year'].toString())
                : null,
            serviceIds: {
              'simkl':
                  ids['simkl_id']?.toString() ?? item['id']?.toString() ?? '',
              'mal': ids['mal']?.toString(),
              'anilist': ids['anilist']?.toString(),
            },
          );
        }
      } catch (e) {
        Logger.error('SimklSearchHelper: Parse error: $e');
        Logger.error('SimklSearchHelper: Response body: ${response.body}');
      }
    } else {
      Logger.error(
        'SimklSearchHelper: HTTP ${response.statusCode}: ${response.body}',
      );
    }

    return null;
  }

  /// Search Simkl API using a more comprehensive approach
  static Future<Map<String, String>?> findSimklIdByCrossService(
    MediaEntity media,
    String accessToken,
  ) async {
    Logger.info('SimklSearchHelper: Looking for Simkl ID for "${media.title}"');

    // First try direct search
    final result = await searchSimklWithCrossIds(
      media.title,
      media.type,
      accessToken,
    );
    if (result != null) {
      return {
        'simkl': result.id,
        'mal': result.serviceIds['mal'] ?? '',
        'anilist': result.serviceIds['anilist'] ?? '',
      };
    }

    return null;
  }
}
