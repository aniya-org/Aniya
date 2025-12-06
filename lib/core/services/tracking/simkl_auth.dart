/// Simkl authentication service following AnymeX pattern
/// Handles OAuth2 flow and token management for Simkl
///
/// CREDIT: Based on AnymeX's authentication pattern using FlutterWebAuth2
/// and GetX state management with Hive storage
import 'dart:convert';
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
    if (clientId.isEmpty || redirectUri.isEmpty) {
      Logger.error(
        'Simkl login failed: Missing required environment variables',
      );
      throw Exception(
        'Simkl authentication not configured. Please check your environment variables.',
      );
    }

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

      final code = Uri.parse(result).queryParameters['code'];
      if (code != null && code.isNotEmpty) {
        Logger.info("Simkl authorization code received");
        await _exchangeCodeForToken(code, clientId, redirectUri);
      } else {
        Logger.error('Simkl login failed: No authorization code received');
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
        'client_id': clientId,
        'client_secret': clientSecret,
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': redirectUri,
      };

      Logger.info('Simkl token exchange request: $requestBody');

      final response = await http.post(
        Uri.parse('https://api.simkl.com/oauth/token'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

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
        Logger.error('Simkl token exchange response: ${response.body}');
        try {
          final errorData = json.decode(response.body);
          final errorMessage =
              errorData['error_description'] ??
              errorData['error'] ??
              'Unknown error';
          Logger.error(
            'Simkl token exchange failed: ${response.statusCode} - $errorMessage',
          );
        } catch (e) {
          Logger.error('Failed to parse Simkl error response: $e');
          Logger.error('Raw response: ${response.body}');
        }
        Logger.error('Simkl token exchange failed');
        throw Exception('Failed to exchange code for token: json_error');
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
      headers: {'Authorization': 'Bearer $_accessToken'},
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

  Future<String?> searchMedia(String title) async {
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

  Future<bool> updateListEntry(
    String mediaId, {
    TrackingStatus? status,
    int? progress,
    double? score,
  }) async {
    try {
      String endpoint;
      Map<String, dynamic> body = {};

      endpoint = '/sync/add-to-list';

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

      body = {
        'shows': [
          {'simkl': int.parse(mediaId), 'to': simklStatus},
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

      final response = await http.post(
        Uri.parse('https://api.simkl.com$endpoint'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      return response.statusCode == 200;
    } catch (e) {
      Logger.info('Error updating Simkl list entry: $e');
      return false;
    }
  }

  Future<bool> _rateMedia(String mediaId, double rating) async {
    try {
      final endpoint = '/sync/ratings';
      final response = await http.post(
        Uri.parse('https://api.simkl.com$endpoint'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'shows': [
            {'simkl': int.parse(mediaId), 'rating': rating},
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
      final response = await http.post(
        Uri.parse('https://api.simkl.com$endpoint'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'shows': [
            {
              'simkl': int.parse(mediaId),
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
