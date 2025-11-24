import 'dart:convert';
import 'package:dartz/dartz.dart';
import '../../../core/error/failures.dart';
import '../entities/library_item_entity.dart';
import '../../data/models/library_item_model.dart';

/// Service for exporting and importing application data
abstract class DataExportImportService {
  /// Export library items to JSON string
  Future<Either<Failure, String>> exportLibrary(List<LibraryItemEntity> items);

  /// Import library items from JSON string
  Future<Either<Failure, List<LibraryItemEntity>>> importLibrary(
    String jsonData,
  );

  /// Export settings to JSON string
  Future<Either<Failure, String>> exportSettings(Map<String, dynamic> settings);

  /// Import settings from JSON string
  Future<Either<Failure, Map<String, dynamic>>> importSettings(String jsonData);
}

class DataExportImportServiceImpl implements DataExportImportService {
  @override
  Future<Either<Failure, String>> exportLibrary(
    List<LibraryItemEntity> items,
  ) async {
    try {
      final jsonList = items.map((item) {
        if (item is LibraryItemModel) {
          return item.toJson();
        }
        // Fallback for non-model entities
        return {
          'id': item.id,
          'media': {
            'id': item.media.id,
            'title': item.media.title,
            'coverImage': item.media.coverImage,
            'bannerImage': item.media.bannerImage,
            'description': item.media.description,
            'type': item.media.type.name,
            'rating': item.media.rating,
            'genres': item.media.genres,
            'status': item.media.status.name,
            'totalEpisodes': item.media.totalEpisodes,
            'totalChapters': item.media.totalChapters,
            'sourceId': item.media.sourceId,
            'sourceName': item.media.sourceName,
          },
          'status': item.status.name,
          'currentEpisode': item.currentEpisode,
          'currentChapter': item.currentChapter,
          'addedAt': item.addedAt.toIso8601String(),
          'lastUpdated': item.lastUpdated?.toIso8601String(),
        };
      }).toList();

      final exportData = {
        'version': '1.0',
        'exportedAt': DateTime.now().toIso8601String(),
        'itemCount': jsonList.length,
        'items': jsonList,
      };

      return Right(jsonEncode(exportData));
    } catch (e) {
      return Left(StorageFailure('Failed to export library: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<LibraryItemEntity>>> importLibrary(
    String jsonData,
  ) async {
    try {
      final decoded = jsonDecode(jsonData) as Map<String, dynamic>;

      // Validate export format
      if (!decoded.containsKey('items') || decoded['items'] is! List) {
        return Left(ValidationFailure('Invalid library export format'));
      }

      final items = <LibraryItemEntity>[];
      final itemsList = decoded['items'] as List<dynamic>;

      for (final itemJson in itemsList) {
        if (itemJson is Map<String, dynamic>) {
          try {
            final item = LibraryItemModel.fromJson(itemJson);
            items.add(item);
          } catch (e) {
            // Skip invalid items
            continue;
          }
        }
      }

      return Right(items);
    } catch (e) {
      return Left(
        ValidationFailure('Failed to import library: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, String>> exportSettings(
    Map<String, dynamic> settings,
  ) async {
    try {
      final exportData = {
        'version': '1.0',
        'exportedAt': DateTime.now().toIso8601String(),
        'settings': settings,
      };

      return Right(jsonEncode(exportData));
    } catch (e) {
      return Left(StorageFailure('Failed to export settings: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> importSettings(
    String jsonData,
  ) async {
    try {
      final decoded = jsonDecode(jsonData) as Map<String, dynamic>;

      // Validate export format
      if (!decoded.containsKey('settings') ||
          decoded['settings'] is! Map<String, dynamic>) {
        return Left(ValidationFailure('Invalid settings export format'));
      }

      return Right(decoded['settings'] as Map<String, dynamic>);
    } catch (e) {
      return Left(
        ValidationFailure('Failed to import settings: ${e.toString()}'),
      );
    }
  }
}
