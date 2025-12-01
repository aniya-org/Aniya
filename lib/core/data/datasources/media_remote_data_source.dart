import 'package:dartotsu_extension_bridge/ExtensionManager.dart';
import 'package:dartotsu_extension_bridge/Extensions/Extensions.dart';
import 'package:dartotsu_extension_bridge/Models/DMedia.dart';
import 'package:dartotsu_extension_bridge/Models/DEpisode.dart';
import 'package:dartotsu_extension_bridge/Models/Pages.dart';
import 'package:dartotsu_extension_bridge/Models/Source.dart';

import '../../domain/entities/media_entity.dart';
import '../models/media_model.dart';
import '../models/episode_model.dart';
import '../models/chapter_model.dart';
import '../../error/exceptions.dart';

/// Remote data source for fetching media content from extensions
/// Integrates with DartotsuExtensionBridge to access multiple extension types
abstract class MediaRemoteDataSource {
  /// Search for media across all enabled extensions
  Future<List<MediaModel>> searchMedia(String query, String sourceId);

  /// Get detailed information about a media item
  Future<MediaModel> getMediaDetails(String id, String sourceId);

  /// Get episodes for an anime or TV show
  Future<List<EpisodeModel>> getEpisodes(String mediaId, String sourceId);

  /// Get chapters for a manga
  Future<List<ChapterModel>> getChapters(String mediaId, String sourceId);

  /// Get trending media from a source
  Future<List<MediaModel>> getTrending(String sourceId, int page);

  /// Get popular media from a source
  Future<List<MediaModel>> getPopular(String sourceId, int page);

  /// Get pages for a manga chapter
  Future<List<String>> getChapterPages(String chapterId, String sourceId);

  /// Get novel chapter content (HTML/text) for a chapter
  Future<String> getNovelChapterContent(
    String chapterId,
    String chapterTitle,
    String sourceId,
  );
}

class MediaRemoteDataSourceImpl implements MediaRemoteDataSource {
  final ExtensionManager? extensionManager;

  MediaRemoteDataSourceImpl({this.extensionManager});

  /// Get a source by ID from the current extension manager
  Source? _getSourceById(String sourceId) {
    if (extensionManager == null) {
      return null;
    }

    final managers = <Extension>{};
    managers.add(extensionManager!.currentManager);

    for (final type in getSupportedExtensions) {
      try {
        final manager = type.getManager();
        if (!managers.contains(manager)) {
          managers.add(manager);
        }
      } catch (_) {}
    }

    for (final manager in managers) {
      final source = _findSourceInManager(manager, sourceId);
      if (source != null) {
        return source;
      }
    }
    return null;
  }

