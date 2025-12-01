import 'dart:io';
import 'package:get_it/get_it.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:isar_community/isar.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dartotsu_extension_bridge/ExtensionManager.dart';
import 'package:path_provider/path_provider.dart';
import '../domain/services/offline_storage_manager.dart';
import '../domain/services/lazy_extension_loader.dart';
import '../services/data_migration_service.dart';
import '../services/tracking_auth_service.dart';
import '../services/extension_discovery_service.dart';
import '../services/permission_service.dart';
import '../services/tmdb_service.dart';
import '../services/cloudstream_service.dart';
import '../services/deep_link_handler.dart';
import '../domain/repositories/download_repository.dart';
import '../domain/repositories/media_repository.dart';
import '../domain/repositories/library_repository.dart';
import '../domain/repositories/extension_repository.dart';
import '../domain/repositories/video_repository.dart';
import '../domain/repositories/tracking_repository.dart';
import '../domain/repositories/tracking_auth_repository.dart';
import '../domain/repositories/repository_repository.dart';
import '../data/repositories/download_repository_impl.dart';
import '../data/repositories/media_repository_impl.dart';
import '../data/repositories/library_repository_impl.dart';
import '../data/repositories/extension_repository_impl.dart';
import '../data/repositories/video_repository_impl.dart';
import '../data/repositories/tracking_repository_impl.dart';
import '../data/repositories/tracking_auth_repository_impl.dart';
import '../data/repositories/repository_repository_impl.dart';
import '../data/datasources/download_local_data_source.dart';
import '../data/datasources/media_remote_data_source.dart';
import '../data/datasources/media_local_data_source.dart';
import '../data/datasources/library_local_data_source.dart';
import '../data/datasources/extension_data_source.dart';
import '../data/datasources/external_remote_data_source.dart';
import '../data/datasources/tmdb_external_data_source.dart';
import '../data/datasources/anilist_external_data_source.dart';
import '../data/datasources/simkl_external_data_source.dart';
import '../data/datasources/kitsu_external_data_source.dart';
import '../data/datasources/tracking_data_source.dart';
import '../data/datasources/jikan_external_data_source.dart';
import '../data/datasources/mal_external_data_source.dart';
import '../data/datasources/repository_local_data_source.dart';
import '../data/datasources/watch_history_local_data_source.dart';
import '../domain/repositories/watch_history_repository.dart';
import '../data/repositories/watch_history_repository_impl.dart';
import '../services/watch_history_controller.dart';
import '../domain/usecases/get_trending_media_usecase.dart';
import '../domain/usecases/get_popular_media_usecase.dart';
import '../domain/usecases/get_library_items_usecase.dart';
import '../domain/usecases/search_media_usecase.dart';
import '../domain/usecases/get_available_extensions_usecase.dart';
import '../domain/usecases/get_installed_extensions_usecase.dart';
import '../domain/usecases/install_extension_usecase.dart';
import '../domain/usecases/uninstall_extension_usecase.dart';
import '../domain/usecases/get_video_sources_usecase.dart';
import '../domain/usecases/extract_video_url_usecase.dart';
import '../domain/usecases/save_playback_position_usecase.dart';
import '../domain/usecases/get_playback_position_usecase.dart';
import '../domain/usecases/update_progress_usecase.dart';
import '../domain/usecases/update_library_item_usecase.dart';
import '../domain/usecases/remove_from_library_usecase.dart';
import '../domain/usecases/get_media_details_usecase.dart';
import '../domain/usecases/get_episodes_usecase.dart';
import '../domain/usecases/get_chapters_usecase.dart';
import '../domain/usecases/get_chapter_pages_usecase.dart';
import '../domain/usecases/save_reading_position_usecase.dart';
import '../domain/usecases/get_reading_position_usecase.dart';
import '../domain/usecases/add_to_library_usecase.dart';
import '../domain/usecases/authenticate_tracking_service_usecase.dart';
import '../../features/home/presentation/viewmodels/home_viewmodel.dart';
import '../../features/home/presentation/viewmodels/browse_viewmodel.dart';
import '../../features/search/presentation/viewmodels/search_viewmodel.dart';
import '../../features/library/presentation/viewmodels/library_viewmodel.dart';
import '../../features/extensions/controllers/extensions_controller.dart';
import '../../features/settings/presentation/viewmodels/settings_viewmodel.dart';
import '../../features/media_details/presentation/viewmodels/media_details_viewmodel.dart';
import '../../features/media_details/presentation/viewmodels/episode_source_selection_viewmodel.dart';
import '../../features/manga_reader/presentation/viewmodels/manga_reader_viewmodel.dart';
import '../../features/auth/presentation/viewmodels/auth_viewmodel.dart';
import '../domain/repositories/extension_search_repository.dart';
import '../domain/repositories/recent_extensions_repository.dart';
import '../data/repositories/extension_search_repository_impl.dart';
import '../data/repositories/recent_extensions_repository_impl.dart';
import '../utils/provider_cache.dart';
import '../utils/cross_provider_matcher.dart';
import '../utils/data_aggregator.dart';
import '../utils/retry_handler.dart';
import '../utils/provider_priority_config.dart';

