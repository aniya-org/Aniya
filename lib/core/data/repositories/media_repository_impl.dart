import 'package:dartz/dartz.dart';
import 'package:dartotsu_extension_bridge/Models/Source.dart';

import '../../domain/entities/media_entity.dart';
import '../../domain/entities/episode_entity.dart';
import '../../domain/entities/chapter_entity.dart';
import '../../domain/entities/search_result_entity.dart';
import '../../domain/entities/extension_entity.dart' as domain_ext;
import '../../domain/repositories/media_repository.dart';
import '../../error/failures.dart';
import '../../error/exceptions.dart';
import '../../utils/logger.dart';
import '../../constants/app_constants.dart';
import '../datasources/media_remote_data_source.dart';
import '../datasources/media_local_data_source.dart';
import '../datasources/extension_data_source.dart';
import '../datasources/external_remote_data_source.dart';

/// Implementation of MediaRepository
/// Handles media operations with error handling and failure conversion
class MediaRepositoryImpl implements MediaRepository {
  final MediaRemoteDataSource remoteDataSource;
  final MediaLocalDataSource localDataSource;
  final ExtensionDataSource extensionDataSource;
  final ExternalRemoteDataSource externalDataSource;

  MediaRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.extensionDataSource,
    required this.externalDataSource,
  });

  @override
  Future<Either<Failure, List<MediaEntity>>> searchMedia(
    String query,
    MediaType type, {
    String? sourceId,
    SourceProgressCallback? onSourceProgress,
  }) async {
    try {
      Logger.info(
        'MediaRepositoryImpl.searchMedia: query="$query", type=$type, sourceId=$sourceId',
        tag: 'MediaRepositoryImpl',
      );

      // If sourceId is provided, search from external source
      if (sourceId != null) {
        Logger.debug(
          'Routing to external data source for sourceId: $sourceId',
          tag: 'MediaRepositoryImpl',
        );

        _emitSourceProgress(
          onSourceProgress,
          SourceSearchProgress(
            sourceId: sourceId,
            sourceName: _formatSourceName(sourceId),
            isLoading: true,
            hasError: false,
            results: const [],
          ),
        );

        final result = await externalDataSource.searchMediaAdvanced(
          query,
          sourceId,
          type,
          page: 1,
          perPage: AppConstants.maxPageSize,
        );

        Logger.info(
          'External search completed: ${result.items.length} results',
          tag: 'MediaRepositoryImpl',
        );

        _emitSourceProgress(
          onSourceProgress,
          SourceSearchProgress(
            sourceId: sourceId,
            sourceName: _formatSourceName(sourceId),
            isLoading: false,
            hasError: false,
            results: result.items,
          ),
        );

        return Right(result.items);
      }

      // Otherwise, search across all installed extensions for the media type
      final ItemType itemType = _mapMediaTypeToItemType(type);
      final installedExtensions = <MediaEntity>[];

      // Search across all extension types
      for (final extensionType in extensionDataSource.getSupportedTypes()) {
        try {
          final extensions = await extensionDataSource.getInstalledExtensions(
            extensionType,
            itemType,
          );

          // Search in each installed extension
          for (final extension in extensions) {
            try {
              final bridgeItemType = _mapDomainItemTypeToBridgeItemType(
                extension.itemType,
              );

              _emitSourceProgress(
                onSourceProgress,
                SourceSearchProgress(
                  sourceId: extension.id,
                  sourceName: extension.name,
                  isLoading: true,
                  hasError: false,
                  results: const [],
                ),
              );

              final results = await extensionDataSource.searchMedia(
                query: query,
                extensionId: extension.id,
                extensionType: extensionType,
                itemType: bridgeItemType,
                page: 1,
              );

              final entities = results.map((m) => m.toEntity()).toList();
              installedExtensions.addAll(entities);

              _emitSourceProgress(
                onSourceProgress,
                SourceSearchProgress(
                  sourceId: extension.id,
                  sourceName: extension.name,
                  isLoading: false,
                  hasError: false,
                  results: entities,
                ),
              );

              // Stop if we've reached the max page size limit
              if (installedExtensions.length >= AppConstants.maxPageSize) {
                break;
              }
            } catch (e) {
              _emitSourceProgress(
                onSourceProgress,
                SourceSearchProgress(
                  sourceId: extension.id,
                  sourceName: extension.name,
                  isLoading: false,
                  hasError: true,
                  errorMessage: e.toString(),
                  results: const [],
                ),
              );
              continue;
            }
          }

          // Stop if we've reached the max page size limit
          if (installedExtensions.length >= AppConstants.maxPageSize) {
            break;
          }
        } catch (e) {
          Logger.warning(
            'Extension type $extensionType search failed: $e',
            tag: 'MediaRepositoryImpl',
          );
          continue;
        }
      }

      // Limit results to max page size for search
      final limitedResults = installedExtensions
          .take(AppConstants.maxPageSize)
          .toList();
      return Right(limitedResults);
    } on ServerException catch (e) {
      Logger.error(
        'Server exception in searchMedia',
        tag: 'MediaRepositoryImpl',
        error: e,
      );
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      Logger.error(
        'Network exception in searchMedia',
        tag: 'MediaRepositoryImpl',
        error: e,
      );
      return Left(NetworkFailure(e.message));
    } on ExtensionException catch (e) {
      Logger.error(
        'Extension exception in searchMedia',
        tag: 'MediaRepositoryImpl',
        error: e,
      );
      return Left(ExtensionFailure(e.message));
    } catch (e, stackTrace) {
      Logger.error(
        'Unexpected error in searchMedia',
        tag: 'MediaRepositoryImpl',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(UnknownFailure('Failed to search media: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, String>> getNovelChapterContent(
    String chapterId,
    String chapterTitle,
    String sourceId,
  ) async {
    try {
      final content = await remoteDataSource.getNovelChapterContent(
        chapterId,
        chapterTitle,
        sourceId,
      );
      return Right(content);
    } on ServerException catch (e) {
      Logger.error(
        'Server exception in getNovelChapterContent',
        tag: 'MediaRepositoryImpl',
        error: e,
      );
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      Logger.error(
        'Network exception in getNovelChapterContent',
        tag: 'MediaRepositoryImpl',
        error: e,
      );
      return Left(NetworkFailure(e.message));
    } catch (e, stackTrace) {
      Logger.error(
        'Unexpected error in getNovelChapterContent',
        tag: 'MediaRepositoryImpl',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(
        UnknownFailure('Failed to get novel chapter content: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, MediaEntity>> getMediaDetails(
    String id,
    String sourceId,
  ) async {
    try {
      // Try to get from cache first
      final cachedMedia = await localDataSource.getCachedMedia(id);
      if (cachedMedia != null) {
        return Right(cachedMedia.toEntity());
      }

      // Fetch from remote
      final media = await remoteDataSource.getMediaDetails(id, sourceId);

      // Cache the result
      await localDataSource.cacheMedia(media);

      return Right(media.toEntity());
    } on ServerException catch (e) {
      Logger.error(
        'Server exception in getMediaDetails',
        tag: 'MediaRepositoryImpl',
        error: e,
      );
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      Logger.error(
        'Network exception in getMediaDetails',
        tag: 'MediaRepositoryImpl',
        error: e,
      );
      return Left(NetworkFailure(e.message));
    } on CacheException catch (e) {
      Logger.error(
        'Cache exception in getMediaDetails',
        tag: 'MediaRepositoryImpl',
        error: e,
      );
      return Left(CacheFailure(e.message));
    } catch (e, stackTrace) {
      Logger.error(
        'Unexpected error in getMediaDetails',
        tag: 'MediaRepositoryImpl',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(
        UnknownFailure('Failed to get media details: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, List<MediaEntity>>> getTrending(
    MediaType type,
    int page, {
    String? sourceId,
  }) async {
    try {
      // If sourceId is provided, get trending from external source
      if (sourceId != null) {
        final results = await externalDataSource.getTrending(
          sourceId,
          type,
          page: page,
        );
        return Right(results);
      }
      final ItemType itemType = _mapMediaTypeToItemType(type);
      final trendingMedia = <MediaEntity>[];

      // Get trending from all installed extensions
      for (final extensionType in extensionDataSource.getSupportedTypes()) {
        try {
          final extensions = await extensionDataSource.getInstalledExtensions(
            extensionType,
            itemType,
          );

          for (final extension in extensions) {
            try {
              final results = await remoteDataSource.getTrending(
                extension.id,
                page,
              );
              trendingMedia.addAll(results.map((m) => m.toEntity()));

              // Stop if we've reached the page size limit
              if (trendingMedia.length >= AppConstants.defaultPageSize) {
                break;
              }
            } catch (e) {
              // Continue with other extensions if one fails
              continue;
            }
          }

          // Stop if we've reached the page size limit
          if (trendingMedia.length >= AppConstants.defaultPageSize) {
            break;
          }
        } catch (e) {
          // Continue with other extension types if one fails
          continue;
        }
      }

      // Limit results to page size
      final limitedResults = trendingMedia
          .take(AppConstants.defaultPageSize)
          .toList();
      return Right(limitedResults);
    } on ServerException catch (e) {
      Logger.error(
        'Server exception in getTrending',
        tag: 'MediaRepositoryImpl',
        error: e,
      );
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      Logger.error(
        'Network exception in getTrending',
        tag: 'MediaRepositoryImpl',
        error: e,
      );
      return Left(NetworkFailure(e.message));
    } catch (e, stackTrace) {
      Logger.error(
        'Unexpected error in getTrending',
        tag: 'MediaRepositoryImpl',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(UnknownFailure('Failed to get trending: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<MediaEntity>>> getPopular(
    MediaType type,
    int page, {
    String? sourceId,
  }) async {
    try {
      // If sourceId is provided, get popular from external source
      if (sourceId != null) {
        final results = await externalDataSource.getPopular(
          sourceId,
          type,
          page: page,
        );
        return Right(results);
      }

      final ItemType itemType = _mapMediaTypeToItemType(type);
      final popularMedia = <MediaEntity>[];

      // Get popular from all installed extensions
      for (final extensionType in extensionDataSource.getSupportedTypes()) {
        try {
          final extensions = await extensionDataSource.getInstalledExtensions(
            extensionType,
            itemType,
          );

          for (final extension in extensions) {
            try {
              final results = await remoteDataSource.getPopular(
                extension.id,
                page,
              );
              popularMedia.addAll(results.map((m) => m.toEntity()));

              // Stop if we've reached the page size limit
              if (popularMedia.length >= AppConstants.defaultPageSize) {
                break;
              }
            } catch (e) {
              // Continue with other extensions if one fails
              continue;
            }
          }

          // Stop if we've reached the page size limit
          if (popularMedia.length >= AppConstants.defaultPageSize) {
            break;
          }
        } catch (e) {
          // Continue with other extension types if one fails
          continue;
        }
      }

      // Limit results to page size
      final limitedResults = popularMedia
          .take(AppConstants.defaultPageSize)
          .toList();
      return Right(limitedResults);
    } on ServerException catch (e) {
      Logger.error(
        'Server exception in getPopular',
        tag: 'MediaRepositoryImpl',
        error: e,
      );
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      Logger.error(
        'Network exception in getPopular',
        tag: 'MediaRepositoryImpl',
        error: e,
      );
      return Left(NetworkFailure(e.message));
    } catch (e, stackTrace) {
      Logger.error(
        'Unexpected error in getPopular',
        tag: 'MediaRepositoryImpl',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(UnknownFailure('Failed to get popular: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<EpisodeEntity>>> getEpisodes(
    String mediaId,
    String sourceId,
  ) async {
    try {
      // Check if this is an external source that supports aggregation
      if (_isExternalSource(sourceId)) {
        // For external sources, we need the full MediaEntity to perform aggregation
        // This is a limitation of the current interface - we'll need to fetch details first
        Logger.warning(
          'getEpisodes called with external source but no MediaEntity. '
          'Consider using getEpisodesWithAggregation for better results.',
          tag: 'MediaRepositoryImpl',
        );
      }

      final episodes = await remoteDataSource.getEpisodes(mediaId, sourceId);
      return Right(episodes.map((e) => e.toEntity()).toList());
    } on ServerException catch (e) {
      Logger.error(
        'Server exception in getEpisodes',
        tag: 'MediaRepositoryImpl',
        error: e,
      );
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      Logger.error(
        'Network exception in getEpisodes',
        tag: 'MediaRepositoryImpl',
        error: e,
      );
      return Left(NetworkFailure(e.message));
    } catch (e, stackTrace) {
      Logger.error(
        'Unexpected error in getEpisodes',
        tag: 'MediaRepositoryImpl',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(UnknownFailure('Failed to get episodes: ${e.toString()}'));
    }
  }

  /// Get episodes with cross-provider aggregation for external sources
  @override
  Future<Either<Failure, List<EpisodeEntity>>> getEpisodesWithAggregation(
    MediaEntity media,
  ) async {
    try {
      // Check if this is an external source
      if (_isExternalSource(media.sourceId)) {
        // Use external data source with aggregation
        final episodes = await externalDataSource.getEpisodes(media);
        return Right(episodes);
      } else {
        // Use regular extension-based data source
        final episodes = await remoteDataSource.getEpisodes(
          media.id,
          media.sourceId,
        );
        return Right(episodes.map((e) => e.toEntity()).toList());
      }
    } on ServerException catch (e) {
      Logger.error(
        'Server exception in getEpisodesWithAggregation',
        tag: 'MediaRepositoryImpl',
        error: e,
      );
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      Logger.error(
        'Network exception in getEpisodesWithAggregation',
        tag: 'MediaRepositoryImpl',
        error: e,
      );
      return Left(NetworkFailure(e.message));
    } catch (e, stackTrace) {
      Logger.error(
        'Unexpected error in getEpisodesWithAggregation',
        tag: 'MediaRepositoryImpl',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(UnknownFailure('Failed to get episodes: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<ChapterEntity>>> getChapters(
    String mediaId,
    String sourceId,
  ) async {
    try {
      // Check if this is an external source that supports aggregation
      if (_isExternalSource(sourceId)) {
        // For external sources, we need the full MediaEntity to perform aggregation
        // This is a limitation of the current interface - we'll need to fetch details first
        Logger.warning(
          'getChapters called with external source but no MediaEntity. '
          'Consider using getChaptersWithAggregation for better results.',
          tag: 'MediaRepositoryImpl',
        );
      }

      final chapters = await remoteDataSource.getChapters(mediaId, sourceId);
      return Right(chapters.map((c) => c.toEntity()).toList());
    } on ServerException catch (e) {
      Logger.error(
        'Server exception in getChapters',
        tag: 'MediaRepositoryImpl',
        error: e,
      );
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      Logger.error(
        'Network exception in getChapters',
        tag: 'MediaRepositoryImpl',
        error: e,
      );
      return Left(NetworkFailure(e.message));
    } catch (e, stackTrace) {
      Logger.error(
        'Unexpected error in getChapters',
        tag: 'MediaRepositoryImpl',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(UnknownFailure('Failed to get chapters: ${e.toString()}'));
    }
  }

  /// Get chapters with cross-provider aggregation for external sources
  @override
  Future<Either<Failure, List<ChapterEntity>>> getChaptersWithAggregation(
    MediaEntity media,
  ) async {
    try {
      // Check if this is an external source
      if (_isExternalSource(media.sourceId)) {
        // Use external data source with aggregation
        final chapters = await externalDataSource.getChapters(media);
        return Right(chapters);
      } else {
        // Use regular extension-based data source
        final chapters = await remoteDataSource.getChapters(
          media.id,
          media.sourceId,
        );
        return Right(chapters.map((c) => c.toEntity()).toList());
      }
    } on ServerException catch (e) {
      Logger.error(
        'Server exception in getChaptersWithAggregation',
        tag: 'MediaRepositoryImpl',
        error: e,
      );
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      Logger.error(
        'Network exception in getChaptersWithAggregation',
        tag: 'MediaRepositoryImpl',
        error: e,
      );
      return Left(NetworkFailure(e.message));
    } catch (e, stackTrace) {
      Logger.error(
        'Unexpected error in getChaptersWithAggregation',
        tag: 'MediaRepositoryImpl',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(UnknownFailure('Failed to get chapters: ${e.toString()}'));
    }
  }

  /// Check if a source ID is an external source (vs extension)
  bool _isExternalSource(String sourceId) {
    final externalSources = ['tmdb', 'anilist', 'jikan', 'kitsu', 'simkl'];
    return externalSources.contains(sourceId.toLowerCase());
  }

  @override
  Future<Either<Failure, List<String>>> getChapterPages(
    String chapterId,
    String sourceId,
  ) async {
    try {
      final pages = await remoteDataSource.getChapterPages(chapterId, sourceId);
      return Right(pages);
    } on ServerException catch (e) {
      Logger.error(
        'Server exception in getChapterPages',
        tag: 'MediaRepositoryImpl',
        error: e,
      );
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      Logger.error(
        'Network exception in getChapterPages',
        tag: 'MediaRepositoryImpl',
        error: e,
      );
      return Left(NetworkFailure(e.message));
    } catch (e, stackTrace) {
      Logger.error(
        'Unexpected error in getChapterPages',
        tag: 'MediaRepositoryImpl',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(
        UnknownFailure('Failed to get chapter pages: ${e.toString()}'),
      );
    }
  }

  @override
  /// Advanced search for media with filtering and pagination (external sources only)
  Future<Either<Failure, SearchResult<List<MediaEntity>>>> searchMediaAdvanced(
    String query,
    MediaType type,
    String sourceId, {
    List<String>? genres,
    int? year,
    String? season,
    String? status,
    String? format,
    int? minScore,
    int? maxScore,
    String? sort,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final result = await externalDataSource.searchMediaAdvanced(
        query,
        sourceId,
        type,
        genres: genres,
        year: year,
        season: season,
        status: status,
        format: format,
        minScore: minScore,
        maxScore: maxScore,
        sort: sort,
        page: page,
        perPage: perPage,
      );
      return Right(result);
    } on ServerException catch (e) {
      Logger.error(
        'Server exception in searchMediaAdvanced',
        tag: 'MediaRepositoryImpl',
        error: e,
      );
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      Logger.error(
        'Network exception in searchMediaAdvanced',
        tag: 'MediaRepositoryImpl',
        error: e,
      );
      return Left(NetworkFailure(e.message));
    } on ExtensionException catch (e) {
      Logger.error(
        'Extension exception in searchMediaAdvanced',
        tag: 'MediaRepositoryImpl',
        error: e,
      );
      return Left(ExtensionFailure(e.message));
    } catch (e, stackTrace) {
      Logger.error(
        'Unexpected error in searchMediaAdvanced',
        tag: 'MediaRepositoryImpl',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(UnknownFailure('Failed to search media: ${e.toString()}'));
    }
  }

  /// Helper method to map MediaType to ItemType
  ItemType _mapMediaTypeToItemType(MediaType type) {
    switch (type) {
      case MediaType.anime:
        return ItemType.anime;
      case MediaType.manga:
        return ItemType.manga;
      case MediaType.novel:
        return ItemType.novel;
      case MediaType.movie:
        return ItemType.movie;
      case MediaType.tvShow:
        return ItemType.tvShow;
      case MediaType.cartoon:
        return ItemType.cartoon;
      case MediaType.documentary:
        return ItemType.documentary;
      case MediaType.livestream:
        return ItemType.livestream;
      case MediaType.nsfw:
        return ItemType.anime; // NSFW content typically uses anime type
    }
  }

  ItemType _mapDomainItemTypeToBridgeItemType(domain_ext.ItemType itemType) {
    switch (itemType) {
      case domain_ext.ItemType.anime:
        return ItemType.anime;
      case domain_ext.ItemType.manga:
        return ItemType.manga;
      case domain_ext.ItemType.novel:
        return ItemType.novel;
      case domain_ext.ItemType.movie:
        return ItemType.movie;
      case domain_ext.ItemType.tvShow:
        return ItemType.tvShow;
      case domain_ext.ItemType.cartoon:
        return ItemType.cartoon;
      case domain_ext.ItemType.documentary:
        return ItemType.documentary;
      case domain_ext.ItemType.livestream:
        return ItemType.livestream;
      case domain_ext.ItemType.nsfw:
        return ItemType.nsfw;
    }
  }

  void _emitSourceProgress(
    SourceProgressCallback? callback,
    SourceSearchProgress progress,
  ) {
    if (callback != null) {
      callback(progress);
    }
  }

  String _formatSourceName(String sourceId) {
    switch (sourceId.toLowerCase()) {
      case 'tmdb':
        return 'TMDB';
      case 'anilist':
        return 'AniList';
      case 'jikan':
      case 'mal':
        return 'MyAnimeList';
      case 'kitsu':
        return 'Kitsu';
      case 'simkl':
        return 'Simkl';
      default:
        return sourceId.toUpperCase();
    }
  }
}
