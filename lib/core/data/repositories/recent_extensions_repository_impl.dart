import 'dart:convert';
import 'package:dartz/dartz.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/extension_entity.dart';
import '../../domain/repositories/recent_extensions_repository.dart';
import '../../error/failures.dart';
import '../../utils/logger.dart';
import '../models/extension_model.dart';

/// Implementation of RecentExtensionsRepository using SharedPreferences
/// Stores up to 5 recently used extensions in local storage
/// Requirements: 8.1, 8.2, 8.3
class RecentExtensionsRepositoryImpl implements RecentExtensionsRepository {
  final SharedPreferences sharedPreferences;

  /// Key for storing recent extensions in SharedPreferences
  static const String _storageKey = 'recent_extensions';

  /// Maximum number of recent extensions to store
  static const int _maxRecent = 5;

  RecentExtensionsRepositoryImpl({required this.sharedPreferences});

  @override
  Future<Either<Failure, List<ExtensionEntity>>> getRecentExtensions() async {
    try {
      Logger.info(
        'Retrieving recent extensions',
        tag: 'RecentExtensionsRepository',
      );

      // Get the stored JSON list from SharedPreferences
      final jsonList = sharedPreferences.getStringList(_storageKey) ?? [];

      if (jsonList.isEmpty) {
        Logger.info(
          'No recent extensions found',
          tag: 'RecentExtensionsRepository',
        );
        return const Right([]);
      }

      // Convert JSON strings to ExtensionEntity objects
      final extensions = <ExtensionEntity>[];
      for (final jsonString in jsonList) {
        try {
          final json = jsonDecode(jsonString) as Map<String, dynamic>;
          final extension = ExtensionModel.fromJson(json);
          extensions.add(extension);
        } catch (e) {
          Logger.warning(
            'Failed to parse recent extension: $e',
            tag: 'RecentExtensionsRepository',
          );
          // Continue with next extension if parsing fails
          continue;
        }
      }

      Logger.info(
        'Retrieved ${extensions.length} recent extensions',
        tag: 'RecentExtensionsRepository',
      );

      return Right(extensions);
    } catch (e) {
      Logger.error(
        'Failed to get recent extensions',
        tag: 'RecentExtensionsRepository',
        error: e,
      );
      return Left(UnknownFailure('Failed to get recent extensions: $e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> addRecentExtension(
    ExtensionEntity extension,
  ) async {
    try {
      Logger.info(
        'Adding extension to recent: ${extension.name}',
        tag: 'RecentExtensionsRepository',
      );

      // Get current recent extensions
      final jsonList = sharedPreferences.getStringList(_storageKey) ?? [];
      final extensions = <ExtensionEntity>[];

      // Parse existing extensions
      for (final jsonString in jsonList) {
        try {
          final json = jsonDecode(jsonString) as Map<String, dynamic>;
          final ext = ExtensionModel.fromJson(json);
          extensions.add(ext);
        } catch (e) {
          Logger.warning(
            'Failed to parse recent extension during update: $e',
            tag: 'RecentExtensionsRepository',
          );
          continue;
        }
      }

      // Remove the extension if it already exists (to move it to the top)
      extensions.removeWhere((e) => e.id == extension.id);

      // Add the new extension at the beginning
      extensions.insert(0, extension);

      // Keep only the most recent _maxRecent extensions
      if (extensions.length > _maxRecent) {
        extensions.removeRange(_maxRecent, extensions.length);
      }

      // Convert back to JSON strings
      final updatedJsonList = extensions.map((ext) {
        final model = ExtensionModel(
          id: ext.id,
          name: ext.name,
          version: ext.version,
          versionLast: ext.versionLast,
          type: ext.type,
          itemType: ext.itemType,
          language: ext.language,
          isInstalled: ext.isInstalled,
          isNsfw: ext.isNsfw,
          hasUpdate: ext.hasUpdate,
          iconUrl: ext.iconUrl,
          apkUrl: ext.apkUrl,
          description: ext.description,
        );
        return jsonEncode(model.toJson());
      }).toList();

      // Save to SharedPreferences
      await sharedPreferences.setStringList(_storageKey, updatedJsonList);

      Logger.info(
        'Successfully added extension to recent',
        tag: 'RecentExtensionsRepository',
      );

      return const Right(unit);
    } catch (e) {
      Logger.error(
        'Failed to add recent extension',
        tag: 'RecentExtensionsRepository',
        error: e,
      );
      return Left(UnknownFailure('Failed to add recent extension: $e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> clearRecentExtensions() async {
    try {
      Logger.info(
        'Clearing recent extensions',
        tag: 'RecentExtensionsRepository',
      );

      // Remove the storage key
      await sharedPreferences.remove(_storageKey);

      Logger.info(
        'Successfully cleared recent extensions',
        tag: 'RecentExtensionsRepository',
      );

      return const Right(unit);
    } catch (e) {
      Logger.error(
        'Failed to clear recent extensions',
        tag: 'RecentExtensionsRepository',
        error: e,
      );
      return Left(UnknownFailure('Failed to clear recent extensions: $e'));
    }
  }
}