final sl = GetIt.instance;

/// Initialize all dependencies
Future<void> initializeDependencies() async {
  // Initialize Hive using a deterministic application directory so desktop builds
  // don't try to write into the project root (which causes locking errors).
  final storageDir = await _resolveAppStorageDirectory();
  await Hive.initFlutter(storageDir.path);

  // Initialize Isar
  // Note: Isar requires at least one collection schema to open
  // Since we don't have any collections defined in the main app,
  // we skip Isar initialization. Collections from DartotsuExtensionBridge
  // are managed separately by the extension manager.
  // If Isar is needed in the future, add collection schemas here.

  // Register Hive (only if not already registered)
  if (!sl.isRegistered<HiveInterface>()) {
    sl.registerLazySingleton<HiveInterface>(() => Hive);
  }

  // Open and register settings box
  final settingsBox = await Hive.openBox('settings');
  sl.registerSingleton<Box>(settingsBox, instanceName: 'settingsBox');

  // Open and register themeData box (used for extension repo preferences)
  final themeDataBox = await Hive.openBox('themeData');
  sl.registerSingleton<Box>(themeDataBox, instanceName: 'themeDataBox');

  // Initialize GetX ExtensionsController (port of AnymeX SourceController)
  final extensionsController = ExtensionsController(themeBox: themeDataBox);
  if (!Get.isRegistered<ExtensionsController>()) {
    Get.put<ExtensionsController>(extensionsController, permanent: true);
  }
  if (!sl.isRegistered<ExtensionsController>()) {
    sl.registerSingleton<ExtensionsController>(extensionsController);
  }

  // Register SharedPreferences
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerSingleton<SharedPreferences>(sharedPreferences);

  // Register and initialize ProviderCache
  final providerCache = ProviderCache();
  await providerCache.init();
  sl.registerSingleton<ProviderCache>(providerCache);

  // Register cross-provider aggregation utilities
  sl.registerLazySingleton<RetryHandler>(() => RetryHandler());
  sl.registerLazySingleton<ProviderPriorityConfig>(
    () => ProviderPriorityConfig.defaultConfig(),
  );
  sl.registerLazySingleton<CrossProviderMatcher>(
    () => CrossProviderMatcher(retryHandler: sl<RetryHandler>()),
  );
  sl.registerLazySingleton<DataAggregator>(
    () => DataAggregator(
      priorityConfig: sl<ProviderPriorityConfig>(),
      retryHandler: sl<RetryHandler>(),
    ),
  );

  // Register LazyExtensionLoader for on-demand extension loading
  sl.registerLazySingleton<LazyExtensionLoader>(() => LazyExtensionLoader());

  // Register ExtensionDiscoveryService for discovering installed extensions (Task 12)
  sl.registerLazySingleton<ExtensionDiscoveryService>(
    () => ExtensionDiscoveryService(lazyLoader: sl<LazyExtensionLoader>()),
  );

  // Register PermissionService for handling app permissions
  sl.registerLazySingleton<PermissionService>(() => PermissionService());

  // Register TMDB Service
  sl.registerLazySingleton<TmdbService>(() => TmdbService());

  // Register HTTP Client for CloudStream Service
  // This is registered before CloudStreamService so it can be injected
  if (!sl.isRegistered<http.Client>()) {
    sl.registerLazySingleton<http.Client>(() => http.Client());
  }

  // Register CloudStream Service
  sl.registerLazySingleton<CloudStreamService>(
    () => CloudStreamService(httpClient: sl<http.Client>()),
  );

  // Register Data Sources
  sl.registerLazySingleton<DownloadLocalDataSource>(
    () => DownloadLocalDataSource(),
  );

  sl.registerLazySingleton<TmdbExternalDataSourceImpl>(
    () => TmdbExternalDataSourceImpl(),
  );

  sl.registerLazySingleton<AnilistExternalDataSourceImpl>(
    () => AnilistExternalDataSourceImpl(),
  );

  sl.registerLazySingleton<SimklExternalDataSourceImpl>(
    () => SimklExternalDataSourceImpl(),
  );

  sl.registerLazySingleton<KitsuExternalDataSourceImpl>(
    () => KitsuExternalDataSourceImpl(),
  );

  sl.registerLazySingleton<MediaRemoteDataSource>(
    () => MediaRemoteDataSourceImpl(extensionManager: _getExtensionManager()),
  );

  sl.registerLazySingleton<ExternalRemoteDataSource>(
    () => ExternalRemoteDataSource(
      tmdbDataSource: sl<TmdbExternalDataSourceImpl>(),
      anilistDataSource: sl<AnilistExternalDataSourceImpl>(),
      simklDataSource: sl<SimklExternalDataSourceImpl>(),
      jikanDataSource: sl<JikanExternalDataSourceImpl>(),
      kitsuDataSource: sl<KitsuExternalDataSourceImpl>(),
      matcher: sl<CrossProviderMatcher>(),
      aggregator: sl<DataAggregator>(),
      cache: sl<ProviderCache>(),
    ),
  );

  // MediaLocalDataSource requires async initialization
  // For now, we'll use a placeholder that will be initialized later
  sl.registerLazySingleton<MediaLocalDataSource>(
    () => throw UnimplementedError(
      'MediaLocalDataSource must be initialized asynchronously. '
      'Call initializeMediaDataSource() after initializeDependencies()',
    ),
  );

  // LibraryLocalDataSource requires async initialization
  // For now, we'll use a placeholder that will be initialized later
  sl.registerLazySingleton<LibraryLocalDataSource>(
    () => throw UnimplementedError(
      'LibraryLocalDataSource must be initialized asynchronously. '
      'Call initializeLibraryDataSource() after initializeDependencies()',
    ),
  );

  sl.registerLazySingleton<ExtensionDataSource>(
    () => ExtensionDataSourceImpl(lazyLoader: sl<LazyExtensionLoader>()),
  );

  sl.registerLazySingleton<TrackingDataSource>(
    () => TrackingDataSourceImpl(
      dio: Dio(),
      secureStorage: const FlutterSecureStorage(),
    ),
  );

  // Register TrackingAuthRepository for unified token management
  sl.registerLazySingleton<TrackingAuthRepository>(
    () =>
        TrackingAuthRepositoryImpl(secureStorage: const FlutterSecureStorage()),
  );

  sl.registerLazySingleton<TrackingAuthService>(
    () => TrackingAuthService(
      const FlutterSecureStorage(),
      sl<TrackingAuthRepository>(),
    ),
  );

  // Register MalExternalDataSource for MAL API fallback
  sl.registerLazySingleton<MalExternalDataSourceImpl>(
    () => MalExternalDataSourceImpl(),
  );

  // Register JikanExternalDataSource with MAL fallback support
  sl.registerLazySingleton<JikanExternalDataSourceImpl>(
    () => JikanExternalDataSourceImpl(
      authRepository: sl<TrackingAuthRepository>(),
      malDataSource: sl<MalExternalDataSourceImpl>(),
    ),
  );

  // Register Repositories
  sl.registerLazySingleton<DownloadRepository>(
    () =>
        DownloadRepositoryImpl(localDataSource: sl<DownloadLocalDataSource>()),
  );

  sl.registerLazySingleton<MediaRepository>(
    () => MediaRepositoryImpl(
      remoteDataSource: sl<MediaRemoteDataSource>(),
      localDataSource: sl<MediaLocalDataSource>(),
      extensionDataSource: sl<ExtensionDataSource>(),
      externalDataSource: sl<ExternalRemoteDataSource>(),
    ),
  );

  sl.registerLazySingleton<LibraryRepository>(
    () => LibraryRepositoryImpl(localDataSource: sl<LibraryLocalDataSource>()),
  );

  sl.registerLazySingleton<ExtensionRepository>(
    () => ExtensionRepositoryImpl(dataSource: sl<ExtensionDataSource>()),
  );

  sl.registerLazySingleton<VideoRepository>(
    () => VideoRepositoryImpl(extensionManager: _getExtensionManager()),
  );

  sl.registerLazySingleton<TrackingRepository>(
    () => TrackingRepositoryImpl(dataSource: sl<TrackingDataSource>()),
  );

  // Register ExtensionSearchRepository for episode/chapter source selection
  // Requirements: 3.2, 4.1
  sl.registerLazySingleton<ExtensionSearchRepository>(
    () => ExtensionSearchRepositoryImpl(
      extensionDataSource: sl<ExtensionDataSource>(),
    ),
  );

  // Register RecentExtensionsRepository for storing recently used extensions
  // Requirements: 8.1, 8.2, 8.3
  sl.registerLazySingleton<RecentExtensionsRepository>(
    () => RecentExtensionsRepositoryImpl(
      sharedPreferences: sl<SharedPreferences>(),
    ),
  );

  // RepositoryLocalDataSource requires async initialization
  // For now, we'll use a placeholder that will be initialized later
  sl.registerLazySingleton<RepositoryLocalDataSource>(
    () => throw UnimplementedError(
      'RepositoryLocalDataSource must be initialized asynchronously. '
      'Call initializeRepositoryDataSource() after initializeDependencies()',
    ),
  );

  // WatchHistoryLocalDataSource requires async initialization
  // For now, we'll use a placeholder that will be initialized later
  sl.registerLazySingleton<WatchHistoryLocalDataSource>(
    () => throw UnimplementedError(
      'WatchHistoryLocalDataSource must be initialized asynchronously. '
      'Call initializeWatchHistoryDataSource() after initializeDependencies()',
    ),
  );

  // WatchHistoryRepository requires WatchHistoryLocalDataSource
  // Will be properly initialized after initializeWatchHistoryDataSource()
  sl.registerLazySingleton<WatchHistoryRepository>(
    () => WatchHistoryRepositoryImpl(
      localDataSource: sl<WatchHistoryLocalDataSource>(),
    ),
  );

  // Register WatchHistoryController
  sl.registerLazySingleton<WatchHistoryController>(
    () => WatchHistoryController(repository: sl<WatchHistoryRepository>()),
  );

  // RepositoryRepository requires RepositoryLocalDataSource
  // Will be properly initialized after initializeRepositoryDataSource()
  sl.registerLazySingleton<RepositoryRepository>(
    () => RepositoryRepositoryImpl(
      localDataSource: sl<RepositoryLocalDataSource>(),
      httpClient: sl<http.Client>(),
    ),
  );

  // Register DeepLinkHandler
  // The onSaveRepository callback will be connected to the RepositoryRepository
  sl.registerLazySingleton<DeepLinkHandler>(
    () => DeepLinkHandler(
      onSaveRepository: (type, config) async {
        final repo = sl<RepositoryRepository>();
        await repo.saveRepositoryConfig(type, config);
      },
    ),
  );

  // Register Use Cases
  sl.registerLazySingleton<GetTrendingMediaUseCase>(
    () => GetTrendingMediaUseCase(sl<MediaRepository>()),
  );
  sl.registerLazySingleton<GetPopularMediaUseCase>(
    () => GetPopularMediaUseCase(sl<MediaRepository>()),
  );
  sl.registerLazySingleton<GetLibraryItemsUseCase>(
    () => GetLibraryItemsUseCase(sl<LibraryRepository>()),
  );
  sl.registerLazySingleton<SearchMediaUseCase>(
    () => SearchMediaUseCase(sl<MediaRepository>()),
  );
  sl.registerLazySingleton<GetAvailableExtensionsUseCase>(
    () => GetAvailableExtensionsUseCase(sl<ExtensionRepository>()),
  );
  sl.registerLazySingleton<GetInstalledExtensionsUseCase>(
    () => GetInstalledExtensionsUseCase(sl<ExtensionRepository>()),
  );
  sl.registerLazySingleton<InstallExtensionUseCase>(
    () => InstallExtensionUseCase(sl<ExtensionRepository>()),
  );
  sl.registerLazySingleton<UninstallExtensionUseCase>(
    () => UninstallExtensionUseCase(sl<ExtensionRepository>()),
  );
  sl.registerLazySingleton<GetVideoSourcesUseCase>(
    () => GetVideoSourcesUseCase(sl<VideoRepository>()),
  );
  sl.registerLazySingleton<ExtractVideoUrlUseCase>(
    () => ExtractVideoUrlUseCase(sl<VideoRepository>()),
  );
  sl.registerLazySingleton<SavePlaybackPositionUseCase>(
    () => SavePlaybackPositionUseCase(sl<LibraryRepository>()),
  );
  sl.registerLazySingleton<GetPlaybackPositionUseCase>(
    () => GetPlaybackPositionUseCase(sl<LibraryRepository>()),
  );
  sl.registerLazySingleton<UpdateProgressUseCase>(
    () => UpdateProgressUseCase(sl<LibraryRepository>()),
  );
  sl.registerLazySingleton<UpdateLibraryItemUseCase>(
    () => UpdateLibraryItemUseCase(sl<LibraryRepository>()),
  );
  sl.registerLazySingleton<RemoveFromLibraryUseCase>(
    () => RemoveFromLibraryUseCase(sl<LibraryRepository>()),
  );
  sl.registerLazySingleton<GetMediaDetailsUseCase>(
    () => GetMediaDetailsUseCase(sl<MediaRepository>()),
  );
  sl.registerLazySingleton<GetEpisodesUseCase>(
    () => GetEpisodesUseCase(sl<MediaRepository>()),
  );
  sl.registerLazySingleton<GetChaptersUseCase>(
    () => GetChaptersUseCase(sl<MediaRepository>()),
  );
  sl.registerLazySingleton<GetChapterPagesUseCase>(
    () => GetChapterPagesUseCase(sl<MediaRepository>()),
  );
  sl.registerLazySingleton<SaveReadingPositionUseCase>(
    () => SaveReadingPositionUseCase(sl<LibraryRepository>()),
  );
  sl.registerLazySingleton<GetReadingPositionUseCase>(
    () => GetReadingPositionUseCase(sl<LibraryRepository>()),
  );
  sl.registerLazySingleton<AddToLibraryUseCase>(
    () => AddToLibraryUseCase(sl<LibraryRepository>()),
  );

  // Register OfflineStorageManager
  sl.registerLazySingleton<OfflineStorageManager>(
    () => OfflineStorageManager(downloadRepository: sl<DownloadRepository>()),
  );

  // Register ViewModels
  sl.registerLazySingleton<HomeViewModel>(
    () => HomeViewModel(
      getTrendingMedia: sl<GetTrendingMediaUseCase>(),
      getLibraryItems: sl<GetLibraryItemsUseCase>(),
      tmdbService: sl<TmdbService>(),
      watchHistoryRepository: sl<WatchHistoryRepository>(),
    ),
  );
  sl.registerLazySingleton<BrowseViewModel>(
    () => BrowseViewModel(
      getPopularMedia: sl<GetPopularMediaUseCase>(),
      getTrendingMedia: sl<GetTrendingMediaUseCase>(),
      searchMedia: sl<SearchMediaUseCase>(),
    ),
  );
  sl.registerLazySingleton<SearchViewModel>(
    () => SearchViewModel(searchMedia: sl<SearchMediaUseCase>()),
  );
  sl.registerLazySingleton<LibraryViewModel>(
    () => LibraryViewModel(
      getLibraryItems: sl<GetLibraryItemsUseCase>(),
      updateLibraryItem: sl<UpdateLibraryItemUseCase>(),
      removeFromLibrary: sl<RemoveFromLibraryUseCase>(),
    ),
  );
  sl.registerLazySingleton<SettingsViewModel>(
    () => SettingsViewModel(
      sl<TrackingAuthService>(),
      sl<Box>(instanceName: 'settingsBox'),
      sl<ProviderCache>(),
    ),
  );
  sl.registerFactory<MediaDetailsViewModel>(
    () => MediaDetailsViewModel(
      getMediaDetails: sl<GetMediaDetailsUseCase>(),
      getEpisodes: sl<GetEpisodesUseCase>(),
      getChapters: sl<GetChaptersUseCase>(),
      addToLibrary: sl<AddToLibraryUseCase>(),
      mediaRepository: sl<MediaRepository>(),
      libraryRepository: sl<LibraryRepository>(),
      watchHistoryRepository: sl<WatchHistoryRepository>(),
    ),
  );
  sl.registerFactory<EpisodeSourceSelectionViewModel>(
    () => EpisodeSourceSelectionViewModel(
      extensionSearchRepository: sl<ExtensionSearchRepository>(),
      recentExtensionsRepository: sl<RecentExtensionsRepository>(),
    ),
  );
  sl.registerFactory<MangaReaderViewModel>(
    () => MangaReaderViewModel(
      getChapterPages: sl<GetChapterPagesUseCase>(),
      saveReadingPosition: sl<SaveReadingPositionUseCase>(),
      getReadingPosition: sl<GetReadingPositionUseCase>(),
    ),
  );

  // Register AuthenticateTrackingServiceUseCase
  sl.registerLazySingleton<AuthenticateTrackingServiceUseCase>(
    () => AuthenticateTrackingServiceUseCase(sl<TrackingRepository>()),
  );

  // Register AuthViewModel for managing authentication state
  sl.registerLazySingleton<AuthViewModel>(
    () => AuthViewModel(
      authenticateTrackingService: sl<AuthenticateTrackingServiceUseCase>(),
      authRepository: sl<TrackingAuthRepository>(),
    ),
  );

  sl.registerLazySingleton<DataMigrationService>(
    () => DataMigrationService(libraryDataSource: sl<LibraryLocalDataSource>()),
  );
}

