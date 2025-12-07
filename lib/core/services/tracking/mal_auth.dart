import 'dart:convert';

/// MyAnimeList authentication service following AnymeX pattern
/// Handles OAuth2 with PKCE flow and token management for MyAnimeList
///
/// CREDIT: Based on AnymeX's authentication pattern using FlutterWebAuth2
/// and GetX state management with Hive storage
import 'dart:math';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:crypto/crypto.dart';
import '../../utils/logger.dart';
import '../../domain/entities/media_entity.dart';
import '../tracking/tracking_service_interface.dart';

class MalAuth extends GetxController {
  RxBool isLoggedIn = false.obs;
  Rx<TrackingUserProfile> profileData = TrackingUserProfile(
    id: '',
    username: '',
  ).obs;

  RxList<TrackingMediaItem> animeList = <TrackingMediaItem>[].obs;
  RxList<TrackingMediaItem> mangaList = <TrackingMediaItem>[].obs;

  late final Box storage;
  String? _lastCodeVerifier;
  String? _accessToken;
  String? _refreshToken;
  DateTime? _tokenExpiry;

  MalAuth() {
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

  bool get isAuthenticated => _accessToken != null && !_isTokenExpired();

  Future<void> tryAutoLogin() async {
    isLoggedIn.value = false;
    final token = await storage.get('mal_auth_token');
    final refreshToken = await storage.get('mal_refresh_token');
    final expiryStr = await storage.get('mal_token_expiry');

    if (token != null && refreshToken != null && expiryStr != null) {
      _accessToken = token;
      _refreshToken = refreshToken;
      _tokenExpiry = DateTime.parse(expiryStr);

      if (!isAuthenticated) {
        // Try to refresh token
        final refreshed = await _refreshAccessToken();
        if (refreshed) {
          await fetchUserProfile();
          await fetchUserAnimeList();
          await fetchUserMangaList();
        }
      } else {
        await fetchUserProfile();
        await fetchUserAnimeList();
        await fetchUserMangaList();
      }
    }
  }

  Future<void> login() async {
    String clientId = dotenv.env['MAL_CLIENT_ID'] ?? '';
    String redirectUri = dotenv.env['MAL_CALLBACK_SCHEME'] ?? '';

    // Validate required environment variables
    if (clientId.isEmpty || redirectUri.isEmpty) {
      Logger.error('MAL login failed: Missing required environment variables');
      throw Exception(
        'MyAnimeList authentication not configured. Please check your environment variables.',
      );
    }

    // Generate PKCE values (following AnymeX pattern)
    final secureRandom = Random.secure();
    final codeVerifierBytes = List<int>.generate(
      96,
      (_) => secureRandom.nextInt(256),
    );

    final codeVerifier = base64UrlEncode(
      codeVerifierBytes,
    ).replaceAll('=', '').replaceAll('+', '-').replaceAll('/', '_');

    final codeChallenge = base64UrlEncode(
      codeVerifierBytes,
    ).replaceAll('=', '').replaceAll('+', '-').replaceAll('/', '_');

    // Store code verifier for token exchange
    await storage.put('mal_code_verifier', codeVerifier);

    // Also store it in memory as backup
    _lastCodeVerifier = codeVerifier;
    Logger.info(
      'MAL generated code verifier (first 20): ${codeVerifier.substring(0, 20)}',
    );

    final authUrl = Uri.parse('https://myanimelist.net/v1/oauth2/authorize')
        .replace(
          queryParameters: {
            'response_type': 'code',
            'client_id': clientId,
            'code_challenge': codeChallenge,
            'state': 'mal_auth_${DateTime.now().millisecondsSinceEpoch}',
          },
        );

    Logger.info('MAL authorization URL: ${authUrl.toString()}');

    try {
      final result = await FlutterWebAuth2.authenticate(
        url: authUrl.toString(),
        callbackUrlScheme: 'aniya',
      );

      Logger.info('MAL callback URL: $result');

      final code = Uri.parse(result).queryParameters['code'];
      if (code != null && code.isNotEmpty) {
        Logger.info("MAL authorization code received");
        Logger.info(
          "MAL authorization code (first 50 chars): ${code.substring(0, code.length > 50 ? 50 : code.length)}",
        );

        // Extract the actual callback URI from the result
        final actualCallbackUri = Uri.parse(result);
        final actualRedirectUri =
            '${actualCallbackUri.scheme}://${actualCallbackUri.host}${actualCallbackUri.path}';

        Logger.info(
          'MAL actual redirect URI from callback: $actualRedirectUri',
        );
        Logger.info('MAL expected redirect URI: $redirectUri');

        // Use the same redirect URI that was sent in the auth request
        await _exchangeCodeForToken(code, clientId, redirectUri);
      } else {
        Logger.error('MAL login failed: No authorization code received');
        throw Exception(
          'Authorization failed: No code received from MyAnimeList',
        );
      }
    } catch (e) {
      Logger.error('Error during MAL login', error: e);
      throw Exception('MyAnimeList login failed: ${e.toString()}');
    }
  }

  Future<void> _exchangeCodeForToken(
    String code,
    String clientId,
    String redirectUri,
  ) async {
    // Try to get code verifier from storage first
    var codeVerifier = await storage.get('mal_code_verifier');

    // If not in storage, try the in-memory backup
    if (codeVerifier == null && _lastCodeVerifier != null) {
      codeVerifier = _lastCodeVerifier;
      Logger.warning('MAL: Using in-memory code verifier as fallback');
    }

    if (codeVerifier == null) {
      throw Exception('No code verifier available');
    }
    Logger.info(
      'MAL code verifier (first 20 chars): ${codeVerifier.substring(0, codeVerifier.length > 20 ? 20 : codeVerifier.length)}',
    );

    final clientSecret = dotenv.env['MAL_CLIENT_SECRET'] ?? '';

    try {
      final requestBody = {
        'client_id': clientId,
        'client_secret': clientSecret,
        'grant_type': 'authorization_code',
        'code': code,
        'code_verifier': codeVerifier,
      };

      Logger.info('MAL token exchange request: $requestBody');

      final response = await http.post(
        Uri.parse('https://myanimelist.net/v1/oauth2/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: requestBody.entries
            .map(
              (e) =>
                  '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}',
            )
            .join('&'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'];

        // Calculate expiry time
        final expiresIn =
            data['expires_in'] as int? ?? 2415600; // Default to ~1 month
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));

        // Store tokens securely
        await storage.put('mal_auth_token', _accessToken);
        await storage.put('mal_refresh_token', _refreshToken);
        await storage.put('mal_token_expiry', _tokenExpiry!.toIso8601String());

        // Clean up the code verifier
        await storage.delete('mal_code_verifier');
        _lastCodeVerifier = null;

        Logger.info('MAL token stored successfully');

        // Fetch user data after successful authentication
        await fetchUserProfile();
        await fetchUserAnimeList();
        await fetchUserMangaList();
        isLoggedIn.value = true;
      } else {
        Logger.error('MAL token exchange response: ${response.body}');
        final errorData = json.decode(response.body);
        final errorMessage =
            errorData['error_description'] ??
            errorData['error'] ??
            'Unknown error';
        Logger.error(
          'MAL token exchange failed: ${response.statusCode} - $errorMessage',
        );
        Logger.error('MAL token exchange failed');
        throw Exception('Failed to exchange code for token: $errorMessage');
      }
    } catch (e) {
      if (e is FormatException) {
        Logger.error(
          'MAL token exchange failed: Invalid JSON response',
          error: e,
        );
        throw Exception('Invalid response from MyAnimeList server');
      } else if (e is http.ClientException) {
        Logger.error('MAL token exchange failed: Network error', error: e);
        throw Exception('Network error during authentication');
      } else {
        Logger.error('MAL token exchange failed', error: e);
        rethrow;
      }
    }
  }

  Future<bool> _refreshAccessToken() async {
    try {
      if (_refreshToken == null) {
        Logger.error('No refresh token available');
        return false;
      }

      String clientId = dotenv.env['MAL_CLIENT_ID'] ?? '';

      final response = await http.post(
        Uri.parse('https://myanimelist.net/v1/oauth2/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': clientId,
          'grant_type': 'refresh_token',
          'refresh_token': _refreshToken!,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'];

        final expiresIn = data['expires_in'] as int? ?? 2415600;
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));

        // Update stored tokens
        await storage.put('mal_auth_token', _accessToken);
        await storage.put('mal_refresh_token', _refreshToken);
        await storage.put('mal_token_expiry', _tokenExpiry!.toIso8601String());

        Logger.info('MAL token refreshed successfully');
        return true;
      } else {
        Logger.error('Failed to refresh MAL token', error: response.body);
        return false;
      }
    } catch (e) {
      Logger.error('MAL token refresh failed', error: e);
      return false;
    }
  }

