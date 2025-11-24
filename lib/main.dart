import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:aniya/core/di/injection_container.dart';
import 'package:aniya/core/constants/app_constants.dart';
import 'package:aniya/core/utils/logger.dart';
import 'package:aniya/core/utils/error_handler.dart';
import 'package:aniya/core/utils/platform_utils.dart';
import 'package:aniya/core/theme/theme.dart';
import 'package:aniya/core/navigation/navigation_shell.dart';
import 'package:aniya/core/services/mobile_platform_manager.dart';
import 'package:aniya/core/services/desktop_window_manager.dart';
import 'package:aniya/core/widgets/mobile_status_bar_controller.dart';
import 'package:aniya/core/widgets/mobile_navigation_bar_controller.dart';

void main() async {
  // Initialize Flutter bindings BEFORE creating zones
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize global error handler
  ErrorHandler.initialize();

  try {
    // Initialize media_kit
    MediaKit.ensureInitialized();

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
  }

  @override
  void dispose() {
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
            theme: _themeProvider.lightTheme,
            darkTheme: _themeProvider.darkTheme,
            themeMode: _themeProvider.materialThemeMode,
            home: NavigationShell(
              theme: _themeProvider.lightTheme,
              darkTheme: _themeProvider.darkTheme,
              themeMode: _themeProvider.materialThemeMode,
            ),
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
