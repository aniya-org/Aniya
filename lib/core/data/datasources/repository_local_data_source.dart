import 'dart:convert';
import 'package:hive/hive.dart';

import '../models/repository_config_model.dart';
import '../../domain/entities/extension_entity.dart';
import '../../error/exceptions.dart';

/// Local data source for managing repository configurations using Hive
abstract class RepositoryLocalDataSource {
  /// Get the repository configuration for a specific extension type
  Future<RepositoryConfig?> getRepositoryConfig(ExtensionType type);

  /// Save the repository configuration for a specific extension type
  Future<void> saveRepositoryConfig(
    ExtensionType type,
    RepositoryConfig config,
  );

  /// Delete the repository configuration for a specific extension type
  Future<void> deleteRepositoryConfig(ExtensionType type);

  /// Get all repository configurations
  Future<Map<ExtensionType, RepositoryConfig>> getAllRepositoryConfigs();
}

class RepositoryLocalDataSourceImpl implements RepositoryLocalDataSource {
  static const String _boxName = 'repository_configs';

  final Box<String> _box;

  RepositoryLocalDataSourceImpl({required Box<String> box}) : _box = box;

  /// Factory method to create instance with initialized box
  static Future<RepositoryLocalDataSourceImpl> create() async {
    final box = await Hive.openBox<String>(_boxName);
    return RepositoryLocalDataSourceImpl(box: box);
  }

  String _getKey(ExtensionType type) => 'repo_config_${type.name}';

  @override
  Future<RepositoryConfig?> getRepositoryConfig(ExtensionType type) async {
    try {
      final key = _getKey(type);
      final jsonString = _box.get(key);

      if (jsonString == null) {
        return null;
      }

      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return RepositoryConfig.fromJson(json);
    } catch (e) {
      throw StorageException(
        'Failed to get repository config for ${type.name}: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> saveRepositoryConfig(
    ExtensionType type,
    RepositoryConfig config,
  ) async {
    try {
      final key = _getKey(type);
      final jsonString = jsonEncode(config.toJson());
      await _box.put(key, jsonString);
    } catch (e) {
      throw StorageException(
        'Failed to save repository config for ${type.name}: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> deleteRepositoryConfig(ExtensionType type) async {
    try {
      final key = _getKey(type);
      await _box.delete(key);
    } catch (e) {
      throw StorageException(
        'Failed to delete repository config for ${type.name}: ${e.toString()}',
      );
    }
  }

  @override
  Future<Map<ExtensionType, RepositoryConfig>> getAllRepositoryConfigs() async {
    try {
      final configs = <ExtensionType, RepositoryConfig>{};

      for (final type in ExtensionType.values) {
        final config = await getRepositoryConfig(type);
        if (config != null) {
          configs[type] = config;
        }
      }

      return configs;
    } catch (e) {
      throw StorageException(
        'Failed to get all repository configs: ${e.toString()}',
      );
    }
  }
}
