import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../../../../core/domain/entities/auth_token.dart';
import '../../../../core/domain/entities/user_entity.dart';
import '../../../../core/domain/repositories/tracking_auth_repository.dart';
import '../../../../core/domain/usecases/authenticate_tracking_service_usecase.dart';
import '../../../../core/enums/tracking_service.dart';
import '../../../../core/utils/error_message_mapper.dart';
import '../../../../core/utils/logger.dart';

/// ViewModel for managing authentication state across tracking services.
///
/// This ViewModel integrates with [TrackingAuthRepository] for secure token
/// storage and automatic token refresh (for MAL).
class AuthViewModel extends ChangeNotifier {
  final AuthenticateTrackingServiceUseCase authenticateTrackingService;
  final TrackingAuthRepository _authRepository;

  AuthViewModel({
    required this.authenticateTrackingService,
    required TrackingAuthRepository authRepository,
  }) : _authRepository = authRepository;

  // Map to store authenticated users by service (cached in memory)
  final Map<TrackingService, UserEntity> _authenticatedUsers = {};

  bool _isLoading = false;
  String? _error;

  Map<TrackingService, UserEntity> get authenticatedUsers =>
      Map.unmodifiable(_authenticatedUsers);
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Check if a service is authenticated (has stored token)
  Future<bool> isAuthenticatedAsync(TrackingService service) async {
    return await _authRepository.isAuthenticated(service);
  }

  /// Check if a service is authenticated (sync, uses cached state)
  bool isAuthenticated(TrackingService service) {
    return _authenticatedUsers.containsKey(service);
  }

  /// Get authenticated user for a service
  UserEntity? getUser(TrackingService service) {
    return _authenticatedUsers[service];
  }

  /// Get a valid authentication token for a service.
  ///
  /// This will automatically refresh expired tokens when possible (MAL only).
  /// Returns null if no valid token is available.
  Future<String?> getValidToken(TrackingService service) async {
    return await _authRepository.getValidToken(service);
  }

  /// Get the full AuthToken for a service
  Future<AuthToken?> getAuthToken(TrackingService service) async {
    return await _authRepository.getAuthToken(service);
  }

  /// Ensure a valid token exists for the service.
  ///
  /// If no token exists, this can optionally prompt the user to authenticate.
  /// Returns the valid token, or null if authentication is required but not completed.
  ///
  /// [context] - BuildContext for showing auth prompts (optional)
  /// [showPromptIfMissing] - Whether to show auth prompt if token is missing
  Future<String?> ensureToken(
    TrackingService service, {
    BuildContext? context,
    bool showPromptIfMissing = false,
  }) async {
    // First, try to get a valid token
    final token = await _authRepository.getValidToken(service);
    if (token != null) {
      return token;
    }

    // Token is missing or expired and cannot be refreshed
    if (showPromptIfMissing && context != null) {
      Logger.info(
        'Token missing for ${service.name}, prompt requested',
        tag: 'AuthViewModel',
      );
      // The UI layer should handle showing the auth prompt
      // This method just returns null to indicate auth is needed
    }

    return null;
  }

  /// Authenticate with a tracking service using a token
  Future<void> authenticate(TrackingService service, String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await authenticateTrackingService(
        AuthenticateParams(service: service, token: token),
      );

      result.fold(
        (failure) {
          _error = ErrorMessageMapper.mapFailureToMessage(failure);
          Logger.error(
            'Failed to authenticate with ${service.name}',
            tag: 'AuthViewModel',
            error: failure,
          );
        },
        (user) {
          _authenticatedUsers[service] = user;
          Logger.info(
            'Successfully authenticated with ${service.name}',
            tag: 'AuthViewModel',
          );
        },
      );
    } catch (e, stackTrace) {
      _error = 'An unexpected error occurred. Please try again.';
      Logger.error(
        'Unexpected error during authentication',
        tag: 'AuthViewModel',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Logout from a tracking service
  Future<void> logout(TrackingService service) async {
    try {
      _authenticatedUsers.remove(service);

      // Clear token from secure storage
      final result = await _authRepository.clearToken(service);
      result.fold(
        (failure) {
          Logger.error(
            'Failed to clear token for ${service.name}',
            tag: 'AuthViewModel',
            error: failure,
          );
        },
        (_) {
          Logger.info(
            'Successfully logged out from ${service.name}',
            tag: 'AuthViewModel',
          );
        },
      );

      _error = null;
      notifyListeners();
    } catch (e, stackTrace) {
      _error = 'Failed to logout. Please try again.';
      Logger.error(
        'Error during logout',
        tag: 'AuthViewModel',
        error: e,
        stackTrace: stackTrace,
      );
      notifyListeners();
    }
  }

  /// Load saved authentication tokens on app start
  ///
  /// This loads tokens from secure storage and validates them.
  /// For services with valid tokens, it re-authenticates to get user info.
  Future<void> loadSavedAuthentications() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Get all services that have stored tokens
      final authenticatedServices = await _authRepository
          .getAuthenticatedServices();

      Logger.info(
        'Found ${authenticatedServices.length} saved authentications',
        tag: 'AuthViewModel',
      );

      for (final service in authenticatedServices) {
        // Check if token is still valid (or can be refreshed)
        final token = await _authRepository.getValidToken(service);
        if (token != null) {
          // Re-authenticate to get user info
          await authenticate(service, token);
        } else {
          Logger.warning(
            'Token for ${service.name} is expired and cannot be refreshed',
            tag: 'AuthViewModel',
          );
        }
      }
    } catch (e, stackTrace) {
      _error = 'Failed to load saved authentications. Please sign in again.';
      Logger.error(
        'Error loading saved authentications',
        tag: 'AuthViewModel',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Check if a valid (non-expired) token exists for the service
  Future<bool> hasValidToken(TrackingService service) async {
    return await _authRepository.hasValidToken(service);
  }

  /// Get list of all authenticated services
  Future<List<TrackingService>> getAuthenticatedServices() async {
    return await _authRepository.getAuthenticatedServices();
  }

  /// Clear error state
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
