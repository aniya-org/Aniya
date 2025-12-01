import 'package:dartz/dartz.dart';

import '../../domain/entities/library_item_entity.dart';
import '../../domain/repositories/library_repository.dart';
import '../../error/failures.dart';
import '../../error/exceptions.dart';
import '../datasources/library_local_data_source.dart';
import '../models/library_item_model.dart';
import '../models/media_model.dart';

/// Implementation of LibraryRepository
/// Handles library management with local storage
class LibraryRepositoryImpl implements LibraryRepository {
  final LibraryLocalDataSource localDataSource;

  LibraryRepositoryImpl({required this.localDataSource});

  @override
  Future<Either<Failure, List<LibraryItemEntity>>> getLibraryItems(
    LibraryStatus? status,
  ) async {
    try {
      final List<LibraryItemModel> items;

      if (status != null) {
        items = await localDataSource.getLibraryItemsByStatus(status);
      } else {
        items = await localDataSource.getLibraryItems();
      }

      return Right(items.map((item) => item.toEntity()).toList());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } on StorageException catch (e) {
      return Left(StorageFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get library items: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, LibraryItemEntity>> getLibraryItem(
    String mediaId,
  ) async {
    try {
      final item = await localDataSource.getLibraryItem(mediaId);
      if (item == null) {
        return Left(NotFoundFailure('Library item not found: $mediaId'));
      }
      return Right(item.toEntity());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } on StorageException catch (e) {
      return Left(StorageFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get library item: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, bool>> isInLibrary(String mediaId) async {
    try {
      final item = await localDataSource.getLibraryItem(mediaId);
      return Right(item != null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } on StorageException catch (e) {
      return Left(StorageFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to check library status: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, Unit>> addToLibrary(LibraryItemEntity item) async {
    try {
      // Check if item already exists
      final existingItem = await localDataSource.getLibraryItem(item.id);
      if (existingItem != null) {
        return Left(ValidationFailure('Item already in library: ${item.id}'));
      }

      // Convert entity to model and add to library
      final model = LibraryItemModel(
        id: item.id,
        mediaId: item.mediaId,
        userService: item.userService,
        media: item.media != null ? MediaModel.fromEntity(item.media!) : null,
        mediaType: item.mediaType,
        normalizedId: item.normalizedId,
        sourceId: item.sourceId,
        sourceName: item.sourceName,
        status: item.status,
        progress: item.progress ?? const WatchProgress(),
        addedAt: item.addedAt ?? DateTime.now(),
        lastUpdated: item.lastUpdated,
      );
      await localDataSource.addToLibrary(model);

      return const Right(unit);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } on StorageException catch (e) {
      return Left(StorageFailure(e.message));
    } on ValidationException catch (e) {
      return Left(ValidationFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to add to library: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Unit>> updateLibraryItem(
    LibraryItemEntity item,
  ) async {
    try {
      // Check if item exists
      final existingItem = await localDataSource.getLibraryItem(item.id);
      if (existingItem == null) {
        return Left(ValidationFailure('Item not found in library: ${item.id}'));
      }

      // Convert entity to model and update
      final model = LibraryItemModel(
        id: item.id,
        mediaId: item.mediaId,
        userService: item.userService,
        media: item.media != null ? MediaModel.fromEntity(item.media!) : null,
        mediaType: item.mediaType,
        normalizedId: item.normalizedId,
        sourceId: item.sourceId,
        sourceName: item.sourceName,
        status: item.status,
        progress: item.progress ?? const WatchProgress(),
        addedAt: item.addedAt ?? DateTime.now(),
        lastUpdated: item.lastUpdated,
      );
      await localDataSource.updateLibraryItem(model);

      return const Right(unit);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } on StorageException catch (e) {
      return Left(StorageFailure(e.message));
    } on ValidationException catch (e) {
      return Left(ValidationFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to update library item: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, Unit>> removeFromLibrary(String itemId) async {
    try {
      // Check if item exists
      final existingItem = await localDataSource.getLibraryItem(itemId);
      if (existingItem == null) {
        return Left(ValidationFailure('Item not found in library: $itemId'));
      }

      await localDataSource.removeFromLibrary(itemId);

      return const Right(unit);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } on StorageException catch (e) {
      return Left(StorageFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to remove from library: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, Unit>> updateProgress(
    String itemId,
    int episode,
    int chapter,
  ) async {
    try {
      // Check if item exists
      final existingItem = await localDataSource.getLibraryItem(itemId);
      if (existingItem == null) {
        return Left(ValidationFailure('Item not found in library: $itemId'));
      }

      await localDataSource.updateProgress(itemId, episode, chapter);

      return const Right(unit);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } on StorageException catch (e) {
      return Left(StorageFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to update progress: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Unit>> savePlaybackPosition(
    String itemId,
    String episodeId,
    int position,
  ) async {
    try {
      // Check if item exists
      final existingItem = await localDataSource.getLibraryItem(itemId);
      if (existingItem == null) {
        return Left(ValidationFailure('Item not found in library: $itemId'));
      }

      // Save playback position using the data source
      await localDataSource.savePlaybackPosition(itemId, episodeId, position);

      // Update the library item's last updated timestamp
      final updatedItem = existingItem.copyWith(lastUpdated: DateTime.now());
      await localDataSource.updateLibraryItem(updatedItem);

      return const Right(unit);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } on StorageException catch (e) {
      return Left(StorageFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to save playback position: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, int>> getPlaybackPosition(
    String itemId,
    String episodeId,
  ) async {
    try {
      // Check if item exists
      final existingItem = await localDataSource.getLibraryItem(itemId);
      if (existingItem == null) {
        return Left(ValidationFailure('Item not found in library: $itemId'));
      }

      // Retrieve playback position from data source
      final position = await localDataSource.getPlaybackPosition(
        itemId,
        episodeId,
      );

      // Return position or 0 if not found
      return Right(position ?? 0);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } on StorageException catch (e) {
      return Left(StorageFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get playback position: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, Unit>> saveReadingPosition(
    String itemId,
    String chapterId,
    int page,
  ) async {
    try {
      // Check if item exists
      final existingItem = await localDataSource.getLibraryItem(itemId);
      if (existingItem == null) {
        return Left(ValidationFailure('Item not found in library: $itemId'));
      }

      // Save reading position using the data source
      await localDataSource.saveReadingPosition(itemId, chapterId, page);

      // Update the library item's last updated timestamp
      final updatedItem = existingItem.copyWith(lastUpdated: DateTime.now());
      await localDataSource.updateLibraryItem(updatedItem);

      return const Right(unit);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } on StorageException catch (e) {
      return Left(StorageFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to save reading position: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, int>> getReadingPosition(
    String itemId,
    String chapterId,
  ) async {
    try {
      // Check if item exists
      final existingItem = await localDataSource.getLibraryItem(itemId);
      if (existingItem == null) {
        return Left(ValidationFailure('Item not found in library: $itemId'));
      }

      // Retrieve reading position from data source
      final page = await localDataSource.getReadingPosition(itemId, chapterId);

      // Return page or 0 if not found
      return Right(page ?? 0);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } on StorageException catch (e) {
      return Left(StorageFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get reading position: ${e.toString()}'),
      );
    }
  }
}
