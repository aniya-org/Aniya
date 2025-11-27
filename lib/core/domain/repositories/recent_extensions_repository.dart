import 'package:dartz/dartz.dart';
import '../entities/extension_entity.dart';
import '../../error/failures.dart';

/// Repository interface for managing recently used extensions
/// Provides methods to store, retrieve, and clear recent extensions
/// Requirements: 8.1, 8.2, 8.3
abstract class RecentExtensionsRepository {
  /// Get list of recently used extensions (up to 5)
  ///
  /// Returns a list of recently used extension entities or a failure
  /// Requirements: 8.1, 8.2
  Future<Either<Failure, List<ExtensionEntity>>> getRecentExtensions();

  /// Add extension to recent list
  ///
  /// [extension] - The extension to add to recent list
  ///
  /// Returns success (Unit) or a failure
  /// Requirements: 8.1
  Future<Either<Failure, Unit>> addRecentExtension(ExtensionEntity extension);

  /// Clear recent extensions list
  ///
  /// Returns success (Unit) or a failure
  /// Requirements: 8.3
  Future<Either<Failure, Unit>> clearRecentExtensions();
}
