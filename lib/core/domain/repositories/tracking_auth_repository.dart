import 'package:dartz/dartz.dart';

import '../../enums/tracking_service.dart';
import '../../error/failures.dart';
import '../entities/auth_token.dart';

/// Repository interface for managing tracking service authentication tokens.
///
/// This repository handles:
/// - Storing tokens (access + refresh + expiry) per TrackingService
/// - Refreshing tokens when expiring (service-specific refresh endpoints)
/// - Providing valid tokens for API requests
abstract class TrackingAuthRepository {
  /// Get a valid access token for the specified service.
  ///
  /// This method will:
  /// 1. Check if a cached token exists
  /// 2. If expired and refreshable (MAL), attempt to refresh
  /// 3. Return the valid token or null if unavailable
  ///
  /// Returns null if no token exists or token is expired and cannot be refreshed.
  Future<String?> getValidToken(TrackingService service);

  /// Get the full AuthToken object for the specified service.
  ///
  /// Returns null if no token exists for this service.
  Future<AuthToken?> getAuthToken(TrackingService service);

  /// Save an authentication token for the specified service.
  ///
  /// This stores all token data including access token, refresh token,
  /// and expiration time in secure storage.
  Future<Either<Failure, void>> saveToken(
    TrackingService service,
    AuthToken token,
  );

  /// Clear the authentication token for the specified service.
  ///
  /// This removes all stored token data for the service.
  Future<Either<Failure, void>> clearToken(TrackingService service);

  /// Check if a valid token exists for the specified service.
  ///
  /// Returns true if a non-expired token exists, or if an expired token
  /// can be refreshed.
  Future<bool> hasValidToken(TrackingService service);

  /// Check if the user is authenticated with the specified service.
  ///
  /// This is a simple check for token existence (may be expired).
  Future<bool> isAuthenticated(TrackingService service);

  /// Refresh the token for the specified service.
  ///
  /// Only MAL supports token refresh. AniList tokens are long-lived (1 year)
  /// and Simkl tokens never expire.
  ///
  /// Returns the new AuthToken on success, or a Failure if refresh fails.
  Future<Either<Failure, AuthToken>> refreshToken(TrackingService service);

  /// Get all authenticated services.
  ///
  /// Returns a list of services that have stored tokens (may be expired).
  Future<List<TrackingService>> getAuthenticatedServices();
}
