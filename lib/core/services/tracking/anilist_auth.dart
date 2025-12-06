/// AniList authentication service following AnymeX pattern
/// Handles OAuth2 flow and token management for AniList
///
/// CREDIT: Based on AnymeX's authentication pattern using FlutterWebAuth2
/// and GetX state management with Hive storage
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import '../../utils/logger.dart';
import '../../domain/entities/media_entity.dart';
import 'tracking_service_interface.dart';

/// Parameters for updating a list entry
class UpdateListEntryParams {
  final String id;
  final TrackingStatus? status;
  final int? progress;
  final double? score;

  const UpdateListEntryParams({
    required this.id,
    this.status,
    this.progress,
    this.score,
  });
}

class AnilistAuth extends GetxController {
  RxBool isLoggedIn = false.obs;
  Rx<TrackingUserProfile> profileData = TrackingUserProfile(
    id: '',
    username: '',
  ).obs;
  late final Box storage;

  AnilistAuth() {
    // Get the auth box from service locator (opened during DI initialization)
    final getIt = GetIt.instance;
    if (getIt.isRegistered<Box>(instanceName: 'authBox')) {
      storage = getIt<Box>(instanceName: 'authBox');
    } else {
      throw Exception(
        'Auth box not initialized. Make sure Hive boxes are opened before instantiating auth controllers.',
      );
    }
  }

  bool get isAuthenticated => storage.get('anilist_auth_token') != null;

  Rx<TrackingMediaItem> currentMedia = TrackingMediaItem(
    id: '',
    title: '',
    mediaType: MediaType.anime,
    serviceIds: {},
  ).obs;

  RxList<TrackingMediaItem> currentlyWatching = <TrackingMediaItem>[].obs;
  RxList<TrackingMediaItem> animeList = <TrackingMediaItem>[].obs;

  RxList<TrackingMediaItem> currentlyReading = <TrackingMediaItem>[].obs;
  RxList<TrackingMediaItem> mangaList = <TrackingMediaItem>[].obs;

  Future<void> tryAutoLogin() async {
    isLoggedIn.value = false;
    final token = await storage.get('anilist_auth_token');
    if (token != null) {
      await fetchUserProfile();
      await fetchUserAnimeList();
      await fetchUserMangaList();
    }
  }

  Future<void> login() async {
    String clientId = dotenv.env['ANILIST_CLIENT_ID'] ?? '';
    String clientSecret = dotenv.env['ANILIST_CLIENT_SECRET'] ?? '';
    String redirectUri = dotenv.env['CALLBACK_SCHEME'] ?? '';

    // Validate required environment variables
    if (clientId.isEmpty || clientSecret.isEmpty || redirectUri.isEmpty) {
      Logger.error(
        'AniList login failed: Missing required environment variables',
      );
      throw Exception(
        'AniList authentication not configured. Please check your environment variables.',
      );
    }

    final url =
        'https://anilist.co/api/v2/oauth/authorize?client_id=$clientId&redirect_uri=$redirectUri&response_type=code';

    try {
      final result = await FlutterWebAuth2.authenticate(
        url: url,
        callbackUrlScheme: 'aniya',
      );

      final code = Uri.parse(result).queryParameters['code'];
      if (code != null && code.isNotEmpty) {
        Logger.info("AniList authorization code received");
        await _exchangeCodeForToken(code, clientId, clientSecret, redirectUri);
      } else {
        Logger.error('AniList login failed: No authorization code received');
        throw Exception('Authorization failed: No code received from AniList');
      }
    } catch (e) {
      Logger.error('Error during AniList login', error: e);
      throw Exception('AniList login failed: ${e.toString()}');
    }
  }

