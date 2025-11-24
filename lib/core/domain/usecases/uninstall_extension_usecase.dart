import 'package:dartz/dartz.dart';
import '../repositories/extension_repository.dart';
import '../../error/failures.dart';

/// Use case for uninstalling an extension
///
/// This use case handles the removal of an installed extension by its ID.
/// It deletes the extension and cleans up associated data.
class UninstallExtensionUseCase {
  final ExtensionRepository repository;

  UninstallExtensionUseCase(this.repository);

  /// Execute the use case to uninstall an extension
  ///
  /// [extensionId] - The unique identifier of the extension to uninstall
  ///
  /// Returns Either a Failure or Unit on success
  Future<Either<Failure, Unit>> call(String extensionId) {
    return repository.uninstallExtension(extensionId);
  }
}
