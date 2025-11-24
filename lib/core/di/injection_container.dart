import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:isar_community/isar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../domain/services/offline_storage_manager.dart';
import '../domain/services/lazy_extension_loader.dart';
import '../services/tracking_auth_service.dart';
import '../services/tmdb_service.dart';
import '../domain/repositories/download_repository.dart';
import '../domain/repositories/media_repository.dart';
import '../domain/repositories/library_repository.dart';
import '../domain/repositories/extension_repository.dart';
import '../domain/repositories/video_repository.dart';
import '../domain/repositories/tracking_repository.dart';
import '../data/repositories/download_repository_impl.dart';
import '../data/repositories/media_repository_impl.dart';
import '../data/repositories/library_repository_impl.dart';
import '../data/repositories/extension_repository_impl.dart';
import '../data/repositories/video_repository_impl.dart';
import '../data/repositories/tracking_repository_impl.dart';
import '../data/datasources/download_local_data_source.dart';
import '../data/datasources/media_remote_data_source.dart';
import '../data/datasources/media_local_data_source.dart';
import '../data/datasources/library_local_data_source.dart';
import '../data/datasources/extension_data_source.dart';
import '../data/datasources/tracking_data_source.dart';
import '../domain/usecases/get_trending_media_usecase.dart';
import '../domain/usecases/get_popular_media_usecase.dart';
import '../domain/usecases/get_library_items_usecase.dart';
import '../domain/usecases/search_media_usecase.dart';
import '../domain/usecases/get_available_extensions_usecase.dart';
import '../domain/usecases/get_installed_extensions_usecase.dart';
import '../domain/usecases/install_extension_usecase.dart';
import '../domain/usecases/uninstall_extension_usecase.dart';
import '../domain/usecases/get_video_sources_usecase.dart';
import '../domain/usecases/update_progress_usecase.dart';
import '../domain/usecases/update_library_item_usecase.dart';
import '../domain/usecases/remove_from_library_usecase.dart';
import '../../features/home/presentation/viewmodels/home_viewmodel.dart';
import '../../features/home/presentation/viewmodels/browse_viewmodel.dart';
import '../../features/search/presentation/viewmodels/search_viewmodel.dart';
import '../../features/library/presentation/viewmodels/library_viewmodel.dart';
import '../../features/extensions/presentation/viewmodels/extension_viewmodel.dart';
import '../../features/settings/presentation/viewmodels/settings_viewmodel.dart';

final sl = GetIt.instance;

/// Initialize all dependencies
Future<void> initializeDependencies() async {
  // Initialize Hive
  await Hive.initFlutter();

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

  // Register LazyExtensionLoader for on-demand extension loading
  sl.registerLazySingleton<LazyExtensionLoader>(() => LazyExtensionLoader());

  // Register TMDB Service
  sl.registerLazySingleton<TmdbService>(() => TmdbService());

  // Register Data Sources
  sl.registerLazySingleton<DownloadLocalDataSource>(
    () => DownloadLocalDataSource(),
  );

  sl.registerLazySingleton<MediaRemoteDataSource>(
    () => MediaRemoteDataSourceImpl(extensionManager: _getExtensionManager()),
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
    () => ExtensionDataSourceImpl(
      extensionManager: _getExtensionManager(),
      lazyLoader: sl<LazyExtensionLoader>(),
    ),
  );

  sl.registerLazySingleton<TrackingDataSource>(
    () => TrackingDataSourceImpl(
      dio: Dio(),
      secureStorage: const FlutterSecureStorage(),
    ),
  );

  sl.registerLazySingleton<TrackingAuthService>(
    () => TrackingAuthService(const FlutterSecureStorage()),
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
  sl.registerLazySingleton<UpdateProgressUseCase>(
    () => UpdateProgressUseCase(sl<LibraryRepository>()),
  );
  sl.registerLazySingleton<UpdateLibraryItemUseCase>(
    () => UpdateLibraryItemUseCase(sl<LibraryRepository>()),
  );
  sl.registerLazySingleton<RemoveFromLibraryUseCase>(
    () => RemoveFromLibraryUseCase(sl<LibraryRepository>()),
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
    ),
  );
  sl.registerLazySingleton<BrowseViewModel>(
    () => BrowseViewModel(
      getPopularMedia: sl<GetPopularMediaUseCase>(),
      getTrendingMedia: sl<GetTrendingMediaUseCase>(),
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
  sl.registerLazySingleton<ExtensionViewModel>(
    () => ExtensionViewModel(
      getAvailableExtensions: sl<GetAvailableExtensionsUseCase>(),
      getInstalledExtensions: sl<GetInstalledExtensionsUseCase>(),
      installExtension: sl<InstallExtensionUseCase>(),
      uninstallExtension: sl<UninstallExtensionUseCase>(),
    ),
  );
  sl.registerLazySingleton<SettingsViewModel>(
    () => SettingsViewModel(
      sl<TrackingAuthService>(),
      sl<Box>(instanceName: 'settingsBox'),
    ),
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
}

/// Get ExtensionManager from GetX (if available) or return a placeholder
/// This is a workaround since ExtensionManager is managed by GetX
dynamic _getExtensionManager() {
  try {
    // Try to get from GetX if available
    // This will be called when the extension bridge is initialized
    return null; // Placeholder - will be replaced with actual manager
  } catch (e) {
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
