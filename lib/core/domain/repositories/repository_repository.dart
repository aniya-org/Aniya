import 'package:dartz/dartz.dart';
import '../entities/extension_entity.dart';
import '../../data/models/repository_config_model.dart';
import '../../error/failures.dart';

/// Repository interface for managing extension repository configurations
/// Provides methods to get, save, and fetch extensions from repository URLs
abstract class RepositoryRepository {
  /// Get the repository configuration for a specific extension type
  ///
  /// [type] - The extension type (cloudstream, aniyomi, mangayomi, lnreader)
  ///
  /// Returns the repository configuration or a failure
  Future<Either<Failure, RepositoryConfig>> getRepositoryConfig(
    ExtensionType type,
  );

  /// Save the repository configuration for a specific extension type
  ///
  /// [type] - The extension type
  /// [config] - The repository configuration to save
  ///
  /// Returns success (Unit) or a failure
  Future<Either<Failure, Unit>> saveRepositoryConfig(
    ExtensionType type,
    RepositoryConfig config,
  );

  /// Fetch extensions from a repository URL
  ///
  /// [repoUrl] - The repository URL to fetch from
  /// [itemType] - The item type (anime, manga, novel)
  /// [extensionType] - The extension type for parsing
  ///
  /// Returns a list of extensions or a failure
  Future<Either<Failure, List<ExtensionEntity>>> fetchExtensionsFromRepo(
    String repoUrl,
    ItemType itemType,
    ExtensionType extensionType,
  );

  /// Aggregate extensions from multiple repositories
  ///
  /// [extensionLists] - List of extension lists to aggregate
  ///
  /// Returns a deduplicated list of extensions
  List<ExtensionEntity> aggregateExtensions(
    List<List<ExtensionEntity>> extensionLists,
  );

  /// Fetch extensions from a CloudStream repository
  ///
  /// CloudStream repositories have a manifest format with pluginLists
  /// that point to separate JSON files containing the actual plugins.
  ///
  /// [repoUrl] - The CloudStream repository URL
  ///
  /// Returns a list of extensions or a failure
  Future<Either<Failure, List<ExtensionEntity>>> fetchCloudStreamRepository(
    String repoUrl,
  );
}
