import 'package:dartz/dartz.dart';
import 'package:dartotsu_extension_bridge/ExtensionManager.dart' as bridge;
import 'package:dartotsu_extension_bridge/Extensions/ExtractorService.dart'
    show ExtractorResult, ExtractorService;
import 'package:dartotsu_extension_bridge/Models/DEpisode.dart';
import 'package:dartotsu_extension_bridge/Models/Video.dart';
import 'package:dartotsu_extension_bridge/Models/DMedia.dart'
    show CloudStreamUrlCodec;

import '../../domain/entities/video_source_entity.dart';
import '../../domain/repositories/video_repository.dart';
import '../../error/failures.dart';
import '../../error/exceptions.dart';
import '../models/video_source_model.dart';
import '../../utils/logger.dart';

/// Implementation of VideoRepository
/// Handles video source fetching and URL extraction from extensions
/// Validates: Requirements 5.3, 5.4
class VideoRepositoryImpl implements VideoRepository {
  final bridge.ExtensionManager? extensionManager;

  VideoRepositoryImpl({this.extensionManager});

  final ExtractorService _extractorService = ExtractorService();

  /// Get a source by ID from the current extension manager
  dynamic _getSourceById(String sourceId) {
    if (extensionManager == null) {
      return null;
    }

    final extension = extensionManager!.currentManager;

    // Check all installed extension lists
    final allSources = [
      ...extension.installedAnimeExtensions.value,
      ...extension.installedMovieExtensions.value,
      ...extension.installedTvShowExtensions.value,
    ];

    try {
      return allSources.firstWhere((source) => source.id == sourceId);
    } catch (e) {
      return null;
    }
  }

