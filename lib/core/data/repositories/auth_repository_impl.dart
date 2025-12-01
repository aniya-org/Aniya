import 'dart:convert';
import 'package:aniya/core/error/exceptions.dart';
import 'package:aniya/core/utils/logger.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../error/failures.dart';
import '../datasources/anilist_auth_data_source.dart';
import '../datasources/mal_auth_data_source.dart';
import '../datasources/simkl_auth_data_source.dart';

/// Implementation of AuthRepository
/// Handles OAuth2 authentication across multiple services
class AuthRepositoryImpl implements AuthRepository {
  final FlutterSecureStorage _secureStorage;
  final AnilistAuthDataSource _anilistAuth;
  final MalAuthDataSource _malAuth;
  final SimklAuthDataSource _simklAuth;

  // Storage keys
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _tokenExpiryKey = 'token_expiry';
  static const String _userDataKey = 'user_data';

  AuthRepositoryImpl({
    FlutterSecureStorage? secureStorage,
    AnilistAuthDataSource? anilistAuth,
    MalAuthDataSource? malAuth,
    SimklAuthDataSource? simklAuth,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _anilistAuth = anilistAuth ?? AnilistAuthDataSource(),
       _malAuth = malAuth ?? MalAuthDataSource(),
       _simklAuth = simklAuth ?? SimklAuthDataSource();

  @override
  Future<Either<Failure, UserEntity>> authenticate(
    TrackingService service, {
    String? authorizationCode,
    String? redirectUri,
  }) async {
    try {
      if (authorizationCode == null || redirectUri == null) {
        return Left(AuthFailure('Missing authorization code or redirect URI'));
      }

      // Exchange code for tokens
      final tokenData = await _exchangeCodeForTokens(
        service,
        authorizationCode,
        redirectUri,
      );

      // Get user info using access token
      final userInfo = await _getUserInfo(service, tokenData['access_token']);

      // Create user entity
      final user = _createUserEntity(service, userInfo, tokenData);

      // Store authentication data
      await _storeAuthData(service, tokenData, user);

      return Right(user);
    } on ServerException catch (e) {
      Logger.error('Authentication failed', error: e, tag: 'AuthRepository');
      return Left(AuthFailure(e.message));
    } catch (e, stackTrace) {
      Logger.error(
        'Authentication failed',
        error: e,
        stackTrace: stackTrace,
        tag: 'AuthRepository',
      );
      return Left(AuthFailure('Authentication failed: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> refreshToken(
    TrackingService service,
  ) async {
    try {
      final refreshToken = await _loadRefreshToken(service);
      if (refreshToken == null) {
        return Left(AuthFailure('No refresh token available'));
      }

      // Get new tokens
      final tokenData = await _refreshTokens(service, refreshToken);

      // Get user info with new access token
      final userInfo = await _getUserInfo(service, tokenData['access_token']);

      // Create user entity
      final storedUserData = await _loadUserData(service);
      final user = _createUserEntity(
        service,
        userInfo,
        tokenData,
        storedUserData,
      );

      // Store updated data
      await _storeAuthData(service, tokenData, user);

      return Right(user);
    } on ServerException catch (e) {
      Logger.error('Token refresh failed', error: e, tag: 'AuthRepository');
      return Left(AuthFailure(e.message));
    } catch (e, stackTrace) {
      Logger.error(
        'Token refresh failed',
        error: e,
        stackTrace: stackTrace,
        tag: 'AuthRepository',
      );
      return Left(AuthFailure('Token refresh failed: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> logout(TrackingService service) async {
    try {
      await _clearAuthData(service);
      return const Right(null);
    } catch (e, stackTrace) {
      Logger.error(
        'Logout failed',
        error: e,
        stackTrace: stackTrace,
        tag: 'AuthRepository',
      );
      return Left(AuthFailure('Logout failed: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser(
    TrackingService service,
  ) async {
    try {
      final userData = await _loadUserData(service);
      if (userData == null) {
        return const Right(null);
      }

      return Right(_userFromJson(service, userData));
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to get current user',
        error: e,
        stackTrace: stackTrace,
        tag: 'AuthRepository',
      );
      return Left(AuthFailure('Failed to get current user: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> isAuthenticated(TrackingService service) async {
    try {
      final accessToken = await _loadAccessToken(service);
      final expiry = await _loadTokenExpiry(service);

      if (accessToken == null || expiry == null) {
        return const Right(false);
      }

      // Check if token is expired or will expire within 5 minutes
      final bufferTime = const Duration(minutes: 5);
      final isExpired = DateTime.now().add(bufferTime).isAfter(expiry);

      return Right(!isExpired);
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to check authentication',
        error: e,
        stackTrace: stackTrace,
        tag: 'AuthRepository',
      );
      return const Right(false);
    }
  }

  @override
  Future<Either<Failure, String>> getAuthorizationUrl(
    TrackingService service,
    String redirectUri,
  ) async {
    try {
      String url;
      switch (service) {
        case TrackingService.anilist:
          url = _anilistAuth.getAuthorizationUrl(redirectUri);
          break;
        case TrackingService.mal:
          url = _malAuth.getAuthorizationUrl(redirectUri);
          break;
        case TrackingService.simkl:
          url = _simklAuth.getAuthorizationUrl(redirectUri);
          break;
        case TrackingService.jikan:
        case TrackingService.local:
          throw ServerException(
            'Jikan and local do not require authentication',
          );
      }

      return Right(url);
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to get authorization URL',
        error: e,
        stackTrace: stackTrace,
        tag: 'AuthRepository',
      );
      return Left(
        AuthFailure('Failed to get authorization URL: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, List<UserEntity>>> validateAndRefreshTokens() async {
    final users = <UserEntity>[];

    for (final service in TrackingService.values) {
      final authStatus = await isAuthenticated(service);
      authStatus.fold(
        (failure) => Logger.error(
          'Failed to check auth status for $service',
          error: failure,
        ),
        (isAuth) async {
          if (isAuth) {
            // Try to refresh if needed (within 1 hour of expiry)
            final expiry = await _loadTokenExpiry(service);
            if (expiry != null &&
                DateTime.now().add(const Duration(hours: 1)).isAfter(expiry)) {
              final refreshResult = await refreshToken(service);
              refreshResult.fold(
                (failure) => Logger.error(
                  'Failed to refresh token for $service',
                  error: failure,
                ),
                (user) => users.add(user),
              );
            } else {
              // Load current user
              final userResult = await getCurrentUser(service);
              userResult.fold(
                (failure) => Logger.error(
                  'Failed to get user for $service',
                  error: failure,
                ),
                (user) => user != null ? users.add(user) : null,
              );
            }
          }
        },
      );
    }

    return Right(users);
  }

  // Helper methods for token exchange
  Future<Map<String, dynamic>> _exchangeCodeForTokens(
    TrackingService service,
    String code,
    String redirectUri,
  ) async {
    switch (service) {
      case TrackingService.anilist:
        return await _anilistAuth.exchangeCodeForToken(code, redirectUri);
      case TrackingService.mal:
        return await _malAuth.exchangeCodeForToken(code, redirectUri);
      case TrackingService.simkl:
        return await _simklAuth.exchangeCodeForToken(code, redirectUri);
      case TrackingService.jikan:
      case TrackingService.local:
        throw ServerException('Jikan does not require authentication');
    }
  }

  Future<Map<String, dynamic>> _refreshTokens(
    TrackingService service,
    String refreshToken,
  ) async {
    switch (service) {
      case TrackingService.anilist:
        return await _anilistAuth.refreshToken(refreshToken);
      case TrackingService.mal:
        return await _malAuth.refreshToken(refreshToken);
      case TrackingService.simkl:
        return await _simklAuth.refreshToken(refreshToken);
      case TrackingService.jikan:
      case TrackingService.local:
        throw ServerException('Jikan does not support token refresh');
    }
  }

  Future<Map<String, dynamic>> _getUserInfo(
    TrackingService service,
    String accessToken,
  ) async {
    switch (service) {
      case TrackingService.anilist:
        return await _anilistAuth.getUserInfo(accessToken);
      case TrackingService.mal:
        return await _malAuth.getUserInfo(accessToken);
      case TrackingService.simkl:
        return await _simklAuth.getUserInfo(accessToken);
      case TrackingService.jikan:
      case TrackingService.local:
        throw ServerException('Jikan does not require authentication');
    }
  }

  UserEntity _createUserEntity(
    TrackingService service,
    Map<String, dynamic> userInfo,
    Map<String, dynamic> tokenData, [
    Map<String, dynamic>? existingUserData,
  ]) {
    // User data structure varies by service
    String id, username, avatarUrl;

    switch (service) {
      case TrackingService.anilist:
        id = userInfo['id'].toString();
        username = userInfo['name'] ?? 'AniList User';
        avatarUrl = userInfo['avatar']?['large'];
        break;

      case TrackingService.mal:
        id = userInfo['id'].toString();
        username = userInfo['name'] ?? 'MAL User';
        avatarUrl = userInfo['picture'];
        break;

      case TrackingService.simkl:
        id =
            userInfo['account']?['id'].toString() ??
            existingUserData?['id']?.toString() ??
            'unknown';
        username =
            userInfo['user']?['name'] ??
            existingUserData?['username'] ??
            'Simkl User';
        avatarUrl = userInfo['user']?['avatar'];
        break;
      case TrackingService.jikan:
      case TrackingService.local:
        throw ServerException('Jikan does not require authentication');
    }

    return UserEntity(
      id: id,
      username: username,
      avatarUrl: avatarUrl,
      service: service,
      // Could add more fields like accessToken expiry, etc.
    );
  }

  // Storage helper methods
  String _getServicePrefix(TrackingService service) {
    return '$service.name_';
  }

  Future<void> _storeAuthData(
    TrackingService service,
    Map<String, dynamic> tokenData,
    UserEntity user,
  ) async {
    final prefix = _getServicePrefix(service);

    // Store tokens
    if (tokenData['access_token'] != null) {
      await _secureStorage.write(
        key: '$prefix$_accessTokenKey',
        value: tokenData['access_token'],
      );
    }

    if (tokenData['refresh_token'] != null) {
      await _secureStorage.write(
        key: '$prefix$_refreshTokenKey',
        value: tokenData['refresh_token'],
      );
    }

    // Store expiry time (usually access_token expires in 1 hour)
    if (tokenData['expires_in'] != null) {
      final expiry = DateTime.now().add(
        Duration(seconds: tokenData['expires_in']),
      );
      await _secureStorage.write(
        key: '$prefix$_tokenExpiryKey',
        value: expiry.toIso8601String(),
      );
    }

    // Store user data
    await _secureStorage.write(
      key: '$prefix$_userDataKey',
      value: jsonEncode(_userToJson(user)),
    );
  }

  Future<String?> _loadAccessToken(TrackingService service) async {
    final prefix = _getServicePrefix(service);
    return await _secureStorage.read(key: '$prefix$_accessTokenKey');
  }

  Future<String?> _loadRefreshToken(TrackingService service) async {
    final prefix = _getServicePrefix(service);
    return await _secureStorage.read(key: '$prefix$_refreshTokenKey');
  }

  Future<DateTime?> _loadTokenExpiry(TrackingService service) async {
    final prefix = _getServicePrefix(service);
    final expiryStr = await _secureStorage.read(key: '$prefix$_tokenExpiryKey');
    return expiryStr != null ? DateTime.tryParse(expiryStr) : null;
  }

  Future<Map<String, dynamic>?> _loadUserData(TrackingService service) async {
    final prefix = _getServicePrefix(service);
    final userDataStr = await _secureStorage.read(key: '$prefix$_userDataKey');
    return userDataStr != null ? jsonDecode(userDataStr) : null;
  }

  Future<void> _clearAuthData(TrackingService service) async {
    final prefix = _getServicePrefix(service);

    await _secureStorage.delete(key: '$prefix$_accessTokenKey');
    await _secureStorage.delete(key: '$prefix$_refreshTokenKey');
    await _secureStorage.delete(key: '$prefix$_tokenExpiryKey');
    await _secureStorage.delete(key: '$prefix$_userDataKey');
  }

  // JSON serialization helpers
  Map<String, dynamic> _userToJson(UserEntity user) {
    return {
      'id': user.id,
      'username': user.username,
      'avatarUrl': user.avatarUrl,
      'service': user.service.name,
    };
  }

  UserEntity _userFromJson(TrackingService service, Map<String, dynamic> json) {
    return UserEntity(
      id: json['id'],
      username: json['username'],
      avatarUrl: json['avatarUrl'],
      service: service,
    );
  }
}
