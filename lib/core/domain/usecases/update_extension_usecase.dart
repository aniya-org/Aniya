import 'package:dartz/dartz.dart';
import '../repositories/extension_repository.dart';
import '../../error/failures.dart';

/// Use case for updating an extension
///
/// This use case handles updating an installed extension to its latest version.
/// It replaces the old version while preserving user settings.
class UpdateExtensionUseCase {
  final ExtensionRepository repository;

  UpdateExtensionUseCase(this.repository);

  /// Execute the use case to update an extension
  ///
  /// [extensionId] - The unique identifier of the extension to update
  ///
  /// Returns Either a Failure or Unit on success
  Future<Either<Failure, Unit>> call(String extensionId) {
    return repository.updateExtension(extensionId);
  }
}
