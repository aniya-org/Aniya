import 'package:dartz/dartz.dart';
import 'package:dartotsu_extension_bridge/ExtensionManager.dart' as bridge;
import 'package:dartotsu_extension_bridge/Models/Source.dart' as bridge_source;

import '../../domain/entities/extension_entity.dart' as domain_ext;
import '../../domain/entities/media_entity.dart';
import '../../domain/entities/episode_entity.dart';
import '../../domain/entities/source_entity.dart';
import '../../domain/repositories/extension_search_repository.dart';
import '../../error/failures.dart';
import '../../error/exceptions.dart';
import '../../utils/logger.dart';
import '../datasources/extension_data_source.dart';

/// Implementation of ExtensionSearchRepository
/// Handles searching for media within extensions and retrieving sources
/// Supports both CloudStream and Aniyomi/Mangayomi extensions
/// Requirements: 3.2, 4.1
class ExtensionSearchRepositoryImpl implements ExtensionSearchRepository {
  final ExtensionDataSource extensionDataSource;

  ExtensionSearchRepositoryImpl({required this.extensionDataSource});

  @override
  Future<Either<Failure, List<MediaEntity>>> searchMedia(
    String query,
    domain_ext.ExtensionEntity extension,
    int page,
  ) async {
    try {
      // Validate input
      if (query.trim().isEmpty) {
        return Left(ValidationFailure('Search query cannot be empty'));
      }

      if (page < 1) {
        return Left(ValidationFailure('Page number must be >= 1'));
      }

      Logger.info(
        'Searching for "$query" in ${extension.name} (page $page)',
        tag: 'ExtensionSearchRepository',
      );

      // Handle CloudStream extensions
      if (extension.type == domain_ext.ExtensionType.cloudstream) {
        return await _searchMediaCloudStream(query, extension, page);
      }

      // Handle Aniyomi/Mangayomi/LnReader extensions
      return await _searchMediaExtensionBridge(query, extension, page);
    } on ValidationException catch (e) {
      Logger.error(
        'Validation error',
        tag: 'ExtensionSearchRepository',
        error: e,
      );
      return Left(ValidationFailure(e.message));
    } on NetworkException catch (e) {
      Logger.error('Network error', tag: 'ExtensionSearchRepository', error: e);
      return Left(NetworkFailure(e.message));
    } catch (e) {
      Logger.error(
        'Unexpected error searching media',
        tag: 'ExtensionSearchRepository',
        error: e,
      );
      return Left(UnknownFailure('Failed to search media: $e'));
    }
  }

  @override
  Future<Either<Failure, List<SourceEntity>>> getSources(
    MediaEntity media,
    domain_ext.ExtensionEntity extension,
    EpisodeEntity episode,
  ) async {
    try {
      Logger.info(
        'Getting sources for ${media.title} from ${extension.name}',
        tag: 'ExtensionSearchRepository',
      );

      // Handle CloudStream extensions
      if (extension.type == domain_ext.ExtensionType.cloudstream) {
        return await _getSourcesCloudStream(media, extension, episode);
      }

      // Handle Aniyomi/Mangayomi/LnReader extensions
      return await _getSourcesExtensionBridge(media, extension, episode);
    } on NetworkException catch (e) {
      Logger.error('Network error', tag: 'ExtensionSearchRepository', error: e);
      return Left(NetworkFailure(e.message));
    } catch (e) {
      Logger.error(
        'Unexpected error getting sources',
        tag: 'ExtensionSearchRepository',
        error: e,
      );
      return Left(UnknownFailure('Failed to get sources: $e'));
    }
  }

  /// Search for media in CloudStream extension
  Future<Either<Failure, List<MediaEntity>>> _searchMediaCloudStream(
    String query,
    domain_ext.ExtensionEntity extension,
    int page,
  ) async {
    return _searchMediaViaBridge(query, extension, page);
  }

  /// Search for media in Aniyomi/Mangayomi/LnReader extension via bridge
  Future<Either<Failure, List<MediaEntity>>> _searchMediaExtensionBridge(
    String query,
    domain_ext.ExtensionEntity extension,
    int page,
  ) async {
    return _searchMediaViaBridge(query, extension, page);
  }