  Future<String?> _tryExtractorService(VideoSource source) async {
    try {
      if (!await _extractorService.isInitialized) {
        final initialized = await _extractorService.initialize();
        if (!initialized) {
          Logger.warning('ExtractorService failed to initialize');
          return null;
        }
      }

      final referer = source.headers?['referer'] ?? source.headers?['Referer'];
      final ExtractorResult result = await _extractorService.extract(
        source.url,
        referer: referer,
      );

      if (!result.hasLinks) {
        Logger.info('ExtractorService returned no links for ${source.name}');
        return null;
      }

      final bestLink = result.bestQualityLink ?? result.links.first;
      Logger.info(
        'ExtractorService selected ${bestLink.qualityString} for ${source.name}',
      );
      return bestLink.url;
    } catch (e, stackTrace) {
      Logger.error(
        'ExtractorService failed for ${source.name}: $e',
        tag: 'VideoRepositoryImpl',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  @override
  Future<Either<Failure, List<VideoSource>>> getVideoSources(
    String episodeId,
    String sourceId,
  ) async {
    try {
      Logger.info(
        'Fetching video sources for episode: $episodeId from source: $sourceId',
      );

      // Get the source extension
      final source = _getSourceById(sourceId);
      if (source == null) {
        Logger.error('Source not found: $sourceId');
        return Left(ExtensionFailure('Source not found: $sourceId'));
      }

      // Create a DEpisode object with the episode number
      // Parse episode number from episodeId if it's numeric
      final episodeNumber = int.tryParse(episodeId) ?? 1;
      final episode = DEpisode(episodeNumber: episodeNumber.toString());

      // Load video servers for the episode
      final methods = source.methods;
      final servers = await methods.loadVideoServers(
        episode,
        null, // Extra data if needed
      );

      if (servers.isEmpty) {
        Logger.warning('No video sources available for episode: $episodeId');
        return Left(
          ServerFailure('No video sources available for episode: $episodeId'),
        );
      }

      Logger.info(
        'Found ${servers.length} video servers for episode: $episodeId',
      );

      // Convert server objects to VideoSource entities
      final videoSources = <VideoSourceModel>[];

      for (int i = 0; i < servers.length; i++) {
        final server = servers[i];

        // Skip servers without embed URLs
        if (server.embed?.url == null || server.embed!.url.isEmpty) {
          Logger.warning('Skipping server ${server.name} - no embed URL');
          continue;
        }

        // Create a video source for each server
        final videoSource = VideoSourceModel(
          id: '${episodeId}_${server.name ?? i}',
          name: server.name ?? 'Server ${i + 1}',
          url: server.embed!.url,
          quality: 'Auto', // Quality will be determined during extraction
          server: server.name ?? 'Unknown',
          headers: server.embed?.headers,
        );

        videoSources.add(videoSource);
      }

      if (videoSources.isEmpty) {
        Logger.error('All servers had invalid embed URLs');
        return Left(
          ServerFailure(
            'No valid video sources available for episode: $episodeId',
          ),
        );
      }

      Logger.info('Successfully created ${videoSources.length} video sources');
      return Right(videoSources.map((s) => s.toEntity()).toList());
    } on ServerException catch (e) {
      Logger.error('Server exception: ${e.message}');
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      Logger.error('Network exception: ${e.message}');
      return Left(NetworkFailure(e.message));
    } on ExtensionException catch (e) {
      Logger.error('Extension exception: ${e.message}');
      return Left(ExtensionFailure(e.message));
    } catch (e) {
      Logger.error('Unexpected error getting video sources: $e');
      return Left(
        UnknownFailure('Failed to get video sources: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, String>> extractVideoUrl(VideoSource source) async {
    try {
      Logger.info('Extracting video URL from source: ${source.name}');

      // Validate the source URL
      if (source.url.trim().isEmpty) {
        Logger.error('Video source URL is empty');
        return Left(ValidationFailure('Video source URL is empty'));
      }

      // Check if URL is already a direct video URL
      if (_isDirectVideoUrl(source.url)) {
        Logger.info('URL is already a direct video URL: ${source.url}');
        return Right(source.url);
      }

      // Try the CloudStream extractor service first (supports all video sources)
      final extractorUrl = await _tryExtractorService(source);
      if (extractorUrl != null) {
        Logger.info(
          'ExtractorService resolved playable URL for ${source.name}',
        );
        return Right(extractorUrl);
      }

      // For embed URLs, fall back to extension-specific loadVideo
      Logger.info(
        'ExtractorService unavailable, falling back to extension load',
      );

      // Get the source extension from the server name
      final sourceExtension = _getSourceByServerName(source.server);
      if (sourceExtension == null) {
        Logger.warning(
          'Could not find extension for server: ${source.server}, returning embed URL',
        );
        // If we can't find the extension, return the embed URL
        // The video player might be able to handle it
        return Right(_sanitizeForPlayer(source.url));
      }

      try {
        // Create a Video object from the source
        final video = Video(
          source.name,
          source.url,
          source.quality,
          headers: source.headers,
        );

        // Use the extension's loadVideo method to extract the actual URL
        final methods = sourceExtension.methods;
        final extractedVideos = await methods.loadVideo(video, null);

        if (extractedVideos.isEmpty) {
          Logger.warning('No videos extracted, returning original URL');
          return Right(_sanitizeForPlayer(source.url));
        }

        // Return the first extracted video URL
        // Prefer higher quality if multiple are available
        final bestVideo = _selectBestQuality(extractedVideos);
        Logger.info(
          'Successfully extracted video URL with quality: ${bestVideo.quality}',
        );
        return Right(bestVideo.url);
      } catch (e) {
        Logger.warning(
          'Failed to extract video using extension: $e, returning original URL',
        );
        // If extraction fails, return the original URL (encoded if needed)
        // The video player might still be able to handle it
        return Right(_sanitizeForPlayer(source.url));
      }
    } on ValidationException catch (e) {
      Logger.error('Validation exception: ${e.message}');
      return Left(ValidationFailure(e.message));
    } catch (e) {
      Logger.error('Unexpected error extracting video URL: $e');
      return Left(
        UnknownFailure('Failed to extract video URL: ${e.toString()}'),
      );
    }
  }

  /// Get a source by server name
  dynamic _getSourceByServerName(String serverName) {
    if (extensionManager == null) {
      return null;
    }
    final extension = extensionManager!.currentManager;

    // Check all installed extension lists
    final allSources = [
      ...extension.installedAnimeExtensions.value,
      ...extension.installedMovieExtensions.value,
      ...extension.installedTvShowExtensions.value,
    ];

    try {
      // Try to find by exact server name match
      return allSources.firstWhere(
        (source) => source.name?.toLowerCase() == serverName.toLowerCase(),
      );
    } catch (e) {
      // If not found, return null
      return null;
    }
  }

  /// Select the best quality video from a list
  Video _selectBestQuality(List<Video> videos) {
    if (videos.length == 1) {
      return videos.first;
    }

    // Quality priority: 1080p > 720p > 480p > 360p > others
    final qualityPriority = {
      '1080p': 5,
      '1080': 5,
      '720p': 4,
      '720': 4,
      '480p': 3,
      '480': 3,
      '360p': 2,
      '360': 2,
    };

    Video? bestVideo;
    int bestPriority = -1;

    for (final video in videos) {
      final quality = video.quality.toLowerCase();
      final priority = qualityPriority[quality] ?? 0;

      if (priority > bestPriority) {
        bestPriority = priority;
        bestVideo = video;
      }
    }

    // If no priority match, return the first video
    return bestVideo ?? videos.first;
  }

  /// Check if a URL is a direct video URL
  bool _isDirectVideoUrl(String url) {
    final videoExtensions = ['.mp4', '.m3u8', '.mkv', '.webm', '.avi', '.mov'];

    final lowerUrl = url.toLowerCase();
    return videoExtensions.any((ext) => lowerUrl.contains(ext));
  }

  String _sanitizeForPlayer(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;
    final firstChar = trimmed[0];
    if (firstChar == '{' || firstChar == '[') {
      return CloudStreamUrlCodec.sanitize(trimmed) ?? trimmed;
    }
    return trimmed;
  }
}
