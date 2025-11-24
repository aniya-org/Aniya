import 'package:flutter/material.dart';
import 'package:aniya/core/services/responsive_layout_manager.dart';

/// A responsive screen widget that adapts layout based on screen size
class ResponsiveScreen extends StatelessWidget {
  final String title;
  final Widget Function(BuildContext context, ScreenType screenType) builder;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final bool showAppBar;

  const ResponsiveScreen({
    super.key,
    required this.title,
    required this.builder,
    this.appBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.showAppBar = true,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, screenType) {
        return Scaffold(
          appBar: showAppBar
              ? appBar ?? AppBar(title: Text(title), elevation: 0)
              : null,
          body: SafeArea(child: builder(context, screenType)),
          floatingActionButton: floatingActionButton,
          floatingActionButtonLocation: floatingActionButtonLocation,
        );
      },
    );
  }
}

/// A responsive grid view that adapts column count based on screen size
class ResponsiveGridView extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsets padding;
  final double spacing;
  final ScrollPhysics? physics;

  const ResponsiveGridView({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.all(16),
    this.spacing = 16,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, screenType) {
        final columnCount = ResponsiveLayoutManager.getGridColumns(
          MediaQuery.of(context).size.width,
        );

        return GridView.count(
          crossAxisCount: columnCount,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          padding: padding,
          physics: physics ?? const AlwaysScrollableScrollPhysics(),
          children: children,
        );
      },
    );
  }
}

/// A responsive list view that adapts padding based on screen size
class ResponsiveListView extends StatelessWidget {
  final List<Widget> children;
  final ScrollPhysics? physics;
  final bool shrinkWrap;

  const ResponsiveListView({
    super.key,
    required this.children,
    this.physics,
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, screenType) {
        final padding = ResponsiveLayoutManager.getPadding(
          MediaQuery.of(context).size.width,
        );

        return ListView(
          padding: padding,
          physics: physics ?? const AlwaysScrollableScrollPhysics(),
          shrinkWrap: shrinkWrap,
          children: children,
        );
      },
    );
  }
}

/// A responsive container that constrains content width on large screens
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, screenType) {
        final maxWidth = ResponsiveLayoutManager.getMaxContentWidth(
          MediaQuery.of(context).size.width,
        );
        final screenWidth = MediaQuery.of(context).size.width;

        if (screenWidth > maxWidth) {
          return Center(
            child: SizedBox(
              width: maxWidth,
              child: Padding(padding: padding, child: child),
            ),
          );
        }

        return Padding(padding: padding, child: child);
      },
    );
  }
}

/// A responsive row that switches to column on mobile
class ResponsiveRow extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;
  final double spacing;

  const ResponsiveRow({
    super.key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.max,
    this.spacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, screenType) {
        if (screenType == ScreenType.mobile) {
          return Column(
            mainAxisAlignment: mainAxisAlignment,
            crossAxisAlignment: crossAxisAlignment,
            mainAxisSize: mainAxisSize,
            children: _addSpacing(children, spacing),
          );
        }

        return Row(
          mainAxisAlignment: mainAxisAlignment,
          crossAxisAlignment: crossAxisAlignment,
          mainAxisSize: mainAxisSize,
          children: _addSpacing(children, spacing),
        );
      },
    );
  }

  List<Widget> _addSpacing(List<Widget> widgets, double spacing) {
    if (widgets.isEmpty) return widgets;

    final result = <Widget>[];
    for (int i = 0; i < widgets.length; i++) {
      result.add(widgets[i]);
      if (i < widgets.length - 1) {
        result.add(SizedBox(width: spacing, height: spacing));
      }
    }
    return result;
  }
}
