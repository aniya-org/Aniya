import 'package:flutter/material.dart';
import 'app_navigation.dart';

/// InheritedWidget that provides navigation control to descendant widgets
class NavigationController extends InheritedWidget {
  final Function(AppDestination) navigateTo;

  const NavigationController({
    super.key,
    required this.navigateTo,
    required super.child,
  });

  static NavigationController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<NavigationController>();
  }

  static NavigationController of(BuildContext context) {
    final NavigationController? result = maybeOf(context);
    assert(result != null, 'No NavigationController found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(NavigationController oldWidget) {
    return false;
  }
}
