import 'dart:convert';

/// Simkl authentication service following AnymeX pattern
/// Handles OAuth2 flow and token management for Simkl
///
/// CREDIT: Based on AnymeX's authentication pattern using FlutterWebAuth2
/// and GetX state management with Hive storage
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import '../../utils/logger.dart';
import '../../domain/entities/media_entity.dart';
import '../tracking/tracking_service_interface.dart';

class SimklAuth extends GetxController {
  RxBool isLoggedIn = false.obs;
  Rx<TrackingUserProfile> profileData = TrackingUserProfile(
    id: '',
    username: '',
  ).obs;
  late final Box storage;

  SimklAuth() {
    // Get the auth box from service locator (opened during DI initialization)
    final getIt = GetIt.instance;
    if (getIt.isRegistered<Box>(instanceName: 'authBox')) {
      storage = getIt<Box>(instanceName: 'authBox');
    } else {
      throw Exception(
        'Auth box not initialized. Make sure Hive boxes are opened before instantiating auth controllers.',
      );
    }
  }

  RxList<TrackingMediaItem> watchlist = <TrackingMediaItem>[].obs;

  String? _accessToken;
  DateTime? _tokenExpiry;

  bool get isAuthenticated => _accessToken != null && !_isTokenExpired();

  Future<void> tryAutoLogin() async {
    isLoggedIn.value = false;
    final token = await storage.get('simkl_auth_token');
    final expiryStr = await storage.get('simkl_token_expiry');

    if (token != null && expiryStr != null) {
      _accessToken = token;
      _tokenExpiry = DateTime.parse(expiryStr);

      if (!isAuthenticated) {
        Logger.warning('Simkl token expired');
        return;
      }

      await fetchUserProfile();
      await fetchWatchlist();
    }
  }

  Future<void> login() async {
    String clientId = dotenv.env['SIMKL_CLIENT_ID'] ?? '';
    String redirectUri = dotenv.env['SIMKL_CALLBACK_SCHEME'] ?? '';

    // Validate required environment variables
    if (clientId.isEmpty) {
      Logger.error(
        'Simkl login failed: Missing SIMKL_CLIENT_ID environment variable',
      );
      throw Exception(
        'Simkl authentication not configured. Please add SIMKL_CLIENT_ID to your .env file.',
      );
    }
    if (redirectUri.isEmpty) {
      Logger.error(
        'Simkl login failed: Missing SIMKL_CALLBACK_SCHEME environment variable',
      );
      throw Exception(
        'Simkl authentication not configured. Please add SIMKL_CALLBACK_SCHEME to your .env file.',
      );
    }

    // Log the client ID (partially masked for security)
    Logger.info(
      'Simkl: Using client_id: ${clientId.substring(0, 8)}... (length: ${clientId.length})',
    );
    Logger.info('Simkl: Using redirect_uri: $redirectUri');

    final authUrl = Uri.parse('https://simkl.com/oauth/authorize').replace(
      queryParameters: {
        'client_id': clientId,
        'response_type': 'code',
        'redirect_uri': redirectUri,
        'scope': 'basic',
        'state': 'simkl_auth_${DateTime.now().millisecondsSinceEpoch}',
      },
    );

    Logger.info('Simkl authorization URL: ${authUrl.toString()}');

    try {
      final result = await FlutterWebAuth2.authenticate(
        url: authUrl.toString(),
        callbackUrlScheme: 'aniya',
      );

      Logger.info('Simkl callback URL received: $result');

      final code = Uri.parse(result).queryParameters['code'];
      if (code != null && code.isNotEmpty) {
        Logger.info(
          "Simkl authorization code received: ${code.substring(0, 10)}...",
        );
        await _exchangeCodeForToken(code, clientId, redirectUri);
      } else {
        Logger.error('Simkl login failed: No authorization code received');
        Logger.error('Full callback result: $result');
        throw Exception('Authorization failed: No code received from Simkl');
      }
    } catch (e) {
      Logger.error('Error during Simkl login', error: e);
      throw Exception('Simkl login failed: ${e.toString()}');
    }
  }