  Source? _findSourceInManager(Extension manager, String sourceId) {
    final buckets = [
      manager.installedAnimeExtensions.value,
      manager.installedMangaExtensions.value,
      manager.installedNovelExtensions.value,
      manager.installedMovieExtensions.value,
      manager.installedTvShowExtensions.value,
      manager.installedCartoonExtensions.value,
      manager.installedDocumentaryExtensions.value,
      manager.installedLivestreamExtensions.value,
      manager.installedNsfwExtensions.value,
    ];

    for (final bucket in buckets) {
      try {
        return bucket.firstWhere((source) => source.id == sourceId);
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  @override
  Future<List<MediaModel>> searchMedia(String query, String sourceId) async {
    try {
      final source = _getSourceById(sourceId);
      if (source == null) {
        throw ServerException('Source not found: $sourceId');
      }

      final methods = source.methods;
      final Pages result = await methods.search(query, 1, []);
      final fallbackType = _mapBridgeItemTypeToMediaType(source.itemType);

      return result.list
          .map(
            (dMedia) => MediaModel.fromDMedia(
              dMedia,
              sourceId,
              source.name ?? 'Unknown',
              fallbackType: fallbackType,
            ),
          )
          .toList();
    } catch (e) {
      throw ServerException('Failed to search media: ${e.toString()}');
    }
  }

  @override
  Future<MediaModel> getMediaDetails(String id, String sourceId) async {
    try {
      final source = _getSourceById(sourceId);
      if (source == null) {
        throw ServerException('Source not found: $sourceId');
      }

      final methods = source.methods;
      final dMedia = DMedia.withUrl(id);
      final detailedMedia = await methods.getDetail(dMedia);

      return MediaModel.fromDMedia(
        detailedMedia,
        sourceId,
        source.name ?? 'Unknown',
        fallbackType: _mapBridgeItemTypeToMediaType(source.itemType),
      );
    } catch (e) {
      throw ServerException('Failed to get media details: ${e.toString()}');
    }
  }

  @override
  Future<List<EpisodeModel>> getEpisodes(
    String mediaId,
    String sourceId,
  ) async {
    try {
      final source = _getSourceById(sourceId);
      if (source == null) {
        throw ServerException('Source not found: $sourceId');
      }

      final methods = source.methods;
      final dMedia = DMedia.withUrl(mediaId);
      final detailedMedia = await methods.getDetail(dMedia);

      if (detailedMedia.episodes == null || detailedMedia.episodes!.isEmpty) {
        return [];
      }

      return detailedMedia.episodes!
          .map((dEpisode) => EpisodeModel.fromDEpisode(dEpisode, mediaId))
          .toList();
    } catch (e) {
      throw ServerException('Failed to get episodes: ${e.toString()}');
    }
  }

  @override
  Future<List<ChapterModel>> getChapters(
    String mediaId,
    String sourceId,
  ) async {
    try {
      final source = _getSourceById(sourceId);
      if (source == null) {
        throw ServerException('Source not found: $sourceId');
      }

      final methods = source.methods;
      final dMedia = DMedia.withUrl(mediaId);
      final detailedMedia = await methods.getDetail(dMedia);

      if (detailedMedia.episodes == null || detailedMedia.episodes!.isEmpty) {
        return [];
      }

      // For manga sources, episodes are actually chapters
      return detailedMedia.episodes!
          .map((dEpisode) => ChapterModel.fromDEpisode(dEpisode, mediaId))
          .toList();
    } catch (e) {
      throw ServerException('Failed to get chapters: ${e.toString()}');
    }
  }

  @override
  Future<List<MediaModel>> getTrending(String sourceId, int page) async {
    try {
      final source = _getSourceById(sourceId);
      if (source == null) {
        throw ServerException('Source not found: $sourceId');
      }

      final methods = source.methods;
      final Pages result = await methods.getLatestUpdates(page);
      final fallbackType = _mapBridgeItemTypeToMediaType(source.itemType);

      return result.list
          .map(
            (dMedia) => MediaModel.fromDMedia(
              dMedia,
              sourceId,
              source.name ?? 'Unknown',
              fallbackType: fallbackType,
            ),
          )
          .toList();
    } catch (e) {
      throw ServerException('Failed to get trending media: ${e.toString()}');
    }
  }

  @override
  Future<List<MediaModel>> getPopular(String sourceId, int page) async {
    try {
      final source = _getSourceById(sourceId);
      if (source == null) {
        throw ServerException('Source not found: $sourceId');
      }

      final methods = source.methods;
      final Pages result = await methods.getPopular(page);
      final fallbackType = _mapBridgeItemTypeToMediaType(source.itemType);

      return result.list
          .map(
            (dMedia) => MediaModel.fromDMedia(
              dMedia,
              sourceId,
              source.name ?? 'Unknown',
              fallbackType: fallbackType,
            ),
          )
          .toList();
    } catch (e) {
      throw ServerException('Failed to get popular media: ${e.toString()}');
    }
  }

  @override
  Future<List<String>> getChapterPages(
    String chapterId,
    String sourceId,
  ) async {
    try {
      final source = _getSourceById(sourceId);
      if (source == null) {
        throw ServerException('Source not found: $sourceId');
      }

      final methods = source.methods;
      // Create a DEpisode with the chapter URL
      // For manga chapters, episodeNumber is typically "1" or extracted from the URL
      final dEpisode = DEpisode(
        url: chapterId,
        episodeNumber: '1', // Default episode number for manga chapters
      );
      final pageList = await methods.getPageList(dEpisode);

      return pageList.map((page) => page.url).toList();
    } catch (e) {
      throw ServerException('Failed to get chapter pages: ${e.toString()}');
    }
  }

  @override
  Future<String> getNovelChapterContent(
    String chapterId,
    String chapterTitle,
    String sourceId,
  ) async {
    try {
      final source = _getSourceById(sourceId);
      if (source == null) {
        throw ServerException('Source not found: $sourceId');
      }

      final methods = source.methods;
      final content = await methods.getNovelContent(chapterTitle, chapterId);

      if (content == null || content.trim().isEmpty) {
        throw ServerException('No content returned for chapter: $chapterId');
      }

      return content;
    } catch (e) {
      throw ServerException(
        'Failed to get novel chapter content: ${e.toString()}',
      );
    }
  }

  MediaType _mapBridgeItemTypeToMediaType(ItemType? itemType) {
    switch (itemType) {
      case ItemType.manga:
        return MediaType.manga;
      case ItemType.anime:
        return MediaType.anime;
      case ItemType.novel:
        return MediaType.novel;
      case ItemType.movie:
        return MediaType.movie;
      case ItemType.tvShow:
        return MediaType.tvShow;
      case ItemType.cartoon:
        return MediaType.anime;
      case ItemType.documentary:
        return MediaType.tvShow;
      case ItemType.livestream:
        return MediaType.tvShow;
      case ItemType.nsfw:
        return MediaType.anime;
      case null:
        return MediaType.anime;
    }
  }
}
