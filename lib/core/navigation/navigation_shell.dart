import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:get_it/get_it.dart';
import 'adaptive_navigation.dart';
import 'app_navigation.dart';
import 'navigation_controller.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/home/presentation/screens/anime_screen.dart';
import '../../features/home/presentation/screens/manga_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/library/presentation/screens/library_screen.dart';
import '../../features/extensions/presentation/screens/extension_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/home/presentation/viewmodels/home_viewmodel.dart';
import '../../features/home/presentation/viewmodels/browse_viewmodel.dart';
import '../../features/search/presentation/viewmodels/search_viewmodel.dart';
import '../../features/library/presentation/viewmodels/library_viewmodel.dart';
import '../../features/extensions/presentation/viewmodels/extension_viewmodel.dart';
import '../../features/settings/presentation/viewmodels/settings_viewmodel.dart';

/// Main navigation shell that manages app-wide navigation
class NavigationShell extends StatefulWidget {
  final ThemeData? theme;
  final ThemeData? darkTheme;
  final ThemeMode? themeMode;

  const NavigationShell({
    super.key,
    this.theme,
    this.darkTheme,
    this.themeMode,
  });

  @override
  State<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends State<NavigationShell>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  final bool _isExtended = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onDestinationSelected(int index) {
    if (_selectedIndex != index) {
      setState(() {
        _animationController.reset();
        _selectedIndex = index;
        _animationController.forward();
      });
    }
  }

  Widget _getSelectedScreen() {
    final destinations = AppNavigationDestinations.allDestinations;
    if (_selectedIndex >= destinations.length) {
      return const Center(child: Text('Invalid destination'));
    }

    final destination = destinations[_selectedIndex].destination;
    final getIt = GetIt.instance;

    switch (destination) {
      case AppDestination.home:
        return ChangeNotifierProvider.value(
          value: getIt<HomeViewModel>(),
          child: const HomeScreen(),
        );
      case AppDestination.anime:
        return ChangeNotifierProvider.value(
          value: getIt<BrowseViewModel>(),
          child: const AnimeScreen(),
        );
      case AppDestination.manga:
        return ChangeNotifierProvider.value(
          value: getIt<BrowseViewModel>(),
          child: const MangaScreen(),
        );
      case AppDestination.search:
        return ChangeNotifierProvider.value(
          value: getIt<SearchViewModel>(),
          child: const SearchScreen(),
        );
      case AppDestination.library:
        return ChangeNotifierProvider.value(
          value: getIt<LibraryViewModel>(),
          child: const LibraryScreen(),
        );
      case AppDestination.extensions:
        return ChangeNotifierProvider.value(
          value: getIt<ExtensionViewModel>(),
          child: const ExtensionScreen(),
        );
      case AppDestination.settings:
        return ChangeNotifierProvider.value(
          value: getIt<SettingsViewModel>(),
          child: const SettingsScreen(),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return NavigationController(
      navigateTo: (destination) {
        final index = AppNavigationDestinations.allDestinations.indexWhere(
          (d) => d.destination == destination,
        );
        if (index != -1) {
          _onDestinationSelected(index);
        }
      },
      child: AdaptiveNavigation(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        extended: _isExtended,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: _getSelectedScreen(),
        ),
      ),
    );
  }
}
