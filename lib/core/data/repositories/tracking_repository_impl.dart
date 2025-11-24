import 'package:dartz/dartz.dart';

import '../../domain/entities/user_entity.dart';
import '../../domain/entities/library_item_entity.dart';
import '../../domain/repositories/tracking_repository.dart';
import '../../error/failures.dart';
import '../../error/exceptions.dart';
import '../datasources/tracking_data_source.dart';

/// Implementation of TrackingRepository
/// Handles tracking service integration (AniList, MAL, Simkl)
class TrackingRepositoryImpl implements TrackingRepository {
  final TrackingDataSource dataSource;

  TrackingRepositoryImpl({required this.dataSource});

  @override
  Future<Either<Failure, UserEntity>> authenticate(
    TrackingService service,
    String token,
  ) async {
    try {
      final userModel = await dataSource.authenticate(service, token);
      return Right(userModel.toEntity());
    } on AuthenticationException catch (e) {
      return Left(AuthenticationFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to authenticate: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Unit>> syncProgress(
    String mediaId,
    int episode,
    int chapter,
  ) async {
    try {
      // Get the current tracking service from stored token
      // Try each service until we find one with a valid token
      TrackingService? activeService;

      for (final service in TrackingService.values) {
        final token = await dataSource.getToken(service);
        if (token != null) {
          activeService = service;
          break;
        }
      }

      if (activeService == null) {
        return const Left(
          AuthenticationFailure('No tracking service authenticated'),
        );
      }

      await dataSource.syncProgress(activeService, mediaId, episode, chapter);

      return const Right(unit);
    } on AuthenticationException catch (e) {
      return Left(AuthenticationFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to sync progress: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<LibraryItemEntity>>> fetchRemoteLibrary(
    TrackingService service,
  ) async {
    try {
      final libraryItems = await dataSource.fetchRemoteLibrary(service);
      return Right(libraryItems.map((item) => item.toEntity()).toList());
    } on AuthenticationException catch (e) {
      return Left(AuthenticationFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to fetch remote library: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, Unit>> updateStatus(
    String mediaId,
    LibraryStatus status,
  ) async {
    try {
      // Get the current tracking service from stored token
      // Try each service until we find one with a valid token
      TrackingService? activeService;

      for (final service in TrackingService.values) {
        final token = await dataSource.getToken(service);
        if (token != null) {
          activeService = service;
          break;
        }
      }

      if (activeService == null) {
        return const Left(
          AuthenticationFailure('No tracking service authenticated'),
        );
      }

      await dataSource.updateStatus(activeService, mediaId, status);

      return const Right(unit);
    } on AuthenticationException catch (e) {
      return Left(AuthenticationFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to update status: ${e.toString()}'));
    }
  }
}