  /// Get sources from CloudStream extension
  Future<Either<Failure, List<SourceEntity>>> _getSourcesCloudStream(
    MediaEntity media,
    domain_ext.ExtensionEntity extension,
    EpisodeEntity episode,
  ) async {
    return _getSourcesViaBridge(media, extension, episode);
  }

  /// Get sources from Aniyomi/Mangayomi/LnReader extension via bridge
  Future<Either<Failure, List<SourceEntity>>> _getSourcesExtensionBridge(
    MediaEntity media,
    domain_ext.ExtensionEntity extension,
    EpisodeEntity episode,
  ) async {
    return _getSourcesViaBridge(media, extension, episode);
  }

  Future<Either<Failure, List<MediaEntity>>> _searchMediaViaBridge(
    String query,
    domain_ext.ExtensionEntity extension,
    int page,
  ) async {
    try {
      final bridgeType = _mapEntityTypeToBridgeType(extension.type);
      final bridgeItemType = _mapDomainItemTypeToBridgeItemType(
        extension.itemType,
      );

      final results = await extensionDataSource.searchMedia(
        query: query,
        extensionId: extension.id,
        extensionType: bridgeType,
        itemType: bridgeItemType,
        page: page,
      );

      final mediaList = results.map((model) => model.toEntity()).toList();

      Logger.info(
        'Found ${mediaList.length} results for "$query"',
        tag: 'ExtensionSearchRepository',
      );

      return Right(mediaList);
    } catch (e) {
      Logger.error(
        'Extension bridge search failed',
        tag: 'ExtensionSearchRepository',
        error: e,
      );
      return Left(UnknownFailure('Search failed: $e'));
    }
  }

  Future<Either<Failure, List<SourceEntity>>> _getSourcesViaBridge(
    MediaEntity media,
    domain_ext.ExtensionEntity extension,
    EpisodeEntity episode,
  ) async {
    try {
      final bridgeType = _mapEntityTypeToBridgeType(extension.type);
      final bridgeItemType = _mapDomainItemTypeToBridgeItemType(
        extension.itemType,
      );

      final sources = await extensionDataSource.getSources(
        mediaId: media.id,
        extensionId: extension.id,
        extensionType: bridgeType,
        itemType: bridgeItemType,
        episodeNumber: episode.number,
      );

      final sourceList = sources.map((model) => model.toEntity()).toList();

      Logger.info(
        'Found ${sourceList.length} sources for ${media.title}',
        tag: 'ExtensionSearchRepository',
      );

      return Right(sourceList);
    } catch (e) {
      Logger.error(
        'Extension bridge source retrieval failed',
        tag: 'ExtensionSearchRepository',
        error: e,
      );
      return Left(UnknownFailure('Source retrieval failed: $e'));
    }
  }

  /// Map entity ExtensionType to bridge ExtensionType
  bridge.ExtensionType _mapEntityTypeToBridgeType(
    domain_ext.ExtensionType type,
  ) {
    switch (type) {
      case domain_ext.ExtensionType.cloudstream:
        return bridge.ExtensionType.cloudstream;
      case domain_ext.ExtensionType.aniyomi:
        return bridge.ExtensionType.aniyomi;
      case domain_ext.ExtensionType.mangayomi:
        return bridge.ExtensionType.mangayomi;
      case domain_ext.ExtensionType.lnreader:
        return bridge.ExtensionType.lnreader;
    }
  }

  /// Map domain ItemType to bridge ItemType
  bridge_source.ItemType _mapDomainItemTypeToBridgeItemType(
    domain_ext.ItemType domainType,
  ) {
    switch (domainType) {
      case domain_ext.ItemType.manga:
        return bridge_source.ItemType.manga;
      case domain_ext.ItemType.anime:
        return bridge_source.ItemType.anime;
      case domain_ext.ItemType.novel:
        return bridge_source.ItemType.novel;
      case domain_ext.ItemType.movie:
        return bridge_source.ItemType.movie;
      case domain_ext.ItemType.tvShow:
        return bridge_source.ItemType.tvShow;
      case domain_ext.ItemType.cartoon:
        return bridge_source.ItemType.cartoon;
      case domain_ext.ItemType.documentary:
        return bridge_source.ItemType.documentary;
      case domain_ext.ItemType.livestream:
        return bridge_source.ItemType.livestream;
      case domain_ext.ItemType.nsfw:
        return bridge_source.ItemType.nsfw;
    }
  }
}
