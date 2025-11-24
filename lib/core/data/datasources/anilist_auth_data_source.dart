import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../error/exceptions.dart';
import '../../utils/logger.dart';

/// AniList OAuth2 authentication data source
/// Handles authentication flow for AniList GraphQL API
class AnilistAuthDataSource {
  late final Dio _dio;
  late final String? _clientId;
  late final String? _clientSecret;

  AnilistAuthDataSource() {
    _dio = Dio();
    _clientId = dotenv.env['ANILIST_CLIENT_ID'];
    _clientSecret = dotenv.env['ANILIST_CLIENT_SECRET'];
    _dio.options.baseUrl = 'https://graphql.anilist.co';
  }

  /// Get OAuth2 authorization URL for AniList
  String getAuthorizationUrl(String redirectUri) {
    if (_clientId == null) {
      throw ServerException('AniList Client ID not configured');
    }

    return 'https://anilist.co/api/v2/oauth/authorize?'
        'client_id=$_clientId&'
        'redirect_uri=${Uri.encodeComponent(redirectUri)}&'
        'response_type=code&'
        'scope=&'
        'state=';
  }

  /// Exchange authorization code for access token
  Future<Map<String, dynamic>> exchangeCodeForToken(
    String code,
    String redirectUri,
  ) async {
    try {
      if (_clientId == null || _clientSecret == null) {
        throw ServerException('AniList OAuth2 credentials not configured');
      }

      final response = await Dio().post(
        'https://anilist.co/api/v2/oauth/token',
        data: {
          'grant_type': 'authorization_code',
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'redirect_uri': redirectUri,
          'code': code,
        },
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
          headers: {'Accept': 'application/json'},
        ),
      );

      return response.data;
    } catch (e) {
      Logger.error('AniList token exchange failed', error: e);
      throw ServerException('Failed to authenticate with AniList: $e');
    }
  }

  /// Refresh access token
  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    try {
      if (_clientId == null || _clientSecret == null) {
        throw ServerException('AniList OAuth2 credentials not configured');
      }

      final response = await Dio().post(
        'https://anilist.co/api/v2/oauth/token',
        data: {
          'grant_type': 'refresh_token',
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'refresh_token': refreshToken,
        },
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
          headers: {'Accept': 'application/json'},
        ),
      );

      return response.data;
    } catch (e) {
      Logger.error('AniList token refresh failed', error: e);
      throw ServerException('Failed to refresh AniList token: $e');
    }
  }

  /// Get user information using access token
  Future<Map<String, dynamic>> getUserInfo(String accessToken) async {
    try {
      const query = '''
        query {
          Viewer {
            id
            name
            avatar {
              large
            }
          }
        }
      ''';

      final response = await Dio().post(
        'https://graphql.anilist.co',
        data: {'query': query},
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
      );

      final viewer = response.data['data']['Viewer'];
      if (viewer == null) {
        throw ServerException('Failed to get user info from AniList');
      }

      return viewer;
    } catch (e) {
      Logger.error('AniList user info fetch failed', error: e);
      throw ServerException('Failed to get AniList user info: $e');
    }
  }
}