  Future<void> _exchangeCodeForToken(
    String code,
    String clientId,
    String clientSecret,
    String redirectUri,
  ) async {
    // Validate input parameters
    if (code.isEmpty ||
        clientId.isEmpty ||
        clientSecret.isEmpty ||
        redirectUri.isEmpty) {
      throw Exception('Invalid parameters for token exchange');
    }

    try {
      final response = await http.post(
        Uri.parse('https://anilist.co/api/v2/oauth/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'authorization_code',
          'client_id': clientId,
          'client_secret': clientSecret,
          'redirect_uri': redirectUri,
          'code': code,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Validate response contains required token
        final token = data['access_token'];
        if (token == null || token.isEmpty) {
          throw Exception('Invalid token response: Missing access_token');
        }

        await storage.put('anilist_auth_token', token);
        Logger.info('AniList token stored successfully');

        // Fetch user data after successful authentication
        await fetchUserProfile();
        await fetchUserAnimeList();
        await fetchUserMangaList();
        isLoggedIn.value = true;
      } else {
        final errorData = json.decode(response.body);
        final errorMessage =
            errorData['error_description'] ??
            errorData['error'] ??
            'Unknown error';
        Logger.error(
          'AniList token exchange failed: ${response.statusCode} - $errorMessage',
        );
        throw Exception('Failed to exchange code for token: $errorMessage');
      }
    } catch (e) {
      if (e is FormatException) {
        Logger.error(
          'AniList token exchange failed: Invalid JSON response',
          error: e,
        );
        throw Exception('Invalid response from AniList server');
      } else if (e is http.ClientException) {
        Logger.error('AniList token exchange failed: Network error', error: e);
        throw Exception('Network error during authentication');
      } else {
        Logger.error('AniList token exchange failed', error: e);
        rethrow;
      }
    }
  }

  Future<void> fetchUserProfile() async {
    final token = await storage.get('anilist_auth_token');

    if (token == null) {
      Logger.info('No AniList token found');
      return;
    }

    final query = '''
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

    try {
      final response = await http.post(
        Uri.parse('https://graphql.anilist.co'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'query': query}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data']?['Viewer'] != null) {
          final viewer = data['data']['Viewer'];
          profileData.value = TrackingUserProfile(
            id: viewer['id']?.toString() ?? '',
            username: viewer['name']?.toString() ?? '',
            avatar: viewer['avatar']?['large']?.toString(),
          );
          isLoggedIn.value = true;
        }
      }
    } catch (e) {
      Logger.info('Error fetching AniList profile: $e');
    }
  }

  Future<void> fetchUserAnimeList() async {
    final token = await storage.get('anilist_auth_token');
    if (token == null) return;

    final query =
        '''
      query {
        MediaListCollection(userId: ${profileData.value.id}, type: ANIME) {
          lists {
            entries {
              media {
                id
                title {
                  romaji
                  english
                }
                coverImage {
                  large
                }
                status
              }
              progress
              score
              status
            }
          }
        }
      }
    ''';

    try {
      final response = await http.post(
        Uri.parse('https://graphql.anilist.co'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'query': query}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final lists =
            data['data']?['MediaListCollection']?['lists'] as List<dynamic>? ??
            [];

        animeList.clear();
        for (final list in lists) {
          final entries = list['entries'] as List<dynamic>? ?? [];
          for (final entry in entries) {
            final media = entry['media'];
            final title = media['title'];

            animeList.add(
              TrackingMediaItem(
                id: media['id'].toString(),
                title: title['romaji'] ?? title['english'] ?? 'Unknown Title',
                mediaType: MediaType.anime,
                coverImage: media['coverImage']?['large'],
                status: _mapAniListStatus(entry['status']),
                rating: entry['score']?.toDouble(),
                episodesWatched: entry['progress'],
                serviceIds: {},
              ),
            );
          }
        }
      }
    } catch (e) {
      Logger.info('Error fetching AniList anime list: $e');
    }
  }

  Future<void> fetchUserMangaList() async {
    final token = await storage.get('anilist_auth_token');
    if (token == null) return;

    final query =
        '''
      query {
        MediaListCollection(userId: ${profileData.value.id}, type: MANGA) {
          lists {
            entries {
              media {
                id
                title {
                  romaji
                  english
                }
                coverImage {
                  large
                }
                status
              }
              progress
              score
              status
            }
          }
        }
      }
    ''';

    try {
      final response = await http.post(
        Uri.parse('https://graphql.anilist.co'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'query': query}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final lists =
            data['data']?['MediaListCollection']?['lists'] as List<dynamic>? ??
            [];

        mangaList.clear();
        for (final list in lists) {
          final entries = list['entries'] as List<dynamic>? ?? [];
          for (final entry in entries) {
            final media = entry['media'];
            final title = media['title'];

            mangaList.add(
              TrackingMediaItem(
                id: media['id'].toString(),
                title: title['romaji'] ?? title['english'] ?? 'Unknown Title',
                mediaType: MediaType.manga,
                coverImage: media['coverImage']?['large'],
                status: _mapAniListStatus(entry['status']),
                rating: entry['score']?.toDouble(),
                chaptersRead: entry['progress'],
                serviceIds: {},
              ),
            );
          }
        }
      }
    } catch (e) {
      Logger.info('Error fetching AniList manga list: $e');
    }
  }

  TrackingStatus _mapAniListStatus(String? status) {
    switch (status) {
      case 'CURRENT':
        return TrackingStatus.watching;
      case 'COMPLETED':
        return TrackingStatus.completed;
      case 'PAUSED':
        return TrackingStatus.onHold;
      case 'DROPPED':
        return TrackingStatus.dropped;
      case 'PLANNING':
        return TrackingStatus.planning;
      default:
        return TrackingStatus.planning;
    }
  }

  Future<void> updateListEntry(UpdateListEntryParams params) async {
    final token = await storage.get('anilist_auth_token');
    if (token == null) return;

    final mutation = '''
      mutation (\$mediaId: Int, \$status: MediaListStatus, \$progress: Int, \$score: Float) {
        SaveMediaListEntry(mediaId: \$mediaId, status: \$status, progress: \$progress, score: \$score) {
          id
          status
          progress
          score
        }
      }
    ''';

    final Map<String, dynamic> variables = {
      'mediaId': int.parse(params.id),
      'progress': params.progress,
      'score': params.score,
    };

    if (params.status != null) {
      variables['status'] = _mapTrackingStatusToAniList(params.status!);
    }

    try {
      final response = await http.post(
        Uri.parse('https://graphql.anilist.co'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'query': mutation, 'variables': variables}),
      );

      if (response.statusCode == 200) {
        // Refresh the lists after update
        await fetchUserAnimeList();
        await fetchUserMangaList();
      }
    } catch (e) {
      Logger.info('Error updating AniList entry: $e');
    }
  }

  String _mapTrackingStatusToAniList(TrackingStatus status) {
    switch (status) {
      case TrackingStatus.watching:
        return 'CURRENT';
      case TrackingStatus.completed:
        return 'COMPLETED';
      case TrackingStatus.onHold:
        return 'PAUSED';
      case TrackingStatus.dropped:
        return 'DROPPED';
      case TrackingStatus.planning:
        return 'PLANNING';
    }
  }

  Future<void> deleteListEntry(String listId, {bool isAnime = true}) async {
    final token = await storage.get('anilist_auth_token');
    if (token == null) return;

    final mutation = '''
      mutation (\$mediaId: Int) {
        DeleteMediaListEntry(mediaId: \$mediaId) {
          deleted
        }
      }
    ''';

    try {
      final response = await http.post(
        Uri.parse('https://graphql.anilist.co'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'query': mutation,
          'variables': {'mediaId': int.parse(listId)},
        }),
      );

      if (response.statusCode == 200) {
        // Refresh the lists after deletion
        await fetchUserAnimeList();
        await fetchUserMangaList();
      }
    } catch (e) {
      Logger.info('Error deleting AniList entry: $e');
    }
  }

  Future<void> logout() async {
    await storage.delete('anilist_auth_token');
    isLoggedIn.value = false;
    profileData.value = TrackingUserProfile(id: '', username: '');
    animeList.clear();
    mangaList.clear();
    currentlyWatching.clear();
    currentlyReading.clear();
  }
}
