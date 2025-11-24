import 'package:dartz/dartz.dart';
import '../entities/user_entity.dart';
import '../../error/failures.dart';

/// Repository interface for authentication operations
/// Handles user login, logout, and token management across services
abstract class AuthRepository {
  /// Authenticate user with a specific service
  ///
  /// [service] - The tracking service (anilist, mal, simkl)
  /// [authorizationCode] - OAuth2 authorization code from redirect
  /// [redirectUri] - The redirect URI used in the flow
  ///
  /// Returns authenticated user or failure
  Future<Either<Failure, UserEntity>> authenticate(
    TrackingService service, {
    String? authorizationCode,
    String? redirectUri,
  });

  /// Refresh user authentication token
  ///
  /// [service] - The tracking service to refresh
  ///
  /// Returns refreshed user or failure
  Future<Either<Failure, UserEntity>> refreshToken(TrackingService service);

  /// Logout user from a specific service
  ///
  /// [service] - The tracking service to logout from
  ///
  /// Returns success or failure
  Future<Either<Failure, void>> logout(TrackingService service);

  /// Get currently authenticated user for a service
  ///
  /// [service] - The tracking service
  ///
  /// Returns user if authenticated or null, or failure
  Future<Either<Failure, UserEntity?>> getCurrentUser(TrackingService service);

  /// Check if user is authenticated for a service
  ///
  /// [service] - The tracking service
  ///
  /// Returns true if authenticated, false otherwise
  Future<Either<Failure, bool>> isAuthenticated(TrackingService service);

  /// Get OAuth2 authorization URL for a service
  ///
  /// [service] - The tracking service
  /// [redirectUri] - The redirect URI for the OAuth2 flow
  ///
  /// Returns authorization URL or failure
  Future<Either<Failure, String>> getAuthorizationUrl(
    TrackingService service,
    String redirectUri,
  );

  /// Validate and refresh all authenticated user tokens
  ///
  /// Returns list of updated users or failure
  Future<Either<Failure, List<UserEntity>>> validateAndRefreshTokens();
}
