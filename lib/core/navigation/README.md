# Navigation System

This directory contains the navigation infrastructure for the Aniya application, implementing adaptive navigation that responds to different screen sizes and platforms.

## Components

### NavigationShell (`navigation_shell.dart`)
The main navigation shell that manages app-wide navigation state and screen transitions.

**Features:**
- Manages selected navigation destination
- Handles smooth transitions between screens with fade animations (300ms)
- Provides placeholder screens for all navigation destinations
- Integrates with adaptive navigation for responsive layouts

### AdaptiveNavigation (`adaptive_navigation.dart`)
Responsive navigation component that adapts to screen size:

**Mobile (< 600px):**
- Bottom navigation bar with 5 primary destinations
- Compact layout optimized for touch

**Tablet (600-840px):**
- Compact navigation rail on the left
- Shows all 7 destinations
- Vertical divider separating content

**Desktop (>= 840px):**
- Extended navigation rail with labels
- All 7 destinations visible
- Optional menu button for toggling extended state

### AppNavigation (`app_navigation.dart`)
Defines navigation destinations and their properties:

**Destinations:**
1. Home - Main dashboard
2. Anime - Anime content browser
3. Manga - Manga content browser
4. Search - Global search
5. Library - User's personal library
6. Extensions - Extension management
7. Settings - App settings

**Route Names:**
- Predefined route constants for navigation
- Includes routes for media details, video player, and manga reader

### PageTransitions (`page_transitions.dart`)
Custom page transitions for smooth navigation:

**Available Transitions:**
- `fadeTransition` - Simple fade in/out
- `slideFromRightTransition` - Slide from right edge
- `slideFromBottomTransition` - Slide from bottom
- `scaleTransition` - Scale with fade
- `sharedAxisTransition` - Material Design shared axis (default)

**Custom Route:**
- `CustomPageRoute` - Configurable page route with custom transitions
- Default duration: 300ms (meets requirement 14.3)

**Extensions:**
- `NavigationExtensions` on `BuildContext` for easy navigation
- `pushWithTransition()` - Push with custom transition
- `pushReplacementWithTransition()` - Replace with custom transition

## Usage

### Basic Navigation
```dart
// In main.dart
MaterialApp(
  home: NavigationShell(),
)
```

### Custom Transitions
```dart
// Push with fade transition
context.pushWithTransition(
  MyScreen(),
  transitionsBuilder: AppPageTransitions.fadeTransition,
);

// Push with custom duration
context.pushWithTransition(
  MyScreen(),
  duration: Duration(milliseconds: 500),
);
```

### Accessing Current Destination
```dart
// In NavigationShell
final destination = AppNavigationDestinations.allDestinations[_selectedIndex];
```

## Requirements Satisfied

- **Requirement 10.5**: Smooth animations and transitions (300ms)
- **Requirement 15.6**: Adaptive UI layout based on platform and screen size
- **Requirement 14.3**: Screen transitions complete within 300ms

## Future Enhancements

When implementing actual screens (Task 17), replace the placeholder screens in `NavigationShell._getSelectedScreen()` with real screen implementations:

```dart
case AppDestination.home:
  return const HomeScreen(); // Replace placeholder
case AppDestination.anime:
  return const AnimeScreen(); // Replace placeholder
// ... etc
```

## Architecture

The navigation system follows CLEAN Architecture principles:
- **Presentation Layer**: All navigation components are UI-focused
- **No Business Logic**: Navigation only handles routing and transitions
- **Reusable Components**: Adaptive navigation can be used throughout the app
- **Testable**: Components are designed for easy widget testing
