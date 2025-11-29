import 'dart:convert';
import 'dart:math' show Random;
import 'package:http/http.dart' as http;
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../domain/entities/auth_token.dart';
import '../domain/repositories/tracking_auth_repository.dart';
import '../data/repositories/tracking_auth_repository_impl.dart';
import '../enums/tracking_service.dart';
import '../utils/logger.dart';

class TrackingAuthService {
  final FlutterSecureStorage _secureStorage;
  final TrackingAuthRepository _authRepository;

  TrackingAuthService(
    this._secureStorage, [
    TrackingAuthRepository? authRepository,
  ]) : _authRepository =
           authRepository ??
           TrackingAuthRepositoryImpl(secureStorage: _secureStorage);

  // Credentials loaded from .env
  static String get _anilistClientId => dotenv.env['ANILIST_CLIENT_ID'] ?? '';
  static String get _anilistClientSecret =>
      dotenv.env['ANILIST_CLIENT_SECRET'] ?? '';
  static String get _redirectUri =>
      dotenv.env['ANILIST_REDIRECT_URI'] ?? 'aniya://auth';

  static String get _malClientId => dotenv.env['MAL_CLIENT_ID'] ?? '';
  static String get _malClientSecret => dotenv.env['MAL_CLIENT_SECRET'] ?? '';

  static String get _simklClientId => dotenv.env['SIMKL_CLIENT_ID'] ?? '';
  static String get _simklClientSecret =>
      dotenv.env['SIMKL_CLIENT_SECRET'] ?? '';

  Future<bool> authenticate(TrackingService service) async {
    switch (service) {
      case TrackingService.anilist:
        return _authenticateAnilist();
      case TrackingService.mal:
        return _authenticateMal();
      case TrackingService.simkl:
        return _authenticateSimkl();
      case TrackingService.jikan:
        return true; // Jikan doesn't require authentication
    }
  }

  Future<bool> _authenticateAnilist() async {
    final url =
        'https://anilist.co/api/v2/oauth/authorize?client_id=$_anilistClientId&redirect_uri=$_redirectUri&response_type=code';

    Logger.info(
      'Starting AniList auth with URL: $url',
      tag: 'TrackingAuthService',
    );

    if (_anilistClientId.isEmpty) {
      Logger.error('AniList Client ID is missing', tag: 'TrackingAuthService');
      return false;
    }

    try {
      final result = await FlutterWebAuth2.authenticate(
        url: url,
        callbackUrlScheme: 'aniya',
      );

      Logger.info('Auth result: $result', tag: 'TrackingAuthService');

      final code = Uri.parse(result).queryParameters['code'];
      if (code != null) {
        return await _exchangeAnilistCodeForToken(code);
      } else {
        Logger.error(
          'Auth result did not contain code',
          tag: 'TrackingAuthService',
        );
      }
    } catch (e) {
      Logger.error(
        'Error during AniList login',
        error: e,
        tag: 'TrackingAuthService',
      );
    }
    return false;
  }

