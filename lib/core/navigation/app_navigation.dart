import 'package:flutter/material.dart';

/// Navigation destinations for the application
enum AppDestination { home, anime, manga, novel, library, extensions, settings }

/// Route names for navigation
class AppRoutes {
  static const String home = '/';
  static const String anime = '/anime';
  static const String manga = '/manga';
  static const String novel = '/novel';
  static const String library = '/library';
  static const String extensions = '/extensions';
  static const String settings = '/settings';
  static const String mediaDetails = '/media-details';
  static const String videoPlayer = '/video-player';
  static const String mangaReader = '/manga-reader';
}

/// Navigation destination data
class NavigationDestinationData {
  final AppDestination destination;
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const NavigationDestinationData({
    required this.destination,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

/// Available navigation destinations
class AppNavigationDestinations {
  static const List<NavigationDestinationData> destinations = [
    NavigationDestinationData(
      destination: AppDestination.home,
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
    ),
    NavigationDestinationData(
      destination: AppDestination.anime,
      label: 'Anime',
      icon: Icons.movie_outlined,
      selectedIcon: Icons.movie,
    ),
    NavigationDestinationData(
      destination: AppDestination.manga,
      label: 'Manga',
      icon: Icons.book_outlined,
      selectedIcon: Icons.book,
    ),
    NavigationDestinationData(
      destination: AppDestination.novel,
      label: 'Novels',
      icon: Icons.auto_stories_outlined,
      selectedIcon: Icons.auto_stories,
    ),
    NavigationDestinationData(
      destination: AppDestination.library,
      label: 'Library',
      icon: Icons.video_library_outlined,
      selectedIcon: Icons.video_library,
    ),
    NavigationDestinationData(
      destination: AppDestination.extensions,
      label: 'Extensions',
      icon: Icons.extension_outlined,
      selectedIcon: Icons.extension,
    ),
    NavigationDestinationData(
      destination: AppDestination.settings,
      label: 'Settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
    ),
  ];

  /// Get primary destinations (shown in bottom nav on mobile)
  static List<NavigationDestinationData> get primaryDestinations {
    return destinations.where((d) {
      return d.destination == AppDestination.home ||
          d.destination == AppDestination.anime ||
          d.destination == AppDestination.manga ||
          d.destination == AppDestination.novel ||
          d.destination == AppDestination.library;
    }).toList();
  }

  /// Get all destinations (shown in rail/drawer on desktop)
  static List<NavigationDestinationData> get allDestinations {
    return destinations;
  }
}
