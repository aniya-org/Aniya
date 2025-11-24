import 'package:flutter/material.dart';
import 'package:aniya/core/services/responsive_layout_manager.dart';
import 'app_navigation.dart';

/// Adaptive navigation that switches between bottom nav and rail based on screen size
class AdaptiveNavigation extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget child;
  final bool extended;

  const AdaptiveNavigation({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.child,
    this.extended = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenType = ResponsiveLayoutManager.getScreenType(
          constraints.maxWidth,
        );

        switch (screenType) {
          case ScreenType.mobile:
            return _MobileNavigation(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              child: child,
            );
          case ScreenType.tablet:
            return _TabletNavigation(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              extended: false,
              child: child,
            );
          case ScreenType.desktop:
          case ScreenType.largeDesktop:
            return _DesktopNavigation(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              extended: extended,
              child: child,
            );
        }
      },
    );
  }
}

/// Mobile navigation with bottom navigation bar
class _MobileNavigation extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget child;

  const _MobileNavigation({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final destinations = AppNavigationDestinations.primaryDestinations;

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex.clamp(0, destinations.length - 1),
        onDestinationSelected: onDestinationSelected,
        destinations: destinations.map((dest) {
          return NavigationDestination(
            icon: Icon(dest.icon),
            selectedIcon: Icon(dest.selectedIcon),
            label: dest.label,
          );
        }).toList(),
      ),
    );
  }
}

/// Tablet navigation with compact navigation rail
class _TabletNavigation extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget child;
  final bool extended;

  const _TabletNavigation({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.child,
    required this.extended,
  });

  @override
  Widget build(BuildContext context) {
    final destinations = AppNavigationDestinations.allDestinations;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex.clamp(0, destinations.length - 1),
            onDestinationSelected: onDestinationSelected,
            extended: extended,
            labelType: extended
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
            destinations: destinations.map((dest) {
              return NavigationRailDestination(
                icon: Icon(dest.icon),
                selectedIcon: Icon(dest.selectedIcon),
                label: Text(dest.label),
              );
            }).toList(),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Desktop navigation with extended navigation rail
class _DesktopNavigation extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget child;
  final bool extended;

  const _DesktopNavigation({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.child,
    required this.extended,
  });

  @override
  Widget build(BuildContext context) {
    final destinations = AppNavigationDestinations.allDestinations;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex.clamp(0, destinations.length - 1),
            onDestinationSelected: onDestinationSelected,
            extended: extended,
            labelType: extended
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
            destinations: destinations.map((dest) {
              return NavigationRailDestination(
                icon: Icon(dest.icon),
                selectedIcon: Icon(dest.selectedIcon),
                label: Text(dest.label),
              );
            }).toList(),
            leading: extended
                ? null
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: FloatingActionButton(
                      elevation: 0,
                      onPressed: () {
                        // Toggle extended state - handled by parent
                      },
                      child: const Icon(Icons.menu),
                    ),
                  ),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}
