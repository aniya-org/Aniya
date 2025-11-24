import 'package:dartz/dartz.dart';
import '../repositories/tracking_repository.dart';
import '../entities/user_entity.dart';
import '../../error/failures.dart';

/// Use case for authenticating with tracking services
///
/// This use case handles authentication with external tracking services
/// (AniList, MAL, Simkl) and returns the authenticated user entity
class AuthenticateTrackingServiceUseCase {
  final TrackingRepository repository;

  AuthenticateTrackingServiceUseCase(this.repository);

  /// Execute the use case to authenticate with a tracking service
  ///
  /// [params] - The parameters containing service type and authentication token
  ///
  /// Returns Either a Failure or the authenticated UserEntity
  Future<Either<Failure, UserEntity>> call(AuthenticateParams params) {
    return repository.authenticate(params.service, params.token);
  }
}

/// Parameters for authenticating with a tracking service
class AuthenticateParams {
  final TrackingService service;
  final String token;

  AuthenticateParams({required this.service, required this.token});
}
