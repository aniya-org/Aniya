import 'package:dio/dio.dart';

import '../../error/exceptions.dart';
import '../../utils/logger.dart';

/// Data source for MyAnimeList official API.
///
/// This data source requires user authentication and is used as a fallback
/// when Jikan (unofficial MAL API) doesn't have complete data.
///
/// API Documentation: https://myanimelist.net/apiconfig/references/api/v2
class MalExternalDataSourceImpl {
  late final Dio _dio;

  MalExternalDataSourceImpl() {
    _dio = Dio();
    _dio.options.baseUrl = 'https://api.myanimelist.net/v2';
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);
  }

  /// Get the chapter count for a manga from MAL's official API.
  ///
  /// [malId] - The MyAnimeList manga ID
  /// [accessToken] - A valid MAL access token
  ///
  /// Returns the number of chapters, or null if not available.
  ///
  /// Throws:
  /// - [MalAuthExpiredException] if the token is expired (401)
  /// - [RateLimitException] if rate limited (429)
  /// - [ServerException] for other errors
  Future<int?> getChapterCount(String malId, String accessToken) async {
    try {
      Logger.info(
        'Fetching chapter count from MAL for manga $malId',
        tag: 'MalExternalDataSource',
      );

      final response = await _dio.get(
        '/manga/$malId',
        queryParameters: {'fields': 'num_chapters,num_volumes,status'},
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );

      final data = response.data as Map<String, dynamic>;
      final numChapters = data['num_chapters'] as int?;

      Logger.info(
        'MAL manga $malId has $numChapters chapters',
        tag: 'MalExternalDataSource',
      );

      return numChapters;
    } on DioException catch (e) {
      return _handleDioError(e, malId);
    } catch (e, stackTrace) {
      Logger.error(
        'Error fetching chapter count from MAL for manga $malId',
        tag: 'MalExternalDataSource',
        error: e,
        stackTrace: stackTrace,
      );
      throw ServerException('Failed to get MAL chapter count: $e');
    }
  }

  /// Get manga details from MAL's official API.
  ///
  /// [malId] - The MyAnimeList manga ID
  /// [accessToken] - A valid MAL access token
  ///
  /// Returns a map with manga details including chapters, volumes, status, etc.
  Future<Map<String, dynamic>?> getMangaDetails(
    String malId,
    String accessToken,
  ) async {
    try {
      Logger.info(
        'Fetching manga details from MAL for manga $malId',
        tag: 'MalExternalDataSource',
      );

      final response = await _dio.get(
        '/manga/$malId',
        queryParameters: {
          'fields':
              'id,title,main_picture,alternative_titles,start_date,end_date,'
              'synopsis,mean,rank,popularity,num_list_users,num_scoring_users,'
              'nsfw,created_at,updated_at,media_type,status,genres,num_chapters,'
              'num_volumes,authors{first_name,last_name},pictures,background,'
              'related_anime,related_manga,recommendations,serialization',
        },
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _handleDioError(e, malId);
      return null;
    } catch (e, stackTrace) {
      Logger.error(
        'Error fetching manga details from MAL for manga $malId',
        tag: 'MalExternalDataSource',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Get anime details from MAL's official API.
  ///
  /// [malId] - The MyAnimeList anime ID
  /// [accessToken] - A valid MAL access token
  ///
  /// Returns a map with anime details including episodes, status, etc.
  Future<Map<String, dynamic>?> getAnimeDetails(
    String malId,
    String accessToken,
  ) async {
    try {
      Logger.info(
        'Fetching anime details from MAL for anime $malId',
        tag: 'MalExternalDataSource',
      );

      final response = await _dio.get(
        '/anime/$malId',
        queryParameters: {
          'fields':
              'id,title,main_picture,alternative_titles,start_date,end_date,'
              'synopsis,mean,rank,popularity,num_list_users,num_scoring_users,'
              'nsfw,created_at,updated_at,media_type,status,genres,num_episodes,'
              'start_season,broadcast,source,average_episode_duration,rating,'
              'pictures,background,related_anime,related_manga,recommendations,'
              'studios,statistics',
        },
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _handleDioError(e, malId);
      return null;
    } catch (e, stackTrace) {
      Logger.error(
        'Error fetching anime details from MAL for anime $malId',
        tag: 'MalExternalDataSource',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Get the episode count for an anime from MAL's official API.
  ///
  /// [malId] - The MyAnimeList anime ID
  /// [accessToken] - A valid MAL access token
  ///
  /// Returns the number of episodes, or null if not available.
  Future<int?> getEpisodeCount(String malId, String accessToken) async {
    try {
      Logger.info(
        'Fetching episode count from MAL for anime $malId',
        tag: 'MalExternalDataSource',
      );

      final response = await _dio.get(
        '/anime/$malId',
        queryParameters: {'fields': 'num_episodes,status'},
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );

      final data = response.data as Map<String, dynamic>;
      final numEpisodes = data['num_episodes'] as int?;

      Logger.info(
        'MAL anime $malId has $numEpisodes episodes',
        tag: 'MalExternalDataSource',
      );

      return numEpisodes;
    } on DioException catch (e) {
      return _handleDioError(e, malId);
    } catch (e, stackTrace) {
      Logger.error(
        'Error fetching episode count from MAL for anime $malId',
        tag: 'MalExternalDataSource',
        error: e,
        stackTrace: stackTrace,
      );
      throw ServerException('Failed to get MAL episode count: $e');
    }
  }

  /// Handle Dio errors and convert to appropriate exceptions.
  int? _handleDioError(DioException e, String malId) {
    final statusCode = e.response?.statusCode;

    switch (statusCode) {
      case 401:
        Logger.warning(
          'MAL token expired for request to manga $malId',
          tag: 'MalExternalDataSource',
        );
        throw const MalAuthExpiredException();

      case 403:
        Logger.warning(
          'MAL access forbidden for manga $malId',
          tag: 'MalExternalDataSource',
        );
        throw const ServerException('MAL access forbidden');

      case 404:
        Logger.info('MAL manga $malId not found', tag: 'MalExternalDataSource');
        return null;

      case 429:
        // Parse retry-after header if available
        final retryAfter = e.response?.headers.value('retry-after');
        final retryDuration = retryAfter != null
            ? Duration(seconds: int.tryParse(retryAfter) ?? 60)
            : const Duration(seconds: 60);

        Logger.warning(
          'MAL rate limit exceeded, retry after: $retryDuration',
          tag: 'MalExternalDataSource',
        );
        throw RateLimitException('MAL rate limit exceeded', retryDuration);

      default:
        Logger.error(
          'MAL API error for manga $malId: ${e.message}',
          tag: 'MalExternalDataSource',
          error: e,
        );
        throw ServerException('MAL API error: ${e.message}');
    }
  }
}