  bool _isTokenExpired() {
    return _tokenExpiry?.isBefore(DateTime.now()) ?? true;
  }

  Future<Map<String, dynamic>?> _makeAuthenticatedRequest(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    final token = await storage.get('mal_auth_token');
    Logger.info('MAL: Auth check - token exists: ${token != null}');
    if (token != null) {
      Logger.info('MAL: Token expires at: ${await storage.get('mal_token_expiry')}');
    }

    if (!isAuthenticated) {
      Logger.warning('MAL: Not authenticated - isAuthenticated flag is false');
      return null;
    }

    // Refresh token if needed
    if (_isTokenExpired()) {
      final refreshed = await _refreshAccessToken();
      if (!refreshed) {
        Logger.error('Failed to refresh MAL token');
        return null;
      }
    }

    final uri = Uri.parse(
      'https://api.myanimelist.net/v2$endpoint',
    ).replace(queryParameters: queryParams);
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $_accessToken'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      // Token might be invalid, try refreshing
      final refreshed = await _refreshAccessToken();
      if (refreshed) {
        // Retry the request
        final retryResponse = await http.get(
          uri,
          headers: {'Authorization': 'Bearer $_accessToken'},
        );
        if (retryResponse.statusCode == 200) {
          return jsonDecode(retryResponse.body);
        }
      }
    }

