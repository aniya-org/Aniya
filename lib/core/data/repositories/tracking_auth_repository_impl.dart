import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../domain/entities/auth_token.dart';
import '../../domain/repositories/tracking_auth_repository.dart';
import '../../enums/tracking_service.dart';
import '../../error/failures.dart';
import '../../utils/logger.dart';

/// Implementation of [TrackingAuthRepository] using Flutter Secure Storage.
///
/// This implementation handles token storage, retrieval, and refresh for
/// all tracking services (MAL, AniList, Simkl).
///
/// Token expiration behavior:
/// - **MAL**: Access tokens expire in 1 hour, refresh tokens in 1 month
/// - **AniList**: Access tokens expire in 1 year, no refresh tokens
/// - **Simkl**: Access tokens never expire
class TrackingAuthRepositoryImpl implements TrackingAuthRepository {
  final FlutterSecureStorage _secureStorage;

  // Storage keys
  static const String _tokenKeyPrefix = 'tracking_auth_token_';

  // MAL OAuth endpoints and credentials
  static String get _malClientId => dotenv.env['MAL_CLIENT_ID'] ?? '';
  static String get _malClientSecret => dotenv.env['MAL_CLIENT_SECRET'] ?? '';
  static const String _malTokenEndpoint =
      'https://myanimelist.net/v1/oauth2/token';

