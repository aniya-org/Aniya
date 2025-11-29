import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/user_model.dart';
import '../models/library_item_model.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/entities/library_item_entity.dart';
import '../../error/exceptions.dart';

/// Data source for tracking service integrations (AniList, MAL, Simkl)
abstract class TrackingDataSource {
  /// Authenticate with a tracking service
  Future<UserModel> authenticate(TrackingService service, String token);

  /// Sync progress to a tracking service
  Future<void> syncProgress(
    TrackingService service,
    String mediaId,
    int episode,
    int chapter,
  );

  /// Fetch user's library from a tracking service
  Future<List<LibraryItemModel>> fetchRemoteLibrary(TrackingService service);

  /// Update status on a tracking service
  Future<void> updateStatus(
    TrackingService service,
    String mediaId,
    LibraryStatus status,
  );

  /// Store authentication token securely
  Future<void> storeToken(TrackingService service, String token);

  /// Retrieve authentication token
  Future<String?> getToken(TrackingService service);

  /// Clear authentication token
  Future<void> clearToken(TrackingService service);
}

class TrackingDataSourceImpl implements TrackingDataSource {
  final Dio dio;
  final FlutterSecureStorage secureStorage;

  // API endpoints
  static const String _anilistEndpoint = 'https://graphql.anilist.co';
  static const String _malEndpoint = 'https://api.myanimelist.net/v2';
  static const String _simklEndpoint = 'https://api.simkl.com';

  TrackingDataSourceImpl({required this.dio, required this.secureStorage});

  String _getTokenKey(TrackingService service) {
    return 'tracking_token_${service.name}';
  }

  @override
  Future<void> storeToken(TrackingService service, String token) async {
    try {
      await secureStorage.write(key: _getTokenKey(service), value: token);
    } catch (e) {
      throw CacheException('Failed to store token: ${e.toString()}');
    }
  }

  @override
  Future<String?> getToken(TrackingService service) async {
    try {
      return await secureStorage.read(key: _getTokenKey(service));
    } catch (e) {
      throw CacheException('Failed to get token: ${e.toString()}');
    }
  }

  @override
  Future<void> clearToken(TrackingService service) async {
    try {
      await secureStorage.delete(key: _getTokenKey(service));
    } catch (e) {
      throw CacheException('Failed to clear token: ${e.toString()}');
    }
  }

  @override
  Future<UserModel> authenticate(TrackingService service, String token) async {
    try {
      await storeToken(service, token);

      switch (service) {
        case TrackingService.anilist:
          return await _authenticateAniList(token);
        case TrackingService.mal:
          return await _authenticateMAL(token);
        case TrackingService.simkl:
          return await _authenticateSimkl(token);
        case TrackingService.jikan:
          throw ServerException('Jikan does not require authentication');
      }
    } catch (e) {
      throw ServerException('Failed to authenticate: ${e.toString()}');
    }
  }

  Future<UserModel> _authenticateAniList(String token) async {
    const query = '''
      query {
        Viewer {
          id
          name
          avatar {
            large
          }
        }
      }
    ''';

    final response = await dio.post(
      _anilistEndpoint,
      data: {'query': query},
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    final data = response.data['data']['Viewer'];
    return UserModel(
      id: data['id'].toString(),
      username: data['name'],
      avatarUrl: data['avatar']?['large'],
      service: TrackingService.anilist,
    );
  }

  Future<UserModel> _authenticateMAL(String token) async {
    final response = await dio.get(
      '$_malEndpoint/users/@me',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );

    final data = response.data;
    return UserModel(
      id: data['id'].toString(),
      username: data['name'],
      avatarUrl: data['picture'],
      service: TrackingService.mal,
    );
  }

  Future<UserModel> _authenticateSimkl(String token) async {
    final response = await dio.get(
      '$_simklEndpoint/users/settings',
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'simkl-api-key': 'YOUR_SIMKL_API_KEY', // TODO: Add to config
        },
      ),
    );