  Future<bool> _exchangeAnilistCodeForToken(String code) async {
    try {
      final response = await http.post(
        Uri.parse('https://anilist.co/api/v2/oauth/token'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
        body: {
          'grant_type': 'authorization_code',
          'client_id': _anilistClientId,
          'client_secret': _anilistClientSecret,
          'redirect_uri': _redirectUri,
          'code': code,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;

        // Create AuthToken with proper expiration (AniList tokens last 1 year)
        final authToken =
            TrackingAuthRepositoryImpl.createTokenFromOAuthResponse(
              TrackingService.anilist,
              data,
            );

        // Save using the repository
        await _authRepository.saveToken(TrackingService.anilist, authToken);

        // Also save to legacy key for backward compatibility
        await _secureStorage.write(
          key: 'anilist_token',
          value: data['access_token'],
        );

        Logger.info(
          'AniList authentication successful (expires: ${authToken.expiresAt})',
          tag: 'TrackingAuthService',
        );
        return true;
      } else {
        Logger.error('Failed to exchange code for token: ${response.body}');
        return false;
      }
    } catch (e) {
      Logger.error('Error exchanging code for token', error: e);
      return false;
    }
  }

  Future<bool> _authenticateMal() async {
    if (_malClientId.isEmpty) {
      Logger.error('MAL Client ID is missing', tag: 'TrackingAuthService');
      return false;
    }

    // Generate PKCE code challenge
    final secureRandom = Random.secure();
    final codeVerifierBytes = List<int>.generate(
      96,
      (_) => secureRandom.nextInt(256),
    );
    final codeChallenge = base64UrlEncode(
      codeVerifierBytes,
    ).replaceAll('=', '').replaceAll('+', '-').replaceAll('/', '_');

    final url =
        'https://myanimelist.net/v1/oauth2/authorize?response_type=code&client_id=$_malClientId&code_challenge=$codeChallenge';

    Logger.info('Starting MAL auth with URL: $url', tag: 'TrackingAuthService');

    try {
      final result = await FlutterWebAuth2.authenticate(
        url: url,
        callbackUrlScheme: 'aniya',
      );

      Logger.info('Auth result: $result', tag: 'TrackingAuthService');

      final code = Uri.parse(result).queryParameters['code'];
      if (code != null) {
        return await _exchangeMalCodeForToken(code, codeChallenge);
      } else {
        Logger.error(
          'Auth result did not contain code',
          tag: 'TrackingAuthService',
        );
      }
    } catch (e) {
      Logger.error(
        'Error during MAL login',
        error: e,
        tag: 'TrackingAuthService',
      );
    }
    return false;
  }

  Future<bool> _exchangeMalCodeForToken(
    String code,
    String codeVerifier,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('https://myanimelist.net/v1/oauth2/token'),
        body: {
          'client_id': _malClientId,
          'client_secret': _malClientSecret,
          'code': code,
          'code_verifier': codeVerifier,
          'grant_type': 'authorization_code',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;

        // Create AuthToken with proper expiration
        final authToken =
            TrackingAuthRepositoryImpl.createTokenFromOAuthResponse(
              TrackingService.mal,
              data,
            );

        // Save using the repository
        await _authRepository.saveToken(TrackingService.mal, authToken);

        // Also save to legacy keys for backward compatibility
        await _secureStorage.write(
          key: 'mal_token',
          value: data['access_token'],
        );
        if (data['refresh_token'] != null) {
          await _secureStorage.write(
            key: 'mal_refresh_token',
            value: data['refresh_token'],
          );
        }

        Logger.info(
          'MAL authentication successful (expires: ${authToken.expiresAt})',
          tag: 'TrackingAuthService',
        );
        return true;
      } else {
        Logger.error(
          'Failed to exchange code for token: ${response.body}',
          tag: 'TrackingAuthService',
        );
        return false;
      }
    } catch (e) {
      Logger.error(
        'Error exchanging code for token',
        error: e,
        tag: 'TrackingAuthService',
      );
      return false;
    }
  }

  Future<bool> _authenticateSimkl() async {
    if (_simklClientId.isEmpty) {
      Logger.error('Simkl Client ID is missing', tag: 'TrackingAuthService');
      return false;
    }

    final url =
        'https://simkl.com/oauth/authorize?response_type=code&client_id=$_simklClientId&redirect_uri=$_redirectUri';

    Logger.info(
      'Starting Simkl auth with URL: $url',
      tag: 'TrackingAuthService',
    );

    try {
      final result = await FlutterWebAuth2.authenticate(
        url: url,
        callbackUrlScheme: 'aniya',
      );

      Logger.info('Auth result: $result', tag: 'TrackingAuthService');

      final code = Uri.parse(result).queryParameters['code'];
      if (code != null) {
        return await _exchangeSimklCodeForToken(code);
      } else {
        Logger.error(
          'Auth result did not contain code',
          tag: 'TrackingAuthService',
        );
      }
    } catch (e) {
      Logger.error(
        'Error during Simkl login',
        error: e,
        tag: 'TrackingAuthService',
      );
    }
    return false;
  }

  Future<bool> _exchangeSimklCodeForToken(String code) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.simkl.com/oauth/token'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'code': code,
          'client_id': _simklClientId,
          'client_secret': _simklClientSecret,
          'redirect_uri': _redirectUri,
          'grant_type': 'authorization_code',
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;

        // Create AuthToken (Simkl tokens never expire)
        final authToken =
            TrackingAuthRepositoryImpl.createTokenFromOAuthResponse(
              TrackingService.simkl,
              data,
            );

        // Save using the repository
        await _authRepository.saveToken(TrackingService.simkl, authToken);

        // Also save to legacy key for backward compatibility
        await _secureStorage.write(
          key: 'simkl_token',
          value: data['access_token'],
        );

        Logger.info(
          'Simkl authentication successful (never expires)',
          tag: 'TrackingAuthService',
        );
        return true;
      } else {
        Logger.error(
          'Failed to exchange code for token: ${response.body}',
          tag: 'TrackingAuthService',
        );
        return false;
      }
    } catch (e) {
      Logger.error(
        'Error exchanging code for token',
        error: e,
        tag: 'TrackingAuthService',
      );
      return false;
    }
  }

  Future<void> logout(TrackingService service) async {
    // Clear from repository
    await _authRepository.clearToken(service);

    // Also clear legacy keys for backward compatibility
    switch (service) {
      case TrackingService.anilist:
        await _secureStorage.delete(key: 'anilist_token');
        break;
      case TrackingService.mal:
        await _secureStorage.delete(key: 'mal_token');
        await _secureStorage.delete(key: 'mal_refresh_token');
        break;
      case TrackingService.simkl:
        await _secureStorage.delete(key: 'simkl_token');
        break;
      case TrackingService.jikan:
        // No auth to logout from
        break;
    }
  }

  Future<bool> isAuthenticated(TrackingService service) async {
    if (service == TrackingService.jikan) {
      return true; // Jikan is a public API, no auth required
    }
    return await _authRepository.isAuthenticated(service);
  }

  /// Get a valid access token for the specified service.
  ///
  /// This will automatically refresh expired tokens when possible (MAL only).
  /// Returns null if no valid token is available.
  Future<String?> getValidToken(TrackingService service) async {
    return await _authRepository.getValidToken(service);
  }

  /// Get the full AuthToken for the specified service.
  Future<AuthToken?> getAuthToken(TrackingService service) async {
    return await _authRepository.getAuthToken(service);
  }

  /// Check if a valid (non-expired) token exists for the service.
  Future<bool> hasValidToken(TrackingService service) async {
    return await _authRepository.hasValidToken(service);
  }

  /// Get the underlying auth repository for advanced operations.
  TrackingAuthRepository get authRepository => _authRepository;
}
