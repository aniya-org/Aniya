import 'package:flutter/material.dart';

/// Transition type enum
enum TransitionType {
  fade,
  slideRight,
  slideLeft,
  slideUp,
  slideDown,
  scale,
  sharedAxis,
  rotation,
}

/// Custom page transitions for smooth navigation
class AppPageTransitions {
  /// Fade transition
  static Widget fadeTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(opacity: animation, child: child);
  }

  /// Slide from right transition
  static Widget slideFromRightTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    const begin = Offset(1.0, 0.0);
    const end = Offset.zero;
    const curve = Curves.easeInOut;

    var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

    return SlideTransition(position: animation.drive(tween), child: child);
  }

  /// Slide from left transition
  static Widget slideFromLeftTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    const begin = Offset(-1.0, 0.0);
    const end = Offset.zero;
    const curve = Curves.easeInOut;

    var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

    return SlideTransition(position: animation.drive(tween), child: child);
  }

  /// Slide from bottom transition
  static Widget slideFromBottomTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    const begin = Offset(0.0, 1.0);
    const end = Offset.zero;
    const curve = Curves.easeInOut;

    var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

    return SlideTransition(position: animation.drive(tween), child: child);
  }

  /// Slide from top transition
  static Widget slideFromTopTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    const begin = Offset(0.0, -1.0);
    const end = Offset.zero;
    const curve = Curves.easeInOut;

    var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

    return SlideTransition(position: animation.drive(tween), child: child);
  }

  /// Scale transition
  static Widget scaleTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return ScaleTransition(
      scale: Tween<double>(
        begin: 0.8,
        end: 1.0,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut)),
      child: FadeTransition(opacity: animation, child: child),
    );
  }

  /// Shared axis transition (Material Design)
  static Widget sharedAxisTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.0, 0.05),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut)),
        child: child,
      ),
    );
  }

  /// Rotation transition
  static Widget rotationTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return RotationTransition(
      turns: Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut)),
      child: FadeTransition(opacity: animation, child: child),
    );
  }

  /// Get transition builder by type
  static RouteTransitionsBuilder getTransitionBuilder(TransitionType type) {
    switch (type) {
      case TransitionType.fade:
        return fadeTransition;
      case TransitionType.slideRight:
        return slideFromRightTransition;
      case TransitionType.slideLeft:
        return slideFromLeftTransition;
      case TransitionType.slideUp:
        return slideFromBottomTransition;
      case TransitionType.slideDown:
        return slideFromTopTransition;
      case TransitionType.scale:
        return scaleTransition;
      case TransitionType.sharedAxis:
        return sharedAxisTransition;
      case TransitionType.rotation:
        return rotationTransition;
    }
  }
}

/// Custom page route with configurable transitions
class CustomPageRoute<T> extends PageRoute<T> {
  final WidgetBuilder builder;
  final RouteTransitionsBuilder? transitionsBuilder;
  final Duration _transitionDuration;

  CustomPageRoute({
    required this.builder,
    this.transitionsBuilder,
    Duration transitionDuration = const Duration(milliseconds: 300),
    super.settings,
  }) : _transitionDuration = transitionDuration;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => _transitionDuration;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (transitionsBuilder != null) {
      return transitionsBuilder!(context, animation, secondaryAnimation, child);
    }
    return AppPageTransitions.sharedAxisTransition(
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}

/// Extension on BuildContext for easy navigation
extension NavigationExtensions on BuildContext {
  /// Push a new route with custom transition
  Future<T?> pushWithTransition<T>(
    Widget page, {
    RouteTransitionsBuilder? transitionsBuilder,
    Duration? duration,
  }) {
    return Navigator.of(this).push<T>(
      CustomPageRoute<T>(
        builder: (_) => page,
        transitionsBuilder: transitionsBuilder,
        transitionDuration: duration ?? const Duration(milliseconds: 300),
      ),
    );
  }

  /// Push and replace with custom transition
  Future<T?> pushReplacementWithTransition<T, TO>(
    Widget page, {
    RouteTransitionsBuilder? transitionsBuilder,
    Duration? duration,
  }) {
    return Navigator.of(this).pushReplacement<T, TO>(
      CustomPageRoute<T>(
        builder: (_) => page,
        transitionsBuilder: transitionsBuilder,
        transitionDuration: duration ?? const Duration(milliseconds: 300),
      ),
    );
  }
}
