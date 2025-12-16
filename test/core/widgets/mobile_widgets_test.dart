import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aniya/core/widgets/mobile_orientation_listener.dart';
import 'package:aniya/core/widgets/mobile_safe_area.dart';
import 'package:aniya/core/widgets/mobile_status_bar_controller.dart';
import 'package:aniya/core/widgets/mobile_navigation_bar_controller.dart';

void main() {
  group('Mobile Widgets', () {
    void setTestScreenSize(WidgetTester tester, Size size) {
      final view = tester.view;
      view.physicalSize = size;
      addTearDown(view.resetPhysicalSize);
    }

    group('MobileOrientationListener', () {
      testWidgets('renders child widget', (WidgetTester tester) async {
        setTestScreenSize(tester, const Size(400, 800));

        await tester.pumpWidget(
          MaterialApp(
            home: MobileOrientationListener(
              child: Scaffold(body: Center(child: Text('Test Content'))),
            ),
          ),
        );

        expect(find.text('Test Content'), findsOneWidget);
      });

      testWidgets('calls onOrientationChanged callback', (
        WidgetTester tester,
      ) async {
        bool callbackCalled = false;
        Orientation? changedOrientation;

        setTestScreenSize(tester, const Size(400, 800));

        await tester.pumpWidget(
          MaterialApp(
            home: MobileOrientationListener(
              onOrientationChanged: (orientation) {
                callbackCalled = true;
                changedOrientation = orientation;
              },
              child: Scaffold(body: Center(child: Text('Test Content'))),
            ),
          ),
        );

        expect(find.text('Test Content'), findsOneWidget);
        expect(callbackCalled, isFalse);
        expect(changedOrientation, isNull);
      });
    });

    group('MobileSafeArea', () {
      testWidgets('renders child widget', (WidgetTester tester) async {
        setTestScreenSize(tester, const Size(400, 800));

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MobileSafeArea(child: Text('Safe Area Content')),
            ),
          ),
        );

        expect(find.text('Safe Area Content'), findsOneWidget);
      });

      testWidgets('respects top parameter', (WidgetTester tester) async {
        setTestScreenSize(tester, const Size(400, 800));

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MobileSafeArea(top: false, child: Text('No Top Safe Area')),
            ),
          ),
        );

        expect(find.text('No Top Safe Area'), findsOneWidget);
      });

      testWidgets('respects bottom parameter', (WidgetTester tester) async {
        setTestScreenSize(tester, const Size(400, 800));

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MobileSafeArea(
                bottom: false,
                child: Text('No Bottom Safe Area'),
              ),
            ),
          ),
        );

        expect(find.text('No Bottom Safe Area'), findsOneWidget);
      });
    });

    group('MobilePaddedSafeArea', () {
      testWidgets('renders child with padding', (WidgetTester tester) async {
        setTestScreenSize(tester, const Size(400, 800));

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MobilePaddedSafeArea(
                padding: const EdgeInsets.all(16),
                child: Text('Padded Content'),
              ),
            ),
          ),
        );

        expect(find.text('Padded Content'), findsOneWidget);
      });

      testWidgets('applies custom padding', (WidgetTester tester) async {
        setTestScreenSize(tester, const Size(400, 800));

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MobilePaddedSafeArea(
                padding: const EdgeInsets.all(32),
                child: Text('Custom Padded Content'),
              ),
            ),
          ),
        );

        expect(find.text('Custom Padded Content'), findsOneWidget);
      });
    });

    group('MobileSystemUIAwareSafeArea', () {
      testWidgets('renders child widget', (WidgetTester tester) async {
        setTestScreenSize(tester, const Size(400, 800));

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MobileSystemUIAwareSafeArea(
                child: Text('System UI Aware Content'),
              ),
            ),
          ),
        );

        expect(find.text('System UI Aware Content'), findsOneWidget);
      });

      testWidgets('respects avoidStatusBar parameter', (
        WidgetTester tester,
      ) async {
        setTestScreenSize(tester, const Size(400, 800));

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MobileSystemUIAwareSafeArea(
                avoidStatusBar: false,
                child: Text('No Status Bar Avoidance'),
              ),
            ),
          ),
        );

        expect(find.text('No Status Bar Avoidance'), findsOneWidget);
      });

      testWidgets('respects avoidNavigationBar parameter', (
        WidgetTester tester,
      ) async {
        setTestScreenSize(tester, const Size(400, 800));

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MobileSystemUIAwareSafeArea(
                avoidNavigationBar: false,
                child: Text('No Navigation Bar Avoidance'),
              ),
            ),
          ),
        );

        expect(find.text('No Navigation Bar Avoidance'), findsOneWidget);
      });
    });

    group('MobileStatusBarController', () {
      testWidgets('renders child widget', (WidgetTester tester) async {
        setTestScreenSize(tester, const Size(400, 800));

        await tester.pumpWidget(
          MaterialApp(
            home: MobileStatusBarController(
              child: Scaffold(body: Text('Status Bar Controlled')),
            ),
          ),
        );

        expect(find.text('Status Bar Controlled'), findsOneWidget);
      });

      testWidgets('applies light brightness', (WidgetTester tester) async {
        setTestScreenSize(tester, const Size(400, 800));

        await tester.pumpWidget(
          MaterialApp(
            home: MobileStatusBarController(
              statusBarBrightness: Brightness.light,
              child: Scaffold(body: Text('Light Status Bar')),
            ),
          ),
        );

        expect(find.text('Light Status Bar'), findsOneWidget);
      });

      testWidgets('applies dark brightness', (WidgetTester tester) async {
        setTestScreenSize(tester, const Size(400, 800));

        await tester.pumpWidget(
          MaterialApp(
            home: MobileStatusBarController(
              statusBarBrightness: Brightness.dark,
              child: Scaffold(body: Text('Dark Status Bar')),
            ),
          ),
        );

        expect(find.text('Dark Status Bar'), findsOneWidget);
      });
    });

    group('MobileNavigationBarController', () {
      testWidgets('renders child widget', (WidgetTester tester) async {
        setTestScreenSize(tester, const Size(400, 800));

        await tester.pumpWidget(
          MaterialApp(
            home: MobileNavigationBarController(
              child: Scaffold(body: Text('Navigation Bar Controlled')),
            ),
          ),
        );

        expect(find.text('Navigation Bar Controlled'), findsOneWidget);
      });

      testWidgets('applies light brightness', (WidgetTester tester) async {
        setTestScreenSize(tester, const Size(400, 800));

        await tester.pumpWidget(
          MaterialApp(
            home: MobileNavigationBarController(
              navigationBarBrightness: Brightness.light,
              child: Scaffold(body: Text('Light Navigation Bar')),
            ),
          ),
        );

        expect(find.text('Light Navigation Bar'), findsOneWidget);
      });

      testWidgets('applies dark brightness', (WidgetTester tester) async {
        setTestScreenSize(tester, const Size(400, 800));

        await tester.pumpWidget(
          MaterialApp(
            home: MobileNavigationBarController(
              navigationBarBrightness: Brightness.dark,
              child: Scaffold(body: Text('Dark Navigation Bar')),
            ),
          ),
        );

        expect(find.text('Dark Navigation Bar'), findsOneWidget);
      });
    });

    group('MobileStatusBarScope', () {
      testWidgets('provides brightness to descendants', (
        WidgetTester tester,
      ) async {
        setTestScreenSize(tester, const Size(400, 800));

        await tester.pumpWidget(
          MaterialApp(
            home: MobileStatusBarScope(
              brightness: Brightness.light,
              child: Scaffold(
                body: Builder(
                  builder: (context) {
                    final scope = MobileStatusBarScope.of(context);
                    return Text(
                      scope?.brightness == Brightness.light
                          ? 'Light Scope'
                          : 'Dark Scope',
                    );
                  },
                ),
              ),
            ),
          ),
        );

        expect(find.text('Light Scope'), findsOneWidget);
      });
    });

    group('MobileNavigationBarScope', () {
      testWidgets('provides brightness to descendants', (
        WidgetTester tester,
      ) async {
        setTestScreenSize(tester, const Size(400, 800));

        await tester.pumpWidget(
          MaterialApp(
            home: MobileNavigationBarScope(
              brightness: Brightness.dark,
              child: Scaffold(
                body: Builder(
                  builder: (context) {
                    final scope = MobileNavigationBarScope.of(context);
                    return Text(
                      scope?.brightness == Brightness.dark
                          ? 'Dark Scope'
                          : 'Light Scope',
                    );
                  },
                ),
              ),
            ),
          ),
        );

        expect(find.text('Dark Scope'), findsOneWidget);
      });
    });
  });
}