    Logger.error(
      'MAL API request failed',
      error: 'Status: ${response.statusCode}, Body: ${response.body}',
    );
    return null;
  }

  Future<void> fetchUserProfile() async {
    try {
      final data = await _makeAuthenticatedRequest('/users/@me');
      if (data != null) {
        profileData.value = TrackingUserProfile(
          id: data['id']?.toString() ?? '',
          username: data['name']?.toString() ?? '',
          avatar: data['picture']?.toString(),
        );
        isLoggedIn.value = true;
      }
    } catch (e) {
      Logger.info('Error fetching MAL profile: $e');
    }
  }

  Future<void> fetchUserAnimeList() async {
    try {
      final data = await _makeAuthenticatedRequest(
        '/users/@me/animelist',
        queryParams: {'fields': 'list_status', 'limit': '100'},
      );

      if (data != null && data['data'] != null) {
        final animeItems = data['data'] as List<dynamic>;
        animeList.clear();

        for (final item in animeItems) {
          final node = item['node'];
          final listStatus = item['list_status'];

          TrackingStatus? status;
          switch (listStatus['status']) {
            case 'watching':
              status = TrackingStatus.watching;
              break;
            case 'completed':
              status = TrackingStatus.completed;
              break;
            case 'on_hold':
              status = TrackingStatus.onHold;
              break;
            case 'dropped':
              status = TrackingStatus.dropped;
              break;
            case 'plan_to_watch':
              status = TrackingStatus.planning;
              break;
          }

          animeList.add(
            TrackingMediaItem(
              id: node['id'].toString(),
              title: node['title']?.toString() ?? 'Unknown Title',
              mediaType: MediaType.anime,
              coverImage: node['main_picture']?['large']?.toString(),
              status: status,
              rating: listStatus['score']?.toDouble(),
              episodesWatched: listStatus['num_episodes_watched'],
              serviceIds: {'mal': node['id'].toString()},
            ),
          );
        }
      }
    } catch (e) {
      Logger.info('Error fetching MAL anime list: $e');
    }
  }

  Future<void> fetchUserMangaList() async {
    try {
      final data = await _makeAuthenticatedRequest(
        '/users/@me/mangalist',
        queryParams: {'fields': 'list_status', 'limit': '100'},
      );

      if (data != null && data['data'] != null) {
        final mangaItems = data['data'] as List<dynamic>;
        mangaList.clear();

        for (final item in mangaItems) {
          final node = item['node'];
          final listStatus = item['list_status'];

          TrackingStatus? status;
          switch (listStatus['status']) {
            case 'reading':
              status = TrackingStatus.watching;
              break;
            case 'completed':
              status = TrackingStatus.completed;
              break;
            case 'on_hold':
              status = TrackingStatus.onHold;
              break;
            case 'dropped':
              status = TrackingStatus.dropped;
              break;
            case 'plan_to_read':
              status = TrackingStatus.planning;
              break;
          }

          mangaList.add(
            TrackingMediaItem(
              id: node['id'].toString(),
              title: node['title']?.toString() ?? 'Unknown Title',
              mediaType: MediaType.manga,
              coverImage: node['main_picture']?['large']?.toString(),
              status: status,
              rating: listStatus['score']?.toDouble(),
              chaptersRead: listStatus['num_chapters_read'],
              serviceIds: {'mal': node['id'].toString()},
            ),
          );
        }
      }
    } catch (e) {
      Logger.info('Error fetching MAL manga list: $e');
    }
  }

  Future<String?> searchMediaByTitle(String title, bool isAnime) async {
    try {
      final endpoint = isAnime ? '/anime' : '/manga';
      final response = await http.get(
        Uri.parse(
          'https://api.myanimelist.net/v2$endpoint',
        ).replace(queryParameters: {'q': title, 'limit': '10'}),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['data'] as List?;
        if (results != null && results.isNotEmpty) {
          // Return the ID of the first result
          return results[0]['node']['id'].toString();
        }
      }
      return null;
    } catch (e) {
      Logger.info('Error searching MAL: $e');
      return null;
    }
  }

  Future<bool> updateListEntry(
    String mediaId, {
    TrackingStatus? status,
    int? progress,
    double? score,
    bool isAnime = true,
  }) async {
    try {
      String endpoint;
      Map<String, String> body = {};

      if (isAnime) {
        endpoint = '/anime/$mediaId/my_list_status';
        if (progress != null) {
          body['num_watched_episodes'] = progress.toString();
        }
      } else {
        endpoint = '/manga/$mediaId/my_list_status';
        if (progress != null) body['num_chapters_read'] = progress.toString();
      }

      if (status != null) {
        String malStatus;
        switch (status) {
          case TrackingStatus.watching:
            malStatus = isAnime ? 'watching' : 'reading';
            break;
          case TrackingStatus.completed:
            malStatus = 'completed';
            break;
          case TrackingStatus.onHold:
            malStatus = 'on_hold';
            break;
          case TrackingStatus.dropped:
            malStatus = 'dropped';
            break;
          case TrackingStatus.planning:
            malStatus = isAnime ? 'plan_to_watch' : 'plan_to_read';
            break;
        }
        body['status'] = malStatus;
      }

      if (score != null) {
        body['score'] = score.toString();
      }

      Logger.info('MAL API request: PUT $endpoint');
      Logger.info('MAL API body: $body');

      final response = await http.put(
        Uri.parse('https://api.myanimelist.net/v2$endpoint'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body.entries
            .map(
              (e) =>
                  '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}',
            )
            .join('&'),
      );

      Logger.info('MAL API response status: ${response.statusCode}');
      if (response.statusCode != 200) {
        Logger.error('MAL API error response: ${response.body}');
      } else {
        Logger.info('MAL API success response: ${response.body}');
      }

      return response.statusCode == 200;
    } catch (e) {
      Logger.info('Error updating MAL list entry: $e');
      return false;
    }
  }

  Future<void> logout() async {
    await storage.delete('mal_auth_token');
    await storage.delete('mal_refresh_token');
    await storage.delete('mal_token_expiry');
    await storage.delete('mal_code_verifier');

    _accessToken = null;
    _refreshToken = null;
    _tokenExpiry = null;
    isLoggedIn.value = false;
    profileData.value = TrackingUserProfile(id: '', username: '');
    animeList.clear();
    mangaList.clear();
  }

  // PKCE helper methods
  String _generateCodeVerifier() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64UrlEncode(values).replaceAll('=', '');
  }

  String _generateCodeChallenge(String codeVerifier) {
    // For 'S256' method, challenge is BASE64URL-ENCODE(SHA256(ASCII(code_verifier)))
    final bytes = utf8.encode(codeVerifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  /// Search for anime/manga on MyAnimeList
  Future<List<TrackingSearchResult>> searchMedia(
    String query,
    MediaType mediaType,
  ) async {
    if (!isAuthenticated) {
      Logger.warning('MAL: Not authenticated for search');
      return [];
    }

    Logger.info('MAL: Searching for "$query" (${mediaType.name})');

    final fields = 'id,title,main_picture,start_date,media_type';
    final endpoint = mediaType == MediaType.anime ? '/anime' : '/manga';

    final data = await _makeAuthenticatedRequest(
      endpoint,
      queryParams: {'q': query, 'fields': fields, 'limit': '20'},
    );

    if (data != null && data['data'] != null) {
      final items = data['data'] as List<dynamic>;
      Logger.info('MAL: Found ${items.length} results');
      return items.map((item) {
        final node = item['node'];
        return TrackingSearchResult(
          id: node['id'].toString(),
          title: node['title']?.toString() ?? 'Unknown Title',
          coverImage: node['main_picture']?['large']?.toString(),
          mediaType: mediaType,
          year: node['start_date'] != null
              ? int.tryParse(node['start_date'].toString().split('-')[0])
              : null,
          serviceIds: {'mal': node['id'].toString()},
        );
      }).toList();
    }
    Logger.warning('MAL: No results found or data was null');
    return [];
  }

  /// Get specific anime/manga list entry for progress tracking
  Future<Map<String, dynamic>?> getMediaListEntry(
    String mediaId,
    bool isAnime,
  ) async {
    if (!isAuthenticated) return null;

    final endpoint = isAnime ? '/anime/$mediaId' : '/manga/$mediaId';
    final fields = 'id,title,num_episodes,num_chapters,my_list_status';

    final data = await _makeAuthenticatedRequest(
      endpoint,
      queryParams: {'fields': fields},
    );

    return data?['my_list_status'];
  }
}
