import 'package:flutter/foundation.dart';
import '../../../../core/domain/entities/user_entity.dart';
import '../../../../core/domain/usecases/authenticate_tracking_service_usecase.dart';
import '../../../../core/utils/error_message_mapper.dart';
import '../../../../core/utils/logger.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthenticateTrackingServiceUseCase authenticateTrackingService;

  AuthViewModel({required this.authenticateTrackingService});

  // Map to store authenticated users by service
  final Map<TrackingService, UserEntity> _authenticatedUsers = {};

  // Map to store authentication tokens by service
  final Map<TrackingService, String> _authTokens = {};

  bool _isLoading = false;
  String? _error;

  Map<TrackingService, UserEntity> get authenticatedUsers =>
      _authenticatedUsers;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Check if a service is authenticated
  bool isAuthenticated(TrackingService service) {
    return _authenticatedUsers.containsKey(service);
  }

  /// Get authenticated user for a service
  UserEntity? getUser(TrackingService service) {
    return _authenticatedUsers[service];
  }

  /// Get authentication token for a service
  String? getToken(TrackingService service) {
    return _authTokens[service];
  }

  /// Authenticate with a tracking service
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
            'Failed to authenticate with $service',
            tag: 'AuthViewModel',
            error: failure,
          );
        },
        (user) {
          _authenticatedUsers[service] = user;
          _authTokens[service] = token;
          // TODO: Persist token securely using flutter_secure_storage
          _saveTokenSecurely(service, token);
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
      _authTokens.remove(service);

      // TODO: Remove token from secure storage
      await _removeTokenSecurely(service);

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
  Future<void> loadSavedAuthentications() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // TODO: Load tokens from secure storage and re-authenticate
      // For each service, check if there's a saved token
      for (final service in TrackingService.values) {
        final token = await _loadTokenSecurely(service);
        if (token != null) {
          // Re-authenticate with saved token
          await authenticate(service, token);
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

  /// Private method to save token securely
  Future<void> _saveTokenSecurely(TrackingService service, String token) async {
    // TODO: Implement using flutter_secure_storage
    // Example: await secureStorage.write(key: '${service.name}_token', value: token);
  }

  /// Private method to load token securely
  Future<String?> _loadTokenSecurely(TrackingService service) async {
    // TODO: Implement using flutter_secure_storage
    // Example: return await secureStorage.read(key: '${service.name}_token');
    return null;
  }

  /// Private method to remove token securely
  Future<void> _removeTokenSecurely(TrackingService service) async {
    // TODO: Implement using flutter_secure_storage
    // Example: await secureStorage.delete(key: '${service.name}_token');
  }
}
