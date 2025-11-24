import 'package:flutter/material.dart';
import 'package:aniya/core/utils/platform_utils.dart';

/// Callback for orientation changes
typedef OrientationChangedCallback = void Function(Orientation orientation);

/// Widget that listens to orientation changes on mobile devices
class MobileOrientationListener extends StatefulWidget {
  final Widget child;
  final OrientationChangedCallback? onOrientationChanged;

  const MobileOrientationListener({
    super.key,
    required this.child,
    this.onOrientationChanged,
  });

  @override
  State<MobileOrientationListener> createState() =>
      _MobileOrientationListenerState();
}

class _MobileOrientationListenerState extends State<MobileOrientationListener>
    with WidgetsBindingObserver {
  late Orientation _currentOrientation;

  @override
  void initState() {
    super.initState();
    if (PlatformUtils.isMobile) {
      WidgetsBinding.instance.addObserver(this);
      _currentOrientation = MediaQuery.of(context).orientation;
    }
  }

  @override
  void dispose() {
    if (PlatformUtils.isMobile) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle changes if needed
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!PlatformUtils.isMobile) return;

    final newOrientation = MediaQuery.of(context).orientation;
    if (_currentOrientation != newOrientation) {
      _currentOrientation = newOrientation;
      widget.onOrientationChanged?.call(newOrientation);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Mixin for widgets that need to respond to orientation changes
mixin MobileOrientationMixin on State {
  late Orientation _currentOrientation;

  @override
  void initState() {
    super.initState();
    if (PlatformUtils.isMobile) {
      WidgetsBinding.instance.addObserver(this as WidgetsBindingObserver);
      _currentOrientation = MediaQuery.of(context).orientation;
    }
  }

  @override
  void dispose() {
    if (PlatformUtils.isMobile) {
      WidgetsBinding.instance.removeObserver(this as WidgetsBindingObserver);
    }
    super.dispose();
  }

  /// Get current orientation
  Orientation get currentOrientation => _currentOrientation;

  /// Check if in portrait mode
  bool get isPortrait => _currentOrientation == Orientation.portrait;

  /// Check if in landscape mode
  bool get isLandscape => _currentOrientation == Orientation.landscape;

  /// Called when orientation changes
  void onOrientationChanged(Orientation orientation) {}
}
