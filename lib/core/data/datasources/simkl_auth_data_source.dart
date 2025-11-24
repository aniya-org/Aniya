import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../error/exceptions.dart';
import '../../utils/logger.dart';

/// Simkl OAuth2 authentication data source
/// Handles authentication flow for Simkl API
class SimklAuthDataSource {
  late final Dio _dio;
  late final String? _clientId;

  SimklAuthDataSource() {
    _dio = Dio();
    _clientId = dotenv.env['SIMKL_CLIENT_ID'];
    _dio.options.baseUrl = 'https://api.simkl.com';
    if (_clientId != null) {
      _dio.options.queryParameters = {'client_id': _clientId};
    }
  }

  /// Get OAuth2 authorization URL for Simkl
  String getAuthorizationUrl(String redirectUri, {String? state}) {
    if (_clientId == null) {
      throw ServerException('Simkl Client ID not configured');
    }

    return 'https://simkl.com/oauth/authorize?'
        'response_type=code&'
        'client_id=$_clientId&'
        'redirect_uri=${Uri.encodeComponent(redirectUri)}&'
        'scope=basic&'
        'state=${state ?? ''}';
  }

  /// Exchange authorization code for access token
  Future<Map<String, dynamic>> exchangeCodeForToken(
    String code,
    String redirectUri,
  ) async {
    try {
      if (_clientId == null) {
        throw ServerException('Simkl OAuth2 credentials not configured');
      }

      final response = await Dio().post(
        'https://api.simkl.com/oauth/token',
        data: {
          'grant_type': 'authorization_code',
          'client_id': _clientId,
          'client_secret': dotenv.env['SIMKL_CLIENT_SECRET'] ?? '',
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
      Logger.error('Simkl token exchange failed', error: e);
      throw ServerException('Failed to authenticate with Simkl: $e');
    }
  }

  /// Refresh access token
  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    try {
      if (_clientId == null) {
        throw ServerException('Simkl OAuth2 credentials not configured');
      }

      final response = await Dio().post(
        'https://api.simkl.com/oauth/token',
        data: {
          'grant_type': 'refresh_token',
          'client_id': _clientId,
          'client_secret': dotenv.env['SIMKL_CLIENT_SECRET'] ?? '',
          'refresh_token': refreshToken,
        },
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
          headers: {'Accept': 'application/json'},
        ),
      );

      return response.data;
    } catch (e) {
      Logger.error('Simkl token refresh failed', error: e);
      throw ServerException('Failed to refresh Simkl token: $e');
    }
  }

  /// Get user information using access token
  Future<Map<String, dynamic>> getUserInfo(String accessToken) async {
    try {
      final response = await Dio().get(
        'https://api.simkl.com/users/settings',
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'simkl-api-key': _clientId ?? '',
            'Accept': 'application/json',
          },
        ),
      );

      return response.data;
    } catch (e) {
      Logger.error('Simkl user info fetch failed', error: e);
      throw ServerException('Failed to get Simkl user info: $e');
    }
  }
}
