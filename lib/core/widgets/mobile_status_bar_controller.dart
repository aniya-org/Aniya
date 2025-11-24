import 'package:flutter/material.dart';
import 'package:aniya/core/services/mobile_platform_manager.dart';
import 'package:aniya/core/utils/platform_utils.dart';

/// Widget that controls status bar appearance based on theme
class MobileStatusBarController extends StatefulWidget {
  final Widget child;
  final Brightness? statusBarBrightness;

  const MobileStatusBarController({
    super.key,
    required this.child,
    this.statusBarBrightness,
  });

  @override
  State<MobileStatusBarController> createState() =>
      _MobileStatusBarControllerState();
}

class _MobileStatusBarControllerState extends State<MobileStatusBarController> {
  @override
  void initState() {
    super.initState();
    _updateStatusBar();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateStatusBar();
  }

  void _updateStatusBar() {
    if (!PlatformUtils.isMobile) return;

    final brightness =
        widget.statusBarBrightness ?? Theme.of(context).brightness;

    MobilePlatformManager.updateSystemUIForTheme(brightness);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Inherited widget for managing status bar state across the widget tree
class MobileStatusBarScope extends InheritedWidget {
  final Brightness brightness;
  final VoidCallback? onBrightnessChanged;

  const MobileStatusBarScope({
    super.key,
    required this.brightness,
    required super.child,
    this.onBrightnessChanged,
  });

  static MobileStatusBarScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<MobileStatusBarScope>();
  }

  @override
  bool updateShouldNotify(MobileStatusBarScope oldWidget) {
    return brightness != oldWidget.brightness;
  }
}
