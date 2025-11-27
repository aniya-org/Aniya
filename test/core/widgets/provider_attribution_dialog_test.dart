import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aniya/core/widgets/provider_attribution_dialog.dart';
import 'package:aniya/core/widgets/provider_badge.dart';

void main() {
  group('ProviderAttributionDialog', () {
    testWidgets('displays primary provider', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showProviderAttributionDialog(
                      context,
                      primaryProvider: 'tmdb',
                    );
                  },
                  child: const Text('Show Dialog'),
                );
              },
            ),
          ),
        ),
      );

      // Tap the button to show the dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Verify dialog is displayed
      expect(find.text('Data Sources'), findsOneWidget);
      expect(find.text('Primary Source'), findsOneWidget);
      expect(find.byType(ProviderBadge), findsWidgets);
    });

    testWidgets('displays contributing providers', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showProviderAttributionDialog(
                      context,
                      primaryProvider: 'tmdb',
                      contributingProviders: ['anilist', 'kitsu'],
                    );
                  },
                  child: const Text('Show Dialog'),
                );
              },
            ),
          ),
        ),
      );

      // Tap the button to show the dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Verify contributing providers section is displayed
      expect(find.text('Contributing Providers'), findsOneWidget);
    });

    testWidgets('displays match confidence scores', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showProviderAttributionDialog(
                      context,
                      primaryProvider: 'tmdb',
                      matchConfidences: {'anilist': 0.95, 'kitsu': 0.87},
                    );
                  },
                  child: const Text('Show Dialog'),
                );
              },
            ),
          ),
        ),
      );

      // Tap the button to show the dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Verify match confidence section is displayed
      expect(find.text('Match Confidence'), findsOneWidget);
      expect(find.text('95%'), findsOneWidget);
      expect(find.text('87%'), findsOneWidget);
    });

    testWidgets('displays data attribution', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showProviderAttributionDialog(
                      context,
                      primaryProvider: 'tmdb',
                      dataSourceAttribution: {
                        'episodes': 'kitsu',
                        'coverImage': 'tmdb',
                      },
                    );
                  },
                  child: const Text('Show Dialog'),
                );
              },
            ),
          ),
        ),
      );

      // Tap the button to show the dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Verify data attribution section is displayed
      expect(find.text('Data Attribution'), findsOneWidget);
      expect(find.text('Episodes'), findsOneWidget);
      expect(find.text('Cover Image'), findsOneWidget);
    });

    testWidgets('close button dismisses dialog', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showProviderAttributionDialog(
                      context,
                      primaryProvider: 'tmdb',
                    );
                  },
                  child: const Text('Show Dialog'),
                );
              },
            ),
          ),
        ),
      );

      // Tap the button to show the dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Verify dialog is displayed
      expect(find.text('Data Sources'), findsOneWidget);

      // Tap close button
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      // Verify dialog is dismissed
      expect(find.text('Data Sources'), findsNothing);
    });
  });

  group('ProviderBadge', () {
    testWidgets('displays provider name and icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ProviderBadge(providerId: 'tmdb')),
        ),
      );

      expect(find.text('TMDB'), findsOneWidget);
      expect(find.byIcon(Icons.movie), findsOneWidget);
    });

    testWidgets('handles tap callback', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderBadge(
              providerId: 'tmdb',
              onTap: () {
                tapped = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ProviderBadge));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('displays small variant', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProviderBadge(providerId: 'tmdb', isSmall: true),
          ),
        ),
      );

      expect(find.text('TMDB'), findsOneWidget);
    });
  });

  group('ProviderBadgeList', () {
    testWidgets('displays multiple provider badges', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProviderBadgeList(providers: ['tmdb', 'anilist', 'kitsu']),
          ),
        ),
      );

      expect(find.text('TMDB'), findsOneWidget);
      expect(find.text('AniList'), findsOneWidget);
      expect(find.text('Kitsu'), findsOneWidget);
    });

    testWidgets('handles empty provider list', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ProviderBadgeList(providers: [])),
        ),
      );

      expect(find.byType(ProviderBadge), findsNothing);
    });

    testWidgets('handles tap callback for each provider', (
      WidgetTester tester,
    ) async {
      String? tappedProvider;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderBadgeList(
              providers: ['tmdb', 'anilist'],
              onProviderTap: (provider) {
                tappedProvider = provider;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('TMDB'));
      await tester.pumpAndSettle();

      expect(tappedProvider, equals('tmdb'));
    });
  });
}