    final data = response.data['user'];
    return UserModel(
      id: data['id'].toString(),
      username: data['name'],
      avatarUrl: data['avatar'],
      service: TrackingService.simkl,
    );
  }

  @override
  Future<void> syncProgress(
    TrackingService service,
    String mediaId,
    int episode,
    int chapter,
  ) async {
    try {
      final token = await getToken(service);
      if (token == null) {
        throw AuthenticationException('Not authenticated with $service');
      }

      switch (service) {
        case TrackingService.anilist:
          await _syncProgressAniList(token, mediaId, episode, chapter);
          break;
        case TrackingService.mal:
          await _syncProgressMAL(token, mediaId, episode, chapter);
          break;
        case TrackingService.simkl:
          await _syncProgressSimkl(token, mediaId, episode, chapter);
          break;
        case TrackingService.jikan:
          throw ServerException('Jikan does not support progress sync');
      }
    } catch (e) {
      throw ServerException('Failed to sync progress: ${e.toString()}');
    }
  }

  Future<void> _syncProgressAniList(
    String token,
    String mediaId,
    int episode,
    int chapter,
  ) async {
    const mutation = '''
      mutation(\$mediaId: Int, \$progress: Int, \$progressVolumes: Int) {
        SaveMediaListEntry(mediaId: \$mediaId, progress: \$progress, progressVolumes: \$progressVolumes) {
          id
        }
      }
    ''';

    await dio.post(
      _anilistEndpoint,
      data: {
        'query': mutation,
        'variables': {
          'mediaId': int.tryParse(mediaId),
          'progress': episode > 0 ? episode : chapter,
          'progressVolumes': chapter > 0 ? chapter : null,
        },
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
  }

  Future<void> _syncProgressMAL(
    String token,
    String mediaId,
    int episode,
    int chapter,
  ) async {
    final endpoint = episode > 0
        ? '$_malEndpoint/anime/$mediaId/my_list_status'
        : '$_malEndpoint/manga/$mediaId/my_list_status';

    await dio.patch(
      endpoint,
      data: {
        if (episode > 0) 'num_watched_episodes': episode,
        if (chapter > 0) 'num_chapters_read': chapter,
      },
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  Future<void> _syncProgressSimkl(
    String token,
    String mediaId,
    int episode,
    int chapter,
  ) async {
    // Simkl implementation
    // Note: This is a simplified implementation
    await dio.post(
      '$_simklEndpoint/sync/history',
      data: {
        'shows': [
          {
            'ids': {'simkl': int.tryParse(mediaId)},
            'episodes': [
              {'number': episode},
            ],
          },
        ],
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'simkl-api-key': 'YOUR_SIMKL_API_KEY', // TODO: Add to config
        },
      ),
    );
  }

  @override
  Future<List<LibraryItemModel>> fetchRemoteLibrary(
    TrackingService service,
  ) async {
    try {
      final token = await getToken(service);
      if (token == null) {
        throw AuthenticationException('Not authenticated with $service');
      }

      switch (service) {
        case TrackingService.anilist:
          return await _fetchLibraryAniList(token);
        case TrackingService.mal:
          return await _fetchLibraryMAL(token);
        case TrackingService.simkl:
          return await _fetchLibrarySimkl(token);
        case TrackingService.jikan:
          throw ServerException('Jikan does not support library fetch');
      }
    } catch (e) {
      throw ServerException('Failed to fetch remote library: ${e.toString()}');
    }
  }

  Future<List<LibraryItemModel>> _fetchLibraryAniList(String token) async {
    // Simplified implementation - would need pagination in production
    const query = '''
      query {
        MediaListCollection(userId: null, type: ANIME) {
          lists {
            entries {
              id
              mediaId
              status
              progress
              media {
                id
                title {
                  romaji
                }
                coverImage {
                  large
                }
              }
            }
          }
        }
      }
    ''';

    await dio.post(
      _anilistEndpoint,
      data: {'query': query},
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Parse and convert to LibraryItemModel
    // This is a simplified implementation
    return [];
  }

  Future<List<LibraryItemModel>> _fetchLibraryMAL(String token) async {
    // Simplified implementation
    return [];
  }

  Future<List<LibraryItemModel>> _fetchLibrarySimkl(String token) async {
    // Simplified implementation
    return [];
  }

  @override
  Future<void> updateStatus(
    TrackingService service,
    String mediaId,
    LibraryStatus status,
  ) async {
    try {
      final token = await getToken(service);
      if (token == null) {
        throw AuthenticationException('Not authenticated with $service');
      }

      switch (service) {
        case TrackingService.anilist:
          await _updateStatusAniList(token, mediaId, status);
          break;
        case TrackingService.mal:
          await _updateStatusMAL(token, mediaId, status);
          break;
        case TrackingService.simkl:
          await _updateStatusSimkl(token, mediaId, status);
          break;
        case TrackingService.jikan:
          throw ServerException('Jikan does not support status update');
      }
    } catch (e) {
      throw ServerException('Failed to update status: ${e.toString()}');
    }
  }

  Future<void> _updateStatusAniList(
    String token,
    String mediaId,
    LibraryStatus status,
  ) async {
    const mutation = '''
      mutation(\$mediaId: Int, \$status: MediaListStatus) {
        SaveMediaListEntry(mediaId: \$mediaId, status: \$status) {
          id
        }
      }
    ''';

    await dio.post(
      _anilistEndpoint,
      data: {
        'query': mutation,
        'variables': {
          'mediaId': int.tryParse(mediaId),
          'status': _mapStatusToAniList(status),
        },
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
  }

  Future<void> _updateStatusMAL(
    String token,
    String mediaId,
    LibraryStatus status,
  ) async {
    await dio.patch(
      '$_malEndpoint/anime/$mediaId/my_list_status',
      data: {'status': _mapStatusToMAL(status)},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  Future<void> _updateStatusSimkl(
    String token,
    String mediaId,
    LibraryStatus status,
  ) async {
    // Simkl implementation
  }

  String _mapStatusToAniList(LibraryStatus status) {
    switch (status) {
      case LibraryStatus.currentlyWatching:
      case LibraryStatus.watching:
        return 'CURRENT';
      case LibraryStatus.completed:
      case LibraryStatus.finished:
      case LibraryStatus.watched:
        return 'COMPLETED';
      case LibraryStatus.onHold:
        return 'PAUSED';
      case LibraryStatus.dropped:
        return 'DROPPED';
      case LibraryStatus.planToWatch:
      case LibraryStatus.wantToWatch:
        return 'PLANNING';
    }
  }

  String _mapStatusToMAL(LibraryStatus status) {
    switch (status) {
      case LibraryStatus.currentlyWatching:
      case LibraryStatus.watching:
        return 'watching';
      case LibraryStatus.completed:
      case LibraryStatus.finished:
      case LibraryStatus.watched:
        return 'completed';
      case LibraryStatus.onHold:
        return 'on_hold';
      case LibraryStatus.dropped:
        return 'dropped';
      case LibraryStatus.planToWatch:
      case LibraryStatus.wantToWatch:
        return 'plan_to_watch';
    }
  }
}
