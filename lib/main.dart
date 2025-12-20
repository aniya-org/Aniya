import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:adblocker_webview/adblocker_webview.dart';
import 'package:dartotsu_extension_bridge/dartotsu_extension_bridge.dart';
import 'package:dartotsu_extension_bridge/Aniyomi/desktop/aniyomi_desktop.dart';
import 'package:dartotsu_extension_bridge/CloudStream/desktop/desktop.dart';
import 'package:dartotsu_extension_bridge/ExtensionManager.dart' as bridge;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:aniya/core/di/injection_container.dart';
import 'package:aniya/core/constants/app_constants.dart';
import 'package:aniya/core/utils/logger.dart';
import 'package:aniya/core/utils/error_handler.dart';
import 'package:aniya/core/utils/platform_utils.dart';
import 'package:aniya/core/theme/theme.dart';
import 'package:aniya/core/navigation/navigation_shell.dart';
import 'package:aniya/core/services/mobile_platform_manager.dart';
import 'package:aniya/core/services/desktop_window_manager.dart';
import 'package:aniya/core/services/deep_link_service.dart';
import 'package:aniya/core/widgets/mobile_status_bar_controller.dart';
import 'package:aniya/core/widgets/mobile_navigation_bar_controller.dart';
import 'package:aniya/features/media_details/presentation/screens/media_details_screen.dart';
import 'package:aniya/features/media_details/presentation/viewmodels/media_details_viewmodel.dart';
import 'package:aniya/features/extensions/controllers/extensions_controller.dart';
import 'package:aniya/core/domain/entities/media_entity.dart';
import 'package:aniya/core/domain/entities/extension_entity.dart' as domain;

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..userAgent = null
      // Allow self-signed certificates (for development purposes)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  // Initialize Flutter bindings BEFORE creating zones
  WidgetsFlutterBinding.ensureInitialized();

  // Set custom HTTP overrides to disable user-agent
  HttpOverrides.global = MyHttpOverrides();

  // Load environment variables (optional - .env file may not exist)
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    Logger.info('No .env file found, using default values', tag: 'Main');
  }

  // Initialize global error handler
  ErrorHandler.initialize();

  // Configure desktop plugin runtimes programmatically when supported
  if (PlatformUtils.isDesktop) {
    cloudstreamConfig
      ..enableDesktopJsPlugins = true
      ..enableDesktopDexPlugins = true
      ..enableTelemetry = true
      ..enableVerboseLogging = false
      ..jsTimeoutSeconds = 30
      ..dexTimeoutSeconds = 60
      ..maxMemoryMb = 256;

    aniyomiDesktopConfig
      ..enableDesktopAniyomi = true
      ..enableTelemetry = true
      ..verboseLogging = false
      ..dexTimeoutSeconds = 60
      ..networkTimeoutSeconds = 30
      ..maxMemoryMb = 512;
  }

  try {
    // Initialize media_kit
    MediaKit.ensureInitialized();

    if (PlatformUtils.isMobile) {
      try {
        await AdBlockerWebviewController.instance.initialize(
          FilterConfig(filterTypes: [FilterType.easyList, FilterType.adGuard]),
        );
      } catch (e, stackTrace) {
        Logger.warning(
          'AdBlocker WebView initialization failed: $e',
          tag: 'Main',
        );
        Logger.debug(
          'AdBlocker WebView init error stack: $stackTrace',
          tag: 'Main',
        );
      }
    }

    // Initialize DartotsuExtensionBridge to register extension managers with GetX
    // This is required for extension discovery and management (Requirements: 10.1, 10.2, 10.3, 12.1)
    Logger.info('Initializing extension bridge...', tag: 'Main');
    try {
      // Ensure the Isar database directory exists before initializing the bridge
      final isarDir = await _resolveExtensionBridgeIsarDirectory();
      if (!await isarDir.exists()) {
        await isarDir.create(recursive: true);
        Logger.debug('Created Isar directory: ${isarDir.path}', tag: 'Main');
      }

      await DartotsuExtensionBridge().init(null, 'aniya');
      Logger.info('Extension bridge initialized successfully', tag: 'Main');
    } catch (e, stackTrace) {
      // Extension bridge initialization is optional - app can still work without it
      // Extensions will just not be available until the bridge is properly initialized
      Logger.warning(
        'Extension bridge initialization failed (extensions may not be available): $e',
        tag: 'Main',
      );
      Logger.debug('Extension bridge error stack: $stackTrace', tag: 'Main');
    }

    // Initialize platform-specific features
    Logger.info('Initializing platform features...', tag: 'Main');
    if (PlatformUtils.isMobile) {
      await MobilePlatformManager.initializeMobileFeatures();
      Logger.info('Mobile platform features initialized', tag: 'Main');
    } else if (PlatformUtils.isDesktop) {
      await DesktopWindowManager.initializeWindow();
      Logger.info('Desktop window manager initialized', tag: 'Main');
    }

    // Initialize dependencies
    Logger.info('Initializing dependencies...', tag: 'Main');
    await initializeDependencies();
    Logger.info('Dependencies initialized successfully', tag: 'Main');

    // Initialize async data sources
    Logger.info('Initializing data sources...', tag: 'Main');
    await initializeMediaDataSource();
    await initializeLibraryDataSource();
    await initializeRepositoryDataSource();
    await initializeWatchHistoryDataSource();
    Logger.info('Data sources initialized successfully', tag: 'Main');
  } catch (e, stackTrace) {
    Logger.error(
      'Failed to initialize app',
      tag: 'Main',
      error: e,
      stackTrace: stackTrace,
    );
    // Show error screen instead of crashing
    runApp(ErrorApp(error: e.toString()));
    return;
  }

  // Run app directly (no zone wrapper to avoid zone mismatch)
  runApp(const AniyaApp());
}

