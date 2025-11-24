import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../error/exceptions.dart';
import '../../utils/logger.dart';

/// MyAnimeList OAuth2 authentication data source
/// Handles authentication flow for MAL API
class MalAuthDataSource {
  late final Dio _dio;
  late final String? _clientId;

  MalAuthDataSource() {
    _dio = Dio();
    _clientId = dotenv.env['MAL_CLIENT_ID'];
    _dio.options.baseUrl = 'https://myanimelist.net';
  }

  /// Get OAuth2 authorization URL for MyAnimeList
  String getAuthorizationUrl(String redirectUri, {String? state}) {
    if (_clientId == null) {
      throw ServerException('MAL Client ID not configured');
    }

    return 'https://myanimelist.net/v1/oauth2/authorize?'
        'response_type=code&'
        'client_id=$_clientId&'
        'redirect_uri=${Uri.encodeComponent(redirectUri)}&'
        'code_challenge_method=plain&'
        'state=${state ?? ''}';
  }

  /// Exchange authorization code for access token
  Future<Map<String, dynamic>> exchangeCodeForToken(
    String code,
    String redirectUri, {
    String? codeVerifier,
  }) async {
    try {
      if (_clientId == null) {
        throw ServerException('MAL OAuth2 credentials not configured');
      }

      final response = await Dio().post(
        'https://myanimelist.net/v1/oauth2/token',
        data: {
          'client_id': _clientId,
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': redirectUri,
          if (codeVerifier != null) 'code_verifier': codeVerifier,
        },
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
          headers: {'Accept': 'application/json'},
        ),
      );

      return response.data;
    } catch (e) {
      Logger.error('MAL token exchange failed', error: e);
      throw ServerException('Failed to authenticate with MyAnimeList: $e');
    }
  }

  /// Refresh access token
  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    try {
      if (_clientId == null) {
        throw ServerException('MAL OAuth2 credentials not configured');
      }

      final response = await Dio().post(
        'https://myanimelist.net/v1/oauth2/token',
        data: {
          'client_id': _clientId,
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
        },
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
          headers: {'Accept': 'application/json'},
        ),
      );

      return response.data;
    } catch (e) {
      Logger.error('MAL token refresh failed', error: e);
      throw ServerException('Failed to refresh MAL token: $e');
    }
  }

  /// Get user information using access token
  Future<Map<String, dynamic>> getUserInfo(String accessToken) async {
    try {
      final response = await Dio().get(
        'https://api.myanimelist.net/v2/users/@me',
        queryParameters: {'fields': 'id,name,picture'},
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Accept': 'application/json',
          },
        ),
      );

      return response.data;
    } catch (e) {
      Logger.error('MAL user info fetch failed', error: e);
      throw ServerException('Failed to get MAL user info: $e');
    }
  }
}
