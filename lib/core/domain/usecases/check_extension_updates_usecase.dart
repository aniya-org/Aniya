import 'package:dartz/dartz.dart';
import '../entities/extension_entity.dart';
import '../repositories/extension_repository.dart';
import '../../error/failures.dart';

/// Use case for checking for extension updates
///
/// This use case checks all installed extensions for available updates
/// and returns a list of extensions that have updates available.
class CheckExtensionUpdatesUseCase {
  final ExtensionRepository repository;

  CheckExtensionUpdatesUseCase(this.repository);

  /// Execute the use case to check for extension updates
  ///
  /// Returns Either a Failure or a list of ExtensionEntity with updates available
  Future<Either<Failure, List<ExtensionEntity>>> call() {
    return repository.checkForUpdates();
  }
}
