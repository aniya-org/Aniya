import 'package:flutter/material.dart';
import 'package:aniya/core/utils/platform_utils.dart';

/// Mobile-optimized safe area widget that handles notches and system UI
class MobileSafeArea extends StatelessWidget {
  final Widget child;
  final bool top;
  final bool bottom;
  final bool left;
  final bool right;
  final EdgeInsets? minimum;

  const MobileSafeArea({
    super.key,
    required this.child,
    this.top = true,
    this.bottom = true,
    this.left = true,
    this.right = true,
    this.minimum,
  });

  @override
  Widget build(BuildContext context) {
    if (!PlatformUtils.isMobile) {
      return child;
    }

    return SafeArea(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      minimum: minimum ?? EdgeInsets.zero,
      child: child,
    );
  }
}

/// Widget that provides safe area padding for mobile devices
class MobilePaddedSafeArea extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final bool top;
  final bool bottom;
  final bool left;
  final bool right;

  const MobilePaddedSafeArea({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.top = true,
    this.bottom = true,
    this.left = true,
    this.right = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!PlatformUtils.isMobile) {
      return Padding(padding: padding, child: child);
    }

    return SafeArea(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Widget that handles status bar and navigation bar safe areas
class MobileSystemUIAwareSafeArea extends StatelessWidget {
  final Widget child;
  final bool avoidStatusBar;
  final bool avoidNavigationBar;
  final EdgeInsets? additionalPadding;

  const MobileSystemUIAwareSafeArea({
    super.key,
    required this.child,
    this.avoidStatusBar = true,
    this.avoidNavigationBar = true,
    this.additionalPadding,
  });

  @override
  Widget build(BuildContext context) {
    if (!PlatformUtils.isMobile) {
      return child;
    }

    final mediaQuery = MediaQuery.of(context);
    EdgeInsets padding = EdgeInsets.zero;

    if (avoidStatusBar) {
      padding = padding.copyWith(top: mediaQuery.padding.top);
    }

    if (avoidNavigationBar) {
      padding = padding.copyWith(bottom: mediaQuery.padding.bottom);
    }

    if (additionalPadding != null) {
      padding = EdgeInsets.fromLTRB(
        padding.left + additionalPadding!.left,
        padding.top + additionalPadding!.top,
        padding.right + additionalPadding!.right,
        padding.bottom + additionalPadding!.bottom,
      );
    }

    return Padding(padding: padding, child: child);
  }
}