/// Initialize MediaLocalDataSource asynchronously
Future<void> initializeMediaDataSource() async {
  // Unregister the placeholder if it exists
  if (sl.isRegistered<MediaLocalDataSource>()) {
    await sl.unregister<MediaLocalDataSource>();
  }
  final dataSource = await MediaLocalDataSourceImpl.create();
  sl.registerSingleton<MediaLocalDataSource>(dataSource);
}

/// Initialize LibraryLocalDataSource asynchronously
Future<void> initializeLibraryDataSource() async {
  // Unregister the placeholder if it exists
  if (sl.isRegistered<LibraryLocalDataSource>()) {
    await sl.unregister<LibraryLocalDataSource>();
  }
  final dataSource = await LibraryLocalDataSourceImpl.create();
  sl.registerSingleton<LibraryLocalDataSource>(dataSource);

  // Run data migrations after library data source is initialized
  if (sl.isRegistered<DataMigrationService>()) {
    final migrationService = sl<DataMigrationService>();
    await migrationService.runMigrations();
  }
}

/// Initialize RepositoryLocalDataSource asynchronously
/// This is required for repository URL persistence (Requirements: 2.1, 2.2)
Future<void> initializeRepositoryDataSource() async {
  // Unregister the placeholder if it exists
  if (sl.isRegistered<RepositoryLocalDataSource>()) {
    await sl.unregister<RepositoryLocalDataSource>();
  }
  final dataSource = await RepositoryLocalDataSourceImpl.create();
  sl.registerSingleton<RepositoryLocalDataSource>(dataSource);

  // Re-register RepositoryRepository with the initialized data source
  if (sl.isRegistered<RepositoryRepository>()) {
    await sl.unregister<RepositoryRepository>();
  }
  sl.registerLazySingleton<RepositoryRepository>(
    () => RepositoryRepositoryImpl(
      localDataSource: sl<RepositoryLocalDataSource>(),
      httpClient: sl<http.Client>(),
    ),
  );

  // Re-register DeepLinkHandler with the updated repository
  if (sl.isRegistered<DeepLinkHandler>()) {
    await sl.unregister<DeepLinkHandler>();
  }
  sl.registerLazySingleton<DeepLinkHandler>(
    () => DeepLinkHandler(
      onSaveRepository: (type, config) async {
        final repo = sl<RepositoryRepository>();
        await repo.saveRepositoryConfig(type, config);
      },
    ),
  );
}

