import '../../domain/entities/media_entity.dart';

abstract class ExternalMediaDataSource {
  /// Search for media
  Future<List<MediaEntity>> searchMedia(
    String query,
    MediaType type, {
    int page = 1,
  });

  /// Get trending media
  Future<List<MediaEntity>> getTrending(MediaType type, {int page = 1});

  /// Get popular media
  Future<List<MediaEntity>> getPopular(MediaType type, {int page = 1});
}

enum ExternalSource { tmdb, anilist, jikan, simkl }
