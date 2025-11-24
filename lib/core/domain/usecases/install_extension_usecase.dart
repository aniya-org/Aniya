import 'package:dartz/dartz.dart';
import '../entities/extension_entity.dart';
import '../repositories/extension_repository.dart';
import '../../error/failures.dart';

/// Use case for installing an extension
///
/// This use case handles the installation of a new extension by its ID and type.
/// It downloads and configures the extension, making it available for use.
class InstallExtensionUseCase {
  final ExtensionRepository repository;

  InstallExtensionUseCase(this.repository);

  /// Execute the use case to install an extension
  ///
  /// [extensionId] - The unique identifier of the extension to install
  /// [type] - The type of extension (CloudStream, Aniyomi, Mangayomi, LnReader)
  ///
  /// Returns Either a Failure or Unit on success
  Future<Either<Failure, Unit>> call(String extensionId, ExtensionType type) {
    return repository.installExtension(extensionId, type);
  }
}