/// Initialize WatchHistoryLocalDataSource asynchronously
/// This is required for watch history persistence
Future<void> initializeWatchHistoryDataSource() async {
  // Unregister the placeholder if it exists
  if (sl.isRegistered<WatchHistoryLocalDataSource>()) {
    await sl.unregister<WatchHistoryLocalDataSource>();
  }
  final dataSource = await WatchHistoryLocalDataSourceImpl.create();
  sl.registerSingleton<WatchHistoryLocalDataSource>(dataSource);

  // Re-register WatchHistoryRepository with the initialized data source
  if (sl.isRegistered<WatchHistoryRepository>()) {
    await sl.unregister<WatchHistoryRepository>();
  }
  sl.registerLazySingleton<WatchHistoryRepository>(
    () => WatchHistoryRepositoryImpl(
      localDataSource: sl<WatchHistoryLocalDataSource>(),
    ),
  );

  // Re-register WatchHistoryController with the updated repository
  if (sl.isRegistered<WatchHistoryController>()) {
    await sl.unregister<WatchHistoryController>();
  }
  sl.registerLazySingleton<WatchHistoryController>(
    () => WatchHistoryController(repository: sl<WatchHistoryRepository>()),
  );

  // Re-register HomeViewModel with the updated repository
  if (sl.isRegistered<HomeViewModel>()) {
    await sl.unregister<HomeViewModel>();
  }
  sl.registerLazySingleton<HomeViewModel>(
    () => HomeViewModel(
      getTrendingMedia: sl<GetTrendingMediaUseCase>(),
      getLibraryItems: sl<GetLibraryItemsUseCase>(),
      tmdbService: sl<TmdbService>(),
      watchHistoryRepository: sl<WatchHistoryRepository>(),
    ),
  );
}

/// Get ExtensionManager from GetX (if available) or return null
/// This is a workaround since ExtensionManager is managed by GetX
/// The ExtensionManager is registered by DartotsuExtensionBridge.init()
ExtensionManager? _getExtensionManager() {
  try {
    // Try to get from GetX if available
    // This will be available after DartotsuExtensionBridge.init() is called
    return Get.find<ExtensionManager>();
  } catch (e) {
    // ExtensionManager not yet registered - this is expected during initial setup
    return null;
  }
}

/// Clean up resources
Future<void> disposeDependencies() async {
  // Only close Isar if it was registered
  if (sl.isRegistered<Isar>()) {
    await sl<Isar>().close();
  }
  await Hive.close();
}

Future<Directory> _resolveAppStorageDirectory() async {
  final dir = await getApplicationSupportDirectory();
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir;
}
