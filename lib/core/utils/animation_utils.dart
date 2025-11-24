import 'package:flutter/material.dart';
import '../navigation/page_transitions.dart';

/// Utility class for common animation patterns
class AnimationUtils {
  // Private constructor to prevent instantiation
  AnimationUtils._();

  /// Navigate to a new screen with fade transition
  static Future<T?> navigateWithFade<T>(BuildContext context, Widget page) {
    return Navigator.of(context).push<T>(
      CustomPageRoute(
        builder: (_) => page,
        transitionsBuilder: AppPageTransitions.fadeTransition,
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  /// Navigate to a new screen with slide from right transition
  static Future<T?> navigateWithSlideRight<T>(
    BuildContext context,
    Widget page,
  ) {
    return Navigator.of(context).push<T>(
      CustomPageRoute(
        builder: (_) => page,
        transitionsBuilder: AppPageTransitions.slideFromRightTransition,
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  /// Navigate to a new screen with slide from bottom transition
  static Future<T?> navigateWithSlideUp<T>(BuildContext context, Widget page) {
    return Navigator.of(context).push<T>(
      CustomPageRoute(
        builder: (_) => page,
        transitionsBuilder: AppPageTransitions.slideFromBottomTransition,
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  /// Navigate to a new screen with scale transition
  static Future<T?> navigateWithScale<T>(BuildContext context, Widget page) {
    return Navigator.of(context).push<T>(
      CustomPageRoute(
        builder: (_) => page,
        transitionsBuilder: AppPageTransitions.scaleTransition,
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  /// Navigate to a new screen with shared axis transition
  static Future<T?> navigateWithSharedAxis<T>(
    BuildContext context,
    Widget page,
  ) {
    return Navigator.of(context).push<T>(
      CustomPageRoute(
        builder: (_) => page,
        transitionsBuilder: AppPageTransitions.sharedAxisTransition,
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  /// Navigate to a new screen with custom transition
  static Future<T?> navigateWithCustom<T>(
    BuildContext context,
    Widget page, {
    required RouteTransitionsBuilder transitionsBuilder,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return Navigator.of(context).push<T>(
      CustomPageRoute(
        builder: (_) => page,
        transitionsBuilder: transitionsBuilder,
        transitionDuration: duration,
      ),
    );
  }

  /// Replace current screen with fade transition
  static Future<T?> replaceWithFade<T, TO>(BuildContext context, Widget page) {
    return Navigator.of(context).pushReplacement<T, TO>(
      CustomPageRoute(
        builder: (_) => page,
        transitionsBuilder: AppPageTransitions.fadeTransition,
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  /// Replace current screen with slide transition
  static Future<T?> replaceWithSlide<T, TO>(BuildContext context, Widget page) {
    return Navigator.of(context).pushReplacement<T, TO>(
      CustomPageRoute(
        builder: (_) => page,
        transitionsBuilder: AppPageTransitions.slideFromRightTransition,
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  /// Create a staggered animation for list items
  static Widget buildStaggeredListItem({
    required BuildContext context,
    required int index,
    required Animation<double> animation,
    required Widget child,
  }) {
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
          .animate(
            CurvedAnimation(
              parent: animation,
              curve: Interval(
                (index / 10).clamp(0.0, 1.0),
                ((index + 1) / 10).clamp(0.0, 1.0),
                curve: Curves.easeInOut,
              ),
            ),
          ),
      child: FadeTransition(opacity: animation, child: child),
    );
  }

  /// Create a bounce animation
  static Animation<double> createBounceAnimation(
    AnimationController controller,
  ) {
    return Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.elasticOut));
  }

  /// Create a smooth fade animation
  static Animation<double> createFadeAnimation(AnimationController controller) {
    return Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
  }

  /// Create a slide animation
  static Animation<Offset> createSlideAnimation(
    AnimationController controller, {
    Offset begin = const Offset(0, 1),
    Offset end = Offset.zero,
  }) {
    return Tween<Offset>(
      begin: begin,
      end: end,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
  }

  /// Create a scale animation
  static Animation<double> createScaleAnimation(
    AnimationController controller, {
    double begin = 0.8,
    double end = 1.0,
  }) {
    return Tween<double>(
      begin: begin,
      end: end,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
  }
}

/// Extension on BuildContext for easy animation-based navigation
extension AnimationNavigationExtension on BuildContext {
  /// Navigate with fade transition
  Future<T?> navigateFade<T>(Widget page) =>
      AnimationUtils.navigateWithFade<T>(this, page);

  /// Navigate with slide right transition
  Future<T?> navigateSlideRight<T>(Widget page) =>
      AnimationUtils.navigateWithSlideRight<T>(this, page);

  /// Navigate with slide up transition
  Future<T?> navigateSlideUp<T>(Widget page) =>
      AnimationUtils.navigateWithSlideUp<T>(this, page);

  /// Navigate with scale transition
  Future<T?> navigateScale<T>(Widget page) =>
      AnimationUtils.navigateWithScale<T>(this, page);

  /// Navigate with shared axis transition
  Future<T?> navigateSharedAxis<T>(Widget page) =>
      AnimationUtils.navigateWithSharedAxis<T>(this, page);
}