  TrackingAuthRepositoryImpl({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Get the storage key for a service's token
  String _getTokenKey(TrackingService service) {
    return '$_tokenKeyPrefix${service.name}';
  }

  @override
  Future<String?> getValidToken(TrackingService service) async {
    try {
      final token = await getAuthToken(service);
      if (token == null) {
        Logger.debug(
          'No token found for ${service.name}',
          tag: 'TrackingAuthRepository',
        );
        return null;
      }

      // Check if token is expired
      if (token.isExpired) {
        Logger.info(
          'Token expired for ${service.name}, attempting refresh',
          tag: 'TrackingAuthRepository',
        );

        // Only MAL supports refresh
        if (token.canRefresh && service == TrackingService.mal) {
          final refreshResult = await refreshToken(service);
          return refreshResult.fold((failure) {
            Logger.error(
              'Token refresh failed for ${service.name}: ${failure.message}',
              tag: 'TrackingAuthRepository',
            );
            return null;
          }, (newToken) => newToken.accessToken);
        }

        // AniList and Simkl don't support refresh
        // AniList tokens are long-lived (1 year), Simkl never expires
        Logger.warning(
          'Token expired for ${service.name} and cannot be refreshed',
          tag: 'TrackingAuthRepository',
        );
        return null;
      }

      return token.accessToken;
    } catch (e, stackTrace) {
      Logger.error(
        'Error getting valid token for ${service.name}',
        tag: 'TrackingAuthRepository',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  @override
  Future<AuthToken?> getAuthToken(TrackingService service) async {
    try {
      final key = _getTokenKey(service);
      final encoded = await _secureStorage.read(key: key);

      if (encoded == null || encoded.isEmpty) {
        return null;
      }

      return AuthToken.decode(encoded);
    } catch (e, stackTrace) {
      Logger.error(
        'Error reading token for ${service.name}',
        tag: 'TrackingAuthRepository',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  @override
  Future<Either<Failure, void>> saveToken(
    TrackingService service,
    AuthToken token,
  ) async {
    try {
      final key = _getTokenKey(service);
      final encoded = token.encode();

      await _secureStorage.write(key: key, value: encoded);

      Logger.info(
        'Token saved for ${service.name} (expires: ${token.expiresAt})',
        tag: 'TrackingAuthRepository',
      );

      return const Right(null);
    } catch (e, stackTrace) {
      Logger.error(
        'Error saving token for ${service.name}',
        tag: 'TrackingAuthRepository',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(StorageFailure('Failed to save token: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> clearToken(TrackingService service) async {
    try {
      final key = _getTokenKey(service);
      await _secureStorage.delete(key: key);

      Logger.info(
        'Token cleared for ${service.name}',
        tag: 'TrackingAuthRepository',
      );

      return const Right(null);
    } catch (e, stackTrace) {
      Logger.error(
        'Error clearing token for ${service.name}',
        tag: 'TrackingAuthRepository',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(StorageFailure('Failed to clear token: $e'));
    }
  }

  @override
  Future<bool> hasValidToken(TrackingService service) async {
    final token = await getValidToken(service);
    return token != null;
  }

  @override
  Future<bool> isAuthenticated(TrackingService service) async {
    final token = await getAuthToken(service);
    return token != null;
  }

  @override
  Future<Either<Failure, AuthToken>> refreshToken(
    TrackingService service,
  ) async {
    try {
      // Only MAL supports token refresh
      if (service != TrackingService.mal) {
        return Left(
          TokenRefreshFailure('${service.name} does not support token refresh'),
        );
      }

      final currentToken = await getAuthToken(service);
      if (currentToken == null || !currentToken.canRefresh) {
        return const Left(TokenRefreshFailure('No refresh token available'));
      }

      Logger.info('Refreshing MAL token', tag: 'TrackingAuthRepository');

      // Make refresh request to MAL
      final response = await http.post(
        Uri.parse(_malTokenEndpoint),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': _malClientId,
          'client_secret': _malClientSecret,
          'grant_type': 'refresh_token',
          'refresh_token': currentToken.refreshToken,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        // Calculate expiration time
        final expiresIn = data['expires_in'] as int? ?? 3600;
        final expiresAt = DateTime.now().add(Duration(seconds: expiresIn));

        final newToken = AuthToken(
          accessToken: data['access_token'] as String,
          refreshToken: data['refresh_token'] as String?,
          expiresAt: expiresAt,
          tokenType: data['token_type'] as String? ?? 'Bearer',
          service: service,
        );

        // Save the new token
        await saveToken(service, newToken);

        Logger.info(
          'MAL token refreshed successfully (expires: $expiresAt)',
          tag: 'TrackingAuthRepository',
        );

        return Right(newToken);
      } else {
        final errorBody = response.body;
        Logger.error(
          'MAL token refresh failed: ${response.statusCode} - $errorBody',
          tag: 'TrackingAuthRepository',
        );

        // If refresh fails with 401, the refresh token is invalid
        if (response.statusCode == 401) {
          // Clear the invalid token
          await clearToken(service);
          return const Left(
            TokenRefreshFailure(
              'Refresh token expired. Please re-authenticate.',
            ),
          );
        }

        return Left(
          TokenRefreshFailure('Token refresh failed: ${response.statusCode}'),
        );
      }
    } catch (e, stackTrace) {
      Logger.error(
        'Error refreshing token for ${service.name}',
        tag: 'TrackingAuthRepository',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(TokenRefreshFailure('Token refresh error: $e'));
    }
  }

  @override
  Future<List<TrackingService>> getAuthenticatedServices() async {
    final authenticated = <TrackingService>[];

    for (final service in TrackingService.values) {
      // Skip Jikan as it doesn't require authentication
      if (service == TrackingService.jikan) continue;

      if (await isAuthenticated(service)) {
        authenticated.add(service);
      }
    }

    return authenticated;
  }

  /// Create an AuthToken from OAuth response data.
  ///
  /// This is a helper method to create tokens with proper expiration
  /// based on the service type.
  static AuthToken createTokenFromOAuthResponse(
    TrackingService service,
    Map<String, dynamic> data,
  ) {
    DateTime? expiresAt;

    switch (service) {
      case TrackingService.mal:
        // MAL tokens expire in ~1 hour (expires_in is in seconds)
        final expiresIn = data['expires_in'] as int? ?? 3600;
        expiresAt = DateTime.now().add(Duration(seconds: expiresIn));
        break;
      case TrackingService.anilist:
        // AniList tokens expire in 1 year
        expiresAt = DateTime.now().add(const Duration(days: 365));
        break;
      case TrackingService.simkl:
        // Simkl tokens never expire
        expiresAt = null;
        break;
      case TrackingService.jikan:
        // Jikan doesn't use authentication
        expiresAt = null;
        break;
    }

    return AuthToken(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String?,
      expiresAt: expiresAt,
      tokenType: data['token_type'] as String? ?? 'Bearer',
      service: service,
    );
  }
}
