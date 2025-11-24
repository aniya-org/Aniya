import 'package:flutter/material.dart';
import 'package:aniya/core/services/mobile_platform_manager.dart';
import 'package:aniya/core/utils/platform_utils.dart';

/// Widget that controls navigation bar appearance based on theme
class MobileNavigationBarController extends StatefulWidget {
  final Widget child;
  final Brightness? navigationBarBrightness;
  final Color? navigationBarColor;

  const MobileNavigationBarController({
    super.key,
    required this.child,
    this.navigationBarBrightness,
    this.navigationBarColor,
  });

  @override
  State<MobileNavigationBarController> createState() =>
      _MobileNavigationBarControllerState();
}

class _MobileNavigationBarControllerState
    extends State<MobileNavigationBarController> {
  @override
  void initState() {
    super.initState();
    _updateNavigationBar();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateNavigationBar();
  }

  void _updateNavigationBar() {
    if (!PlatformUtils.isAndroid) return;

    final brightness =
        widget.navigationBarBrightness ?? Theme.of(context).brightness;

    MobilePlatformManager.updateSystemUIForTheme(brightness);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Inherited widget for managing navigation bar state across the widget tree
class MobileNavigationBarScope extends InheritedWidget {
  final Brightness brightness;
  final Color? backgroundColor;
  final VoidCallback? onBrightnessChanged;

  const MobileNavigationBarScope({
    super.key,
    required this.brightness,
    required super.child,
    this.backgroundColor,
    this.onBrightnessChanged,
  });

  static MobileNavigationBarScope? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<MobileNavigationBarScope>();
  }

  @override
  bool updateShouldNotify(MobileNavigationBarScope oldWidget) {
    return brightness != oldWidget.brightness ||
        backgroundColor != oldWidget.backgroundColor;
  }
}
