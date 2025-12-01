import 'package:dartz/dartz.dart';
import '../entities/library_item_entity.dart';
import '../../../core/error/failures.dart';

/// Repository interface for library management operations
/// Provides methods to manage user's personal media library
abstract class LibraryRepository {
  /// Get all library items, optionally filtered by status
  ///
  /// [status] - Optional filter by library status (watching, completed, etc.)
  ///
  /// Returns a list of library item entities or a failure
  Future<Either<Failure, List<LibraryItemEntity>>> getLibraryItems(
    LibraryStatus? status,
  );

  /// Get a single library item by media ID
  ///
  /// [mediaId] - The unique identifier of the media
  ///
  /// Returns the library item entity or a failure
  Future<Either<Failure, LibraryItemEntity>> getLibraryItem(String mediaId);

  /// Check if a media item is in the library
  ///
  /// [mediaId] - The unique identifier of the media
  ///
  /// Returns true if the item is in the library, false otherwise
  Future<Either<Failure, bool>> isInLibrary(String mediaId);

  /// Add a media item to the library
  ///
  /// [item] - The library item to add
  ///
  /// Returns success (Unit) or a failure
  Future<Either<Failure, Unit>> addToLibrary(LibraryItemEntity item);

  /// Update an existing library item
  ///
  /// [item] - The library item with updated information
  ///
  /// Returns success (Unit) or a failure
  Future<Either<Failure, Unit>> updateLibraryItem(LibraryItemEntity item);

  /// Remove a media item from the library
  ///
  /// [itemId] - The unique identifier of the library item to remove
  ///
  /// Returns success (Unit) or a failure
  Future<Either<Failure, Unit>> removeFromLibrary(String itemId);

  /// Update the progress (episode/chapter) for a library item
  ///
  /// [itemId] - The unique identifier of the library item
  /// [episode] - The current episode number
  /// [chapter] - The current chapter number
  ///
  /// Returns success (Unit) or a failure
  Future<Either<Failure, Unit>> updateProgress(
    String itemId,
    int episode,
    int chapter,
  );

  /// Save playback position for a video episode
  ///
  /// [itemId] - The unique identifier of the library item
  /// [episodeId] - The unique identifier of the episode
  /// [position] - The playback position in milliseconds
  ///
  /// Returns success (Unit) or a failure
  Future<Either<Failure, Unit>> savePlaybackPosition(
    String itemId,
    String episodeId,
    int position,
  );

  /// Get saved playback position for a video episode
  ///
  /// [itemId] - The unique identifier of the library item
  /// [episodeId] - The unique identifier of the episode
  ///
  /// Returns the playback position in milliseconds or a failure
  Future<Either<Failure, int>> getPlaybackPosition(
    String itemId,
    String episodeId,
  );

  /// Save reading position for a manga chapter
  ///
  /// [itemId] - The unique identifier of the library item
  /// [chapterId] - The unique identifier of the chapter
  /// [page] - The current page number
  ///
  /// Returns success (Unit) or a failure
  Future<Either<Failure, Unit>> saveReadingPosition(
    String itemId,
    String chapterId,
    int page,
  );

  /// Get saved reading position for a manga chapter
  ///
  /// [itemId] - The unique identifier of the library item
  /// [chapterId] - The unique identifier of the chapter
  ///
  /// Returns the page number or a failure
  Future<Either<Failure, int>> getReadingPosition(
    String itemId,
    String chapterId,
  );
}
