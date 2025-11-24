import 'package:dartz/dartz.dart';
import '../entities/extension_entity.dart';
import '../../../core/error/failures.dart';

/// Repository interface for extension management operations
/// Provides methods to browse, install, update, and remove extensions
abstract class ExtensionRepository {
  /// Get all available extensions for a specific type
  ///
  /// [type] - The type of extension (cloudstream, aniyomi, mangayomi, lnreader)
  ///
  /// Returns a list of available extension entities or a failure
  Future<Either<Failure, List<ExtensionEntity>>> getAvailableExtensions(
    ExtensionType type,
  );

  /// Get all installed extensions for a specific type
  ///
  /// [type] - The type of extension (cloudstream, aniyomi, mangayomi, lnreader)
  ///
  /// Returns a list of installed extension entities or a failure
  Future<Either<Failure, List<ExtensionEntity>>> getInstalledExtensions(
    ExtensionType type,
  );

  /// Install a new extension
  ///
  /// [extensionId] - The unique identifier of the extension to install
  /// [type] - The type of extension
  ///
  /// Returns success (Unit) or a failure
  Future<Either<Failure, Unit>> installExtension(
    String extensionId,
    ExtensionType type,
  );

  /// Uninstall an existing extension
  ///
  /// [extensionId] - The unique identifier of the extension to uninstall
  ///
  /// Returns success (Unit) or a failure
  Future<Either<Failure, Unit>> uninstallExtension(String extensionId);

  /// Update an existing extension to the latest version
  ///
  /// [extensionId] - The unique identifier of the extension to update
  ///
  /// Returns success (Unit) or a failure
  Future<Either<Failure, Unit>> updateExtension(String extensionId);

  /// Check for available updates for all installed extensions
  ///
  /// Returns a list of extensions that have updates available or a failure
  Future<Either<Failure, List<ExtensionEntity>>> checkForUpdates();
}
