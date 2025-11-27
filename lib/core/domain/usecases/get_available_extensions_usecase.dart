import 'package:dartz/dartz.dart';
import '../entities/extension_entity.dart';
import '../repositories/extension_repository.dart';
import '../../error/failures.dart';

/// Use case for fetching available extensions by type
///
/// This use case retrieves all extensions that are available for installation
/// for a specific extension type (CloudStream, Aniyomi, Mangayomi, LnReader)
class GetAvailableExtensionsUseCase {
  final ExtensionRepository repository;

  GetAvailableExtensionsUseCase(this.repository);

  /// Execute the use case to get available extensions
  ///
  /// [type] - The type of extension to fetch
  /// [repos] - Optional list of repository URLs to fetch extensions from
  ///
  /// Returns Either a Failure or a list of ExtensionEntity
  Future<Either<Failure, List<ExtensionEntity>>> call(
    ExtensionType type, {
    List<String>? repos,
  }) {
    return repository.getAvailableExtensions(type, repos: repos);
  }
}