class AniyaApp extends StatefulWidget {
  const AniyaApp({super.key});

  @override
  State<AniyaApp> createState() => _AniyaAppState();
}

class _AniyaAppState extends State<AniyaApp> {
  late final ThemeProvider _themeProvider;
  DeepLinkService? _deepLinkService;
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    final settingsBox = sl<Box>(instanceName: 'settingsBox');
    final themeIndex = settingsBox.get(
      'theme_mode',
      defaultValue: AppThemeMode.system.index,
    );
    final initialTheme = AppThemeMode.values[themeIndex];
    _themeProvider = ThemeProvider(initialThemeMode: initialTheme);

    // Initialize deep link handling
    _initializeDeepLinks();
  }

  /// Initializes deep link service to listen for incoming repository links.
  ///
  /// Supports schemes: aniyomi, tachiyomi, mangayomi, dar, cloudstreamrepo, cs.repo
  /// Requirements: 3.1, 3.2, 3.3, 3.4, 3.5
  Future<void> _initializeDeepLinks() async {
    final extensionsController = sl<ExtensionsController>();

    _deepLinkService = DeepLinkService(
      onDeepLinkProcessed: (result) {
        // Show success message (Requirement 3.4)
        Logger.info('Deep link processed: ${result.message}', tag: 'DeepLink');
        _showDeepLinkSnackBar(result.message, isError: false);
        // Reload extensions to show newly added repositories
        extensionsController.fetchRepos();
      },
      onDeepLinkError: (error) {
        // Show error message (Requirement 3.5)
        Logger.warning('Deep link error: $error', tag: 'DeepLink');
        _showDeepLinkSnackBar(error, isError: true);
      },
      onSaveRepository: (type, config) async {
        // Save repository configuration through the viewmodel
        await extensionsController.applyRepositoryConfig(
          _mapDomainTypeToBridge(type),
          config,
        );
      },
    );

    await _deepLinkService!.initialize();
  }

  /// Shows a snackbar with the deep link processing result.
  void _showDeepLinkSnackBar(String message, {required bool isError}) {
    final messenger = _scaffoldMessengerKey.currentState;
    if (messenger != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: isError
              ? Colors.red.shade700
              : Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: isError ? 5 : 3),
          action: isError
              ? SnackBarAction(
                  label: 'Dismiss',
                  textColor: Colors.white,
                  onPressed: () => messenger.hideCurrentSnackBar(),
                )
              : null,
        ),
      );
    }
  }

  @override
  void dispose() {
    _deepLinkService?.dispose();
    _themeProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _themeProvider,
      builder: (context, _) {
        final app = ChangeNotifierProvider.value(
          value: _themeProvider,
          child: MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            scaffoldMessengerKey: _scaffoldMessengerKey,
            theme: _themeProvider.lightTheme,
            darkTheme: _themeProvider.darkTheme,
            themeMode: _themeProvider.materialThemeMode,
            home: NavigationShell(
              theme: _themeProvider.lightTheme,
              darkTheme: _themeProvider.darkTheme,
              themeMode: _themeProvider.materialThemeMode,
            ),
            onGenerateRoute: (settings) {
              if (settings.name == '/media-details') {
                final media = settings.arguments as MediaEntity;
                return MaterialPageRoute(
                  builder: (context) => ChangeNotifierProvider(
                    create: (_) => sl<MediaDetailsViewModel>(),
                    child: MediaDetailsScreen(media: media),
                  ),
                );
              }
              return null;
            },
          ),
        );

        // Wrap with mobile-specific controllers
        if (PlatformUtils.isMobile) {
          return MobileStatusBarController(
            statusBarBrightness: _themeProvider.isDarkMode
                ? Brightness.dark
                : Brightness.light,
            child: MobileNavigationBarController(
              navigationBarBrightness: _themeProvider.isDarkMode
                  ? Brightness.dark
                  : Brightness.light,
              child: app,
            ),
          );
        }

        return app;
      },
    );
  }

  bridge.ExtensionType _mapDomainTypeToBridge(domain.ExtensionType type) {
    switch (type) {
      case domain.ExtensionType.mangayomi:
        return bridge.ExtensionType.mangayomi;
      case domain.ExtensionType.aniyomi:
        return bridge.ExtensionType.aniyomi;
      case domain.ExtensionType.cloudstream:
        return bridge.ExtensionType.cloudstream;
      case domain.ExtensionType.lnreader:
        return bridge.ExtensionType.lnreader;
      case domain.ExtensionType.aniya:
        return bridge.ExtensionType.aniya;
    }
  }
}

Future<Directory> _resolveExtensionBridgeIsarDirectory() async {
  final docDir = await getApplicationDocumentsDirectory();
  final isStandardDocPath =
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  final basePath = isStandardDocPath
      ? docDir.path
      : p.join(docDir.path, 'aniya', 'databases');
  return Directory(p.join(basePath, 'isar'));
}

/// Error app shown when initialization fails
class ErrorApp extends StatelessWidget {
  final String error;

  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Error',
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 24),
                const Text(
                  'Failed to start application',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  error,
                  style: const TextStyle(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    // Restart the app
                    main();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
