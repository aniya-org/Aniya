import 'package:flutter/material.dart';

/// Breakpoints for responsive design
class ResponsiveBreakpoints {
  /// Mobile breakpoint (< 600dp)
  static const double mobile = 600;

  /// Tablet breakpoint (600dp - 840dp)
  static const double tablet = 840;

  /// Desktop breakpoint (>= 840dp)
  static const double desktop = 840;

  /// Large desktop breakpoint (>= 1200dp)
  static const double largeDesktop = 1200;
}

/// Enum for device screen type
enum ScreenType { mobile, tablet, desktop, largeDesktop }

/// Service for managing responsive layouts
class ResponsiveLayoutManager {
  /// Get screen type based on width
  static ScreenType getScreenType(double width) {
    if (width < ResponsiveBreakpoints.mobile) {
      return ScreenType.mobile;
    } else if (width < ResponsiveBreakpoints.tablet) {
      return ScreenType.tablet;
    } else if (width < ResponsiveBreakpoints.largeDesktop) {
      return ScreenType.desktop;
    } else {
      return ScreenType.largeDesktop;
    }
  }

  /// Check if screen is mobile
  static bool isMobile(double width) {
    return width < ResponsiveBreakpoints.mobile;
  }

  /// Check if screen is tablet
  static bool isTablet(double width) {
    return width >= ResponsiveBreakpoints.mobile &&
        width < ResponsiveBreakpoints.tablet;
  }

  /// Check if screen is desktop
  static bool isDesktop(double width) {
    return width >= ResponsiveBreakpoints.desktop;
  }

  /// Check if screen is large desktop
  static bool isLargeDesktop(double width) {
    return width >= ResponsiveBreakpoints.largeDesktop;
  }

  /// Get padding based on screen type
  static EdgeInsets getPadding(double width) {
    final screenType = getScreenType(width);
    switch (screenType) {
      case ScreenType.mobile:
        return const EdgeInsets.all(16);
      case ScreenType.tablet:
        return const EdgeInsets.all(24);
      case ScreenType.desktop:
        return const EdgeInsets.all(32);
      case ScreenType.largeDesktop:
        return const EdgeInsets.all(48);
    }
  }

  /// Get grid column count based on screen type
  static int getGridColumns(double width) {
    final screenType = getScreenType(width);
    switch (screenType) {
      case ScreenType.mobile:
        return 2;
      case ScreenType.tablet:
        return 3;
      case ScreenType.desktop:
        return 4;
      case ScreenType.largeDesktop:
        return 6;
    }
  }

  /// Get font scale based on screen type
  static double getFontScale(double width) {
    final screenType = getScreenType(width);
    switch (screenType) {
      case ScreenType.mobile:
        return 1.0;
      case ScreenType.tablet:
        return 1.1;
      case ScreenType.desktop:
        return 1.2;
      case ScreenType.largeDesktop:
        return 1.3;
    }
  }

  /// Get max content width for desktop layouts
  static double getMaxContentWidth(double width) {
    final screenType = getScreenType(width);
    switch (screenType) {
      case ScreenType.mobile:
        return width;
      case ScreenType.tablet:
        return width;
      case ScreenType.desktop:
        return 1200;
      case ScreenType.largeDesktop:
        return 1400;
    }
  }

  /// Get navigation rail width
  static double getNavigationRailWidth(bool extended) {
    return extended ? 256 : 80;
  }

  /// Get spacing based on screen type
  static double getSpacing(double width) {
    final screenType = getScreenType(width);
    switch (screenType) {
      case ScreenType.mobile:
        return 8;
      case ScreenType.tablet:
        return 12;
      case ScreenType.desktop:
        return 16;
      case ScreenType.largeDesktop:
        return 20;
    }
  }
}

/// Widget for responsive layout building
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, ScreenType screenType) builder;

  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenType = ResponsiveLayoutManager.getScreenType(
          constraints.maxWidth,
        );
        return builder(context, screenType);
      },
    );
  }
}

/// Widget for mobile-only content
class MobileOnly extends StatelessWidget {
  final Widget child;

  const MobileOnly({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, screenType) {
        if (screenType == ScreenType.mobile) {
          return child;
        }
        return const SizedBox.shrink();
      },
    );
  }
}

/// Widget for tablet-only content
class TabletOnly extends StatelessWidget {
  final Widget child;

  const TabletOnly({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, screenType) {
        if (screenType == ScreenType.tablet) {
          return child;
        }
        return const SizedBox.shrink();
      },
    );
  }
}

/// Widget for desktop-only content
class DesktopOnly extends StatelessWidget {
  final Widget child;

  const DesktopOnly({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, screenType) {
        if (screenType == ScreenType.desktop ||
            screenType == ScreenType.largeDesktop) {
          return child;
        }
        return const SizedBox.shrink();
      },
    );
  }
}

/// Widget for mobile and tablet content
class MobileAndTabletOnly extends StatelessWidget {
  final Widget child;

  const MobileAndTabletOnly({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, screenType) {
        if (screenType == ScreenType.mobile ||
            screenType == ScreenType.tablet) {
          return child;
        }
        return const SizedBox.shrink();
      },
    );
  }
}