  Future<void> _exchangeCodeForToken(
    String code,
    String clientId,
    String redirectUri,
  ) async {
    String clientSecret = dotenv.env['SIMKL_CLIENT_SECRET'] ?? '';

    try {
      final requestBody = {
        'client_id': clientId.toString(),
        'client_secret': clientSecret.toString(),
        'grant_type': 'authorization_code',
        'code': code.toString(),
        'redirect_uri': redirectUri.toString(),
      };

      Logger.info('Simkl token exchange request: $requestBody');

      final requestBodyJson = json.encode(requestBody);
      Logger.info('Simkl token exchange JSON: $requestBodyJson');

      // Try with JSON but also log the raw request
      Logger.info(
        'Simkl token exchange endpoint: https://api.simkl.com/oauth/token',
      );
      Logger.info('Request headers: Content-Type: application/json');

      final response = await http.post(
        Uri.parse('https://api.simkl.com/oauth/token'),
        headers: {'Content-Type': 'application/json'},
        body: requestBodyJson,
      );

      // Log raw response for debugging
      Logger.info('Simkl response status: ${response.statusCode}');
      Logger.info('Simkl response headers: ${response.headers}');
      Logger.info('Simkl response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _accessToken = data['access_token'];

        // Calculate expiry time
        final expiresIn =
            data['expires_in'] as int? ?? 3600; // Default to 1 hour
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));

        // Store tokens securely
        await storage.put('simkl_auth_token', _accessToken);
        await storage.put(
          'simkl_token_expiry',
          _tokenExpiry!.toIso8601String(),
        );

        Logger.info('Simkl token stored successfully');

        // Fetch user data after successful authentication
        await fetchUserProfile();
        await fetchWatchlist();
        isLoggedIn.value = true;
      } else {
        Logger.error('Simkl token exchange failed: ${response.statusCode}');
        Logger.error('Response body: ${response.body}');

        String errorMessage = 'Authentication failed';

        try {
          final errorData = json.decode(response.body);

          // Handle specific error cases
          if (errorData['error'] == 'client_id_failed') {
            errorMessage =
                'Invalid SIMKL_CLIENT_ID. Please:\n'
                '1. Visit https://simkl.com/oauth/applications\n'
                '2. Create a new app or check your existing app\n'
                '3. Copy the correct Client ID from your app settings\n'
                '4. Update your .env file with the correct value';
          } else if (errorData['error'] == 'invalid_client') {
            errorMessage =
                'Invalid client credentials. Please check your SIMKL_CLIENT_ID and SIMKL_CLIENT_SECRET.\n'
                'Make sure both values match what\'s shown in your Simkl app settings.';
          } else if (errorData['error'] == 'invalid_grant') {
            errorMessage =
                'Authorization code expired or invalid. Please try again.';
          } else {
            errorMessage =
                errorData['error_description'] ??
                errorData['message'] ??
                'Authentication failed';
          }
        } catch (e) {
          Logger.error('Failed to parse Simkl error response: $e');
        }

        throw Exception('Simkl authentication failed: $errorMessage');
      }
    } catch (e) {
      if (e is FormatException) {
        Logger.error(
          'Simkl token exchange failed: Invalid JSON response',
          error: e,
        );
        throw Exception('Invalid response from Simkl server');
      } else if (e is http.ClientException) {
        Logger.error('Simkl token exchange failed: Network error', error: e);
        throw Exception('Network error during authentication');
      } else {
        Logger.error('Simkl token exchange failed', error: e);
        rethrow;
      }
    }
  }

  bool _isTokenExpired() {
    return _tokenExpiry?.isBefore(DateTime.now()) ?? true;
  }

  Future<Map<String, dynamic>?> _makeAuthenticatedRequest(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    if (!isAuthenticated) {
      Logger.warning('Simkl: Not authenticated');
      return null;
    }

    final uri = Uri.parse(
      'https://api.simkl.com$endpoint',
    ).replace(queryParameters: queryParams);
    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $_accessToken',
        'simkl-api-key': dotenv.env['SIMKL_CLIENT_ID'] ?? '',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      Logger.error('Simkl: Authentication failed');
      return null;
    }

    Logger.error(
      'Simkl API request failed',
      error: 'Status: ${response.statusCode}, Body: ${response.body}',
    );
    return null;
  }

  Future<void> fetchUserProfile() async {
    try {
      final data = await _makeAuthenticatedRequest('/users/settings');
      if (data != null) {
        profileData.value = TrackingUserProfile(
          id: data['account']?['id']?.toString() ?? '',
          username: data['user']?['name']?.toString() ?? '',
          avatar: data['user']?['avatar']?.toString(),
        );
        isLoggedIn.value = true;
      }
    } catch (e) {
      Logger.info('Error fetching Simkl profile: $e');
    }
  }

  Future<void> fetchWatchlist() async {
    try {
      final data = await _makeAuthenticatedRequest('/sync/all-items/shows');
      if (data != null && data['shows'] != null) {
        final shows = data['shows'] as List<dynamic>;
        watchlist.clear();

        for (final item in shows) {
          final show = item['show'];
          TrackingStatus? status;

          // Parse status from Simkl
          switch (item['status']) {
            case 'watching':
              status = TrackingStatus.watching;
              break;
            case 'plantowatch':
              status = TrackingStatus.planning;
              break;
            case 'completed':
              status = TrackingStatus.completed;
              break;
            case 'hold':
              status = TrackingStatus.onHold;
              break;
            case 'dropped':
              status = TrackingStatus.dropped;
              break;
          }

          watchlist.add(
            TrackingMediaItem(
              id: show['ids']?['simkl_id']?.toString() ?? '',
              title: show['title']?.toString() ?? 'Unknown Title',
              mediaType: MediaType.anime, // Simkl primarily handles anime
              coverImage: show['poster']?.toString(),
              status: status,
              rating: item['user_rating']?.toDouble(),
              serviceIds: {'simkl': show['ids']?['simkl_id']?.toString() ?? ''},
            ),
          );
        }
      }
    } catch (e) {
      Logger.info('Error fetching Simkl watchlist: $e');
    }
  }

  Future<bool> updateListEntry(
    String mediaId, {
    TrackingStatus? status,
    int? progress,
    double? score,
  }) async {
    if (mediaId.isEmpty) {
      Logger.error('Simkl: Media ID is empty');
      return false;
    }

    final simklId = int.tryParse(mediaId);
    if (simklId == null || simklId == 0) {
      Logger.error('Simkl: Invalid media ID: $mediaId');
      return false;
    }

    Logger.info(
      'Simkl: updateListEntry called with ID: $mediaId (parsed as: $simklId)',
    );

    try {
      // Simkl /sync/add-to-list expects ids.simkl nesting and returns 201 on success.
      // Ref: https://simkl.docs.apiary.io/#reference/sync/add-to-list/add-to-list
      const endpoint = '/sync/add-to-list';

      String simklStatus;
      switch (status ?? TrackingStatus.planning) {
        case TrackingStatus.watching:
          simklStatus = 'watching';
          break;
        case TrackingStatus.completed:
          simklStatus = 'completed';
          break;
        case TrackingStatus.onHold:
          simklStatus = 'hold';
          break;
        case TrackingStatus.dropped:
          simklStatus = 'dropped';
          break;
        case TrackingStatus.planning:
          simklStatus = 'plantowatch';
          break;
      }

      final body = {
        'shows': [
          {
            'ids': {'simkl': simklId},
            'status': simklStatus,
            'to': {'simkl': simklId},
          },
        ],
      };

      if (score != null) {
        // Simkl rating is separate
        await _rateMedia(mediaId, score);
      }

      if (progress != null) {
        // Simkl progress update is separate
        await _updateProgress(mediaId, progress);
      }

      Logger.info(
        'Simkl: Adding to list - mediaId: $mediaId, status: $simklStatus, body: $body',
      );
      final response = await http.post(
        Uri.parse('https://api.simkl.com$endpoint'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'simkl-api-key': dotenv.env['SIMKL_CLIENT_ID'] ?? '',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      Logger.info('Simkl: Add to list response status: ${response.statusCode}');
      if (response.statusCode != 200 && response.statusCode != 201) {
        Logger.error('Simkl: Add to list failed: ${response.body}');
      }

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      Logger.info('Error updating Simkl list entry: $e');
      return false;
    }
  }

  Future<bool> _rateMedia(String mediaId, double rating) async {
    try {
      final endpoint = '/sync/ratings';
      final simklId = int.tryParse(mediaId) ?? 0;
      final response = await http.post(
        Uri.parse('https://api.simkl.com$endpoint'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'simkl-api-key': dotenv.env['SIMKL_CLIENT_ID'] ?? '',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'shows': [
            {
              'ids': {'simkl': simklId},
              'rating': rating,
              'to': {'simkl': simklId},
            },
          ],
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      Logger.info('Error rating Simkl media: $e');
      return false;
    }
  }

  Future<bool> _updateProgress(String mediaId, int progress) async {
    try {
      final endpoint = '/sync/history';
      final simklId = int.tryParse(mediaId) ?? 0;
      final response = await http.post(
        Uri.parse('https://api.simkl.com$endpoint'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'simkl-api-key': dotenv.env['SIMKL_CLIENT_ID'] ?? '',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'shows': [
            {
              'ids': {'simkl': simklId},
              'seasons': [
                {
                  'number': 1,
                  'episodes': [
                    {
                      'number': progress,
                      'watched_at': DateTime.now().toIso8601String(),
                    },
                  ],
                },
              ],
              'to': {'simkl': simklId},
            },
          ],
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      Logger.info('Error updating Simkl progress: $e');
      return false;
    }
  }

  /// Search for anime/manga on Simkl (returns ID for progress updates)
  Future<String?> searchMediaByTitle(String title) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://api.simkl.com/search/${Uri.encodeComponent(title)}',
        ).replace(queryParameters: {'type': 'anime'}),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'simkl-api-key': dotenv.env['SIMKL_CLIENT_ID'] ?? '',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List && data.isNotEmpty) {
          // Return the Simkl ID of the first result
          return data[0]['ids']['simkl_id'].toString();
        }
      }
      return null;
    } catch (e) {
      Logger.info('Error searching Simkl: $e');
      return null;
    }
  }

  /// Search for anime/manga on Simkl (returns full search results)
  Future<List<TrackingSearchResult>> searchMedia(
    String query,
    MediaType mediaType,
  ) async {
    if (!isAuthenticated) {
      Logger.warning('Simkl: Not authenticated for search');
      return [];
    }

    Logger.info('Simkl: Searching for "$query" (${mediaType.name})');

    // Try multiple search variations
    final searchQueries = [
      query.toLowerCase(),
      query,
      // Remove any special characters and try again
      query.replaceAll(RegExp(r'[^\w\s]'), '').toLowerCase(),
      // Try with just the first word for popular anime
      query.split(' ').first.toLowerCase(),
    ];

    TrackingSearchResult? bestMatch;

    outer:
    for (final searchQuery in searchQueries) {
      // Use the same endpoint format as searchMediaByTitle which works
      final searchUrl =
          Uri.parse(
            'https://api.simkl.com/search/${Uri.encodeComponent(searchQuery)}',
          ).replace(
            queryParameters: {
              'type': mediaType == MediaType.anime ? 'anime' : 'manga',
            },
          );

      Logger.info('Simkl: Search URL: $searchUrl');

      final headers = {
        'Authorization': 'Bearer $_accessToken',
        'simkl-api-key': dotenv.env['SIMKL_CLIENT_ID'] ?? '',
      };

      Logger.info('Simkl: Request headers: $headers');

      final response = await http.get(searchUrl, headers: headers);

      Logger.info('Simkl: Response status: ${response.statusCode}');
      Logger.info('Simkl: Response body length: ${response.body.length}');
      Logger.info('Simkl: Response body: "${response.body}"');

      if (response.statusCode == 200) {
        if (response.body.isEmpty || response.body == 'null') {
          Logger.warning('Simkl: Empty or null response body');
          continue;
        }

        dynamic data;
        try {
          data = json.decode(response.body);
          Logger.info('Simkl: Successfully parsed JSON');
          Logger.info('Simkl: Raw response data type: ${data.runtimeType}');

          if (data == null) {
            Logger.warning('Simkl: Parsed data is null');
            continue;
          }

          Logger.info('Simkl: Raw response data: ${data.toString()}');
        } catch (e) {
          Logger.error('Simkl: Failed to parse JSON: $e');
          Logger.error('Simkl: Raw response that failed: ${response.body}');
          continue;
        }

        // Simkl returns a list directly
        if (data is List && data.isNotEmpty) {
          Logger.info('Simkl: Found ${data.length} results for "$searchQuery"');
          // Use the first successful query's results
          bestMatch = data.map((item) {
            final show = item;
            return TrackingSearchResult(
              id: show['ids']?['simkl_id']?.toString() ?? '',
              title: show['title']?.toString() ?? 'Unknown Title',
              coverImage: show['poster']?.toString(),
              mediaType: mediaType,
              year: show['year'] != null
                  ? int.tryParse(show['year'].toString())
                  : null,
              serviceIds: {
                'simkl': show['ids']?['simkl_id']?.toString() ?? '',
                'mal': show['ids']?['mal']?.toString(),
                'anilist': show['ids']?['anilist']?.toString(),
              },
            );
          }).first;
          // Break out of the loop since we found a result
          break outer;
        } else {
          Logger.warning('Simkl: No results in response for "$searchQuery"');
        }
      } else {
        Logger.error(
          'Simkl: HTTP error: ${response.statusCode} - ${response.reasonPhrase}',
        );
        continue;
      }
    }

    if (bestMatch != null) {
      return [bestMatch];
    }

    Logger.warning('Simkl: No results found for any search variation');
    return [];
  }

  /// Get specific anime list entry for progress tracking
  Future<Map<String, dynamic>?> getMediaListEntry(String mediaId) async {
    if (!isAuthenticated) return null;

    try {
      final response = await http.get(
        Uri.parse('https://api.simkl.com/shows/$mediaId'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'simkl-api-key': dotenv.env['SIMKL_CLIENT_ID'] ?? '',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Return the user's progress if available
        return data['user_status'];
      }
      return null;
    } catch (e) {
      Logger.error('Failed to get Simkl media list entry', error: e);
      return null;
    }
  }

  Future<void> logout() async {
    await storage.delete('simkl_auth_token');
    await storage.delete('simkl_token_expiry');

    _accessToken = null;
    _tokenExpiry = null;
    isLoggedIn.value = false;
    profileData.value = TrackingUserProfile(id: '', username: '');
    watchlist.clear();
  }
}
