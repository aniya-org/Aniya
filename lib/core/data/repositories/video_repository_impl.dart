import 'package:aniya/core/extractor/local_extractor_service.dart';
import 'package:aniya/core/extractor/models/extractor_request.dart';
import 'package:aniya/core/extractor/models/raw_stream.dart';
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
  final LocalExtractorService? localExtractorService;

  VideoRepositoryImpl({
    this.extensionManager,
    LocalExtractorService? localExtractorService,
  }) : localExtractorService = localExtractorService;

  final ExtractorService _bridgeExtractorService = ExtractorService();

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

  Future<String?> _tryBridgeExtractorService(
    VideoSource source, {
    String? overrideUrl,
  }) async {
    try {
      if (!await _bridgeExtractorService.isInitialized) {
        final initialized = await _bridgeExtractorService.initialize();
        if (!initialized) {
          Logger.warning('ExtractorService failed to initialize');
          return null;
        }
      }

      final referer = source.headers?['referer'] ?? source.headers?['Referer'];
      final ExtractorResult result = await _bridgeExtractorService.extract(
        overrideUrl ?? source.url,
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

        // CloudStream servers may return raw JSON payloads; sanitize to csjson://
        final sanitizedUrl =
            CloudStreamUrlCodec.sanitize(server.embed!.url) ??
            server.embed!.url;

        // Create a video source for each server
        final mergedHeaders = <String, String>{
          if (server.embed?.headers != null) ...server.embed!.headers!,
          // Preserve extension identity for downstream extraction
          'x-extension-id': source.id ?? '',
          if (source.name != null) 'x-extension-name': source.name!,
        };

        final videoSource = VideoSourceModel(
          id: '${episodeId}_${server.name ?? i}',
          name: server.name ?? 'Server ${i + 1}',
          url: sanitizedUrl,
          quality: 'Auto', // Quality will be determined during extraction
          server: server.name ?? 'Unknown',
          headers: mergedHeaders,
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

      // Decode CloudStream csjson payloads before any further handling
      final rawUrl = source.url;
      final isCsjson = rawUrl.startsWith(CloudStreamUrlCodec.prefix);
      final decodedUrl = isCsjson
          ? CloudStreamUrlCodec.desanitize(rawUrl)
          : rawUrl;
      final isJsonPayload = isCsjson || _isJsonPayload(decodedUrl);

      // Check if URL is already a direct video URL
      if (_isDirectVideoUrl(decodedUrl)) {
        Logger.info('URL is already a direct video URL: $decodedUrl');
        return Right(decodedUrl);
      }

      if (isJsonPayload) {
        // CloudStream JSON payloads should be handled by the originating extension
        final extensionId = source.headers?['x-extension-id'];
        final sourceExtension = extensionId != null && extensionId.isNotEmpty
            ? _getSourceById(extensionId)
            : _getSourceByServerName(source.server);

        if (sourceExtension == null) {
          Logger.warning(
            'No extension found for CloudStream payload server: ${source.server}',
            tag: 'VideoRepositoryImpl',
          );
          return Left(
            ExtensionFailure(
              'No extension found for CloudStream payload server: ${source.server}',
            ),
          );
        }

        try {
          final video = Video(
            source.name,
            decodedUrl,
            source.quality,
            headers: source.headers,
          );
          final methods = sourceExtension.methods;
          final extractedVideos = await methods.loadVideo(video, null);

          if (extractedVideos.isEmpty) {
            Logger.warning(
              'Extension returned no videos for CloudStream payload',
              tag: 'VideoRepositoryImpl',
            );
            return Left(
              ServerFailure('No videos extracted from CloudStream payload'),
            );
          }

          final bestVideo = _selectBestQuality(extractedVideos);
          Logger.info(
            'Extension resolved CloudStream payload with quality: ${bestVideo.quality}',
            tag: 'VideoRepositoryImpl',
          );
          return Right(bestVideo.url);
        } catch (e, stack) {
          Logger.error(
            'Extension loadVideo failed for CloudStream payload',
            tag: 'VideoRepositoryImpl',
            error: e,
            stackTrace: stack,
          );
          return Left(
            UnknownFailure(
              'Failed to extract CloudStream payload: ${e.toString()}',
            ),
          );
        }
      } else {
        // Try the built-in Dart extractor catalogue first (only for real URLs)
        final localUrl = await _tryLocalExtractorService(
          source,
          overrideUrl: decodedUrl,
        );
        if (localUrl != null) {
          Logger.info(
            'Local extractor resolved playable URL for ${source.name}',
          );
          return Right(localUrl);
        }

        // Fall back to the CloudStream bridge extractor if needed.
        final bridgeUrl = await _tryBridgeExtractorService(
          source,
          overrideUrl: decodedUrl,
        );
        if (bridgeUrl != null) {
          Logger.info(
            'Bridge ExtractorService resolved playable URL for ${source.name}',
          );
          return Right(bridgeUrl);
        }
      }

      // For embed URLs, fall back to extension-specific loadVideo
      Logger.info(
        'ExtractorService unavailable, falling back to extension load',
      );

      // Try to locate the originating extension using embedded metadata
      final extensionId = source.headers?['x-extension-id'];
      final sourceExtension = extensionId != null && extensionId.isNotEmpty
          ? _getSourceById(extensionId)
          : _getSourceByServerName(source.server);
      if (sourceExtension == null) {
        Logger.warning(
          'Could not find extension for server: ${source.server}, returning embed URL',
        );
        // If we can't find the extension, return the embed URL
        // The video player might be able to handle it
        return Right(
          _sanitizeForPlayer(isJsonPayload ? source.url : decodedUrl),
        );
      }

      try {
        // Create a Video object from the source
        final video = Video(
          source.name,
          decodedUrl,
          source.quality,
          headers: source.headers,
        );

        // Use the extension's loadVideo method to extract the actual URL
        final methods = sourceExtension.methods;
        final extractedVideos = await methods.loadVideo(video, null);

        if (extractedVideos.isEmpty) {
          Logger.warning('No videos extracted, returning original URL');
          return Right(_sanitizeForPlayer(decodedUrl));
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
        return Right(_sanitizeForPlayer(decodedUrl));
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

  /// Stores extracted headers from local extractor for later use by the player
  Map<String, String>? _lastExtractedHeaders;

  Future<String?> _tryLocalExtractorService(
    VideoSource source, {
    String? overrideUrl,
  }) async {
    final service = localExtractorService;
    if (service == null) {
      return null;
    }

    final uri = Uri.tryParse(overrideUrl ?? source.url);
    if (uri == null) {
      Logger.warning(
        'Unable to parse URL for local extraction: ${overrideUrl ?? source.url}',
        tag: 'VideoRepositoryImpl',
      );
      return null;
    }

    final request = ExtractorRequest(
      url: uri,
      category: ExtractorCategory.video,
      mediaTitle: source.name,
      serverName: source.server,
      referer: source.headers?['referer'] ?? source.headers?['Referer'],
      headers: source.headers,
    );

    final streams = await service.extract(request);
    if (streams.isEmpty) {
      return null;
    }

    final bestStream = _selectBestLocalStream(streams);
    if (bestStream == null) {
      return null;
    }

    // Store extracted headers for propagation to player
    if (bestStream.headers != null && bestStream.headers!.isNotEmpty) {
      _lastExtractedHeaders = bestStream.headers;
      Logger.debug(
        'Local extractor produced headers for player: ${bestStream.headers}',
        tag: 'VideoRepositoryImpl',
      );
    }

    return bestStream.url.toString();
  }

  /// Get the last extracted headers from local extractor
  /// These should be used when playing the extracted URL
  Map<String, String>? getLastExtractedHeaders() => _lastExtractedHeaders;

  RawStream? _selectBestLocalStream(List<RawStream> streams) {
    if (streams.isEmpty) return null;

    const qualityPriority = {
      '1080p': 5,
      '1080': 5,
      '720p': 4,
      '720': 4,
      '480p': 3,
      '480': 3,
      '360p': 2,
      '360': 2,
      'auto': 1,
    };

    RawStream? best;
    int bestScore = -1;

    for (final stream in streams) {
      final qualityKey = stream.quality?.toLowerCase().trim();
      int score = 0;
      if (qualityKey != null && qualityPriority.containsKey(qualityKey)) {
        score = qualityPriority[qualityKey]!;
      } else {
        final numericMatch = RegExp(
          r'(\d{3,4})',
        ).firstMatch(stream.quality ?? '')?.group(0);
        if (numericMatch != null) {
          score = int.tryParse(numericMatch) ?? 0;
        } else if (stream.isM3u8) {
          score = 1;
        }
      }

      if (score > bestScore) {
        bestScore = score;
        best = stream;
      }
    }

    return best ?? streams.first;
  }

  /// Check if a URL is a direct video URL
  bool _isDirectVideoUrl(String url) {
    final videoExtensions = ['.mp4', '.m3u8', '.mkv', '.webm', '.avi', '.mov'];

    final lowerUrl = url.toLowerCase();
    final hasVideoExtension = videoExtensions.any(
      (ext) => lowerUrl.contains(ext),
    );
    final containsQueryVideoParam =
        lowerUrl.contains('mime=video') || lowerUrl.contains('type=video');

    return hasVideoExtension || containsQueryVideoParam;
  }

  /// Detects if the decoded URL is a JSON payload (CloudStream csjson)
  bool _isJsonPayload(String value) {
    if (value.startsWith(CloudStreamUrlCodec.prefix)) return true;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    final first = trimmed[0];
    return first == '{' || first == '[';
  }

  String _sanitizeForPlayer(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;
    if (_isJsonPayload(trimmed)) {
      return CloudStreamUrlCodec.sanitize(trimmed) ?? trimmed;
    }
    return trimmed;
  }
}
