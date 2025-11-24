# Mobile-Specific Features Implementation

This document describes the mobile-specific features implemented for the Aniya application, including status bar styling, navigation bar styling, and orientation handling.

## Overview

The mobile-specific features are designed to provide a native-like experience on Android and iOS devices by:

1. **Status Bar Styling**: Dynamically adjusting status bar appearance based on theme
2. **Navigation Bar Styling**: Customizing Android navigation bar colors and icons
3. **Orientation Handling**: Managing device orientation with lock/unlock capabilities
4. **Safe Area Management**: Properly handling notches and system UI insets
5. **Theme Integration**: Synchronizing system UI with app theme changes

## Components

### MobilePlatformManager

The core service for managing mobile platform features.

**Key Methods:**

- `initializeMobileFeatures()`: Initialize all mobile features on app startup
- `updateSystemUIForTheme(Brightness)`: Update system UI based on theme brightness
- `lockPortraitOrientation()`: Lock device to portrait mode
- `lockLandscapeOrientation()`: Lock device to landscape mode
- `unlockOrientation()`: Allow all orientations
- `hideStatusBar()`: Hide status bar (immersive mode)
- `showStatusBar()`: Show status bar

**Usage:**

```dart
// Initialize on app startup
await MobilePlatformManager.initializeMobileFeatures();

// Update when theme changes
MobilePlatformManager.updateSystemUIForTheme(Brightness.dark);

// Lock orientation for video player
await MobilePlatformManager.lockLandscapeOrientation();
```

### MobileOrientationListener

Widget that listens to device orientation changes.

**Features:**

- Detects orientation changes automatically
- Calls callback when orientation changes
- Provides `MobileOrientationMixin` for state management

**Usage:**

```dart
MobileOrientationListener(
  onOrientationChanged: (orientation) {
    if (orientation == Orientation.landscape) {
      // Handle landscape
    }
  },
  child: MyScreen(),
)
```

### Safe Area Widgets

Three safe area widgets for different use cases:

#### MobileSafeArea

Basic safe area that respects notches and system UI.

```dart
MobileSafeArea(
  top: true,
  bottom: true,
  child: MyContent(),
)
```

#### MobilePaddedSafeArea

Safe area with additional padding.

```dart
MobilePaddedSafeArea(
  padding: EdgeInsets.all(16),
  child: MyContent(),
)
```

#### MobileSystemUIAwareSafeArea

Advanced safe area with explicit status bar and navigation bar avoidance.

```dart
MobileSystemUIAwareSafeArea(
  avoidStatusBar: true,
  avoidNavigationBar: true,
  additionalPadding: EdgeInsets.all(8),
  child: MyContent(),
)
```

### Status Bar Controller

Widget that manages status bar appearance based on theme.

**Features:**

- Automatically updates status bar brightness
- Responds to theme changes
- Provides `MobileStatusBarScope` for descendant access

**Usage:**

```dart
MobileStatusBarController(
  statusBarBrightness: Brightness.dark,
  child: MyApp(),
)
```

### Navigation Bar Controller

Widget that manages Android navigation bar appearance.

**Features:**

- Updates navigation bar brightness
- Responds to theme changes
- Provides `MobileNavigationBarScope` for descendant access

**Usage:**

```dart
MobileNavigationBarController(
  navigationBarBrightness: Brightness.light,
  child: MyApp(),
)
```

## Integration with Theme System

The mobile features are integrated with the app's theme system:

1. **Theme Provider**: Tracks current theme mode (light, dark, OLED, system)
2. **Status Bar Controller**: Updates status bar when theme changes
3. **Navigation Bar Controller**: Updates navigation bar when theme changes
4. **Automatic Updates**: System UI updates automatically when theme is toggled

**Example:**

```dart
// In main.dart
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
```

## Orientation Handling

### Portrait Mode (Default)

Most screens use portrait mode by default:

```dart
@override
void initState() {
  super.initState();
  MobilePlatformManager.lockPortraitOrientation();
}

@override
void dispose() {
  MobilePlatformManager.unlockOrientation();
  super.dispose();
}
```

### Landscape Mode (Video Player)

Video player locks to landscape:

```dart
@override
void initState() {
  super.initState();
  MobilePlatformManager.lockLandscapeOrientation();
}

@override
void dispose() {
  MobilePlatformManager.unlockOrientation();
  super.dispose();
}
```

### Detecting Orientation Changes

Use `MobileOrientationListener` or `MobileOrientationMixin`:

```dart
class MyScreen extends StatefulWidget {
  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> with MobileOrientationMixin {
  @override
  void onOrientationChanged(Orientation orientation) {
    if (isLandscape) {
      // Handle landscape layout
    } else {
      // Handle portrait layout
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLandscape ? LandscapeLayout() : PortraitLayout(),
    );
  }
}
```

## Best Practices

### 1. Status Bar Styling

- Use transparent status bar for immersive experience
- Adjust icon brightness based on background color
- Update when theme changes

### 2. Navigation Bar Styling (Android)

- Use transparent navigation bar when possible
- Adjust icon brightness for visibility
- Respect system navigation bar color preferences

### 3. Orientation Handling

- Lock orientation only when necessary (e.g., video player)
- Always unlock when leaving the screen
- Use `MobileOrientationListener` for responsive layouts

### 4. Safe Area Management

- Always use safe area widgets on mobile
- Account for notches and system UI
- Test on devices with notches (iPhone X+, Android devices)

### 5. Theme Integration

- Update system UI when theme changes
- Use `MobileStatusBarController` and `MobileNavigationBarController`
- Ensure sufficient contrast for system UI icons

## Testing

Mobile features are tested with:

- Unit tests for `MobilePlatformManager`
- Widget tests for all safe area widgets
- Widget tests for status bar and navigation bar controllers
- Integration tests for orientation handling

Run tests:

```bash
flutter test test/core/services/mobile_platform_manager_test.dart
flutter test test/core/widgets/mobile_widgets_test.dart
```

## Platform-Specific Notes

### Android

- Navigation bar color is set to transparent for edge-to-edge UI
- Status bar icons adjust based on brightness
- Orientation changes are handled by `SystemChrome`

### iOS

- Status bar appearance is managed through `SystemUiOverlayStyle`
- Navigation bar is not customizable on iOS
- Safe area respects notch and home indicator

## Troubleshooting

### Status Bar Not Updating

- Ensure `MobileStatusBarController` wraps the app
- Check that theme provider is notifying listeners
- Verify platform is mobile using `PlatformUtils.isMobile`

### Navigation Bar Not Visible

- Check Android API level (requires API 21+)
- Verify `MobilePlatformManager.initializeMobileFeatures()` is called
- Ensure navigation bar color is set correctly

### Orientation Not Changing

- Verify `SystemChrome.setPreferredOrientations()` is called
- Check that orientation is not locked by system settings
- Ensure orientation is unlocked when leaving screen

## Future Enhancements

- [ ] Support for foldable devices
- [ ] Gesture navigation support
- [ ] Dynamic island support (iOS)
- [ ] Pill-shaped notch support
- [ ] Custom status bar styling per screen
