import 'package:dartz/dartz.dart';
import '../entities/extension_entity.dart';
import '../repositories/extension_repository.dart';
import '../../error/failures.dart';

/// Use case for fetching installed extensions by type
///
/// This use case retrieves all extensions that are currently installed
/// for a specific extension type (CloudStream, Aniyomi, Mangayomi, LnReader)
class GetInstalledExtensionsUseCase {
  final ExtensionRepository repository;

  GetInstalledExtensionsUseCase(this.repository);

  /// Execute the use case to get installed extensions
  ///
  /// [type] - The type of extension to fetch
  ///
  /// Returns Either a Failure or a list of ExtensionEntity
  Future<Either<Failure, List<ExtensionEntity>>> call(ExtensionType type) {
    return repository.getInstalledExtensions(type);
  }
}
