import 'package:flutter_test/flutter_test.dart';
import 'package:aniya/core/services/responsive_layout_manager.dart';

void main() {
  group('ResponsiveLayoutManager', () {
    group('getScreenType', () {
      test('returns mobile for width < 600', () {
        expect(ResponsiveLayoutManager.getScreenType(500), ScreenType.mobile);
      });

      test('returns tablet for 600 <= width < 840', () {
        expect(ResponsiveLayoutManager.getScreenType(700), ScreenType.tablet);
      });

      test('returns desktop for 840 <= width < 1200', () {
        expect(ResponsiveLayoutManager.getScreenType(1000), ScreenType.desktop);
      });

      test('returns largeDesktop for width >= 1200', () {
        expect(
          ResponsiveLayoutManager.getScreenType(1400),
          ScreenType.largeDesktop,
        );
      });
    });

    group('screen type checks', () {
      test('isMobile returns true for mobile width', () {
        expect(ResponsiveLayoutManager.isMobile(500), true);
        expect(ResponsiveLayoutManager.isMobile(700), false);
      });

      test('isTablet returns true for tablet width', () {
        expect(ResponsiveLayoutManager.isTablet(700), true);
        expect(ResponsiveLayoutManager.isTablet(500), false);
        expect(ResponsiveLayoutManager.isTablet(1000), false);
      });

      test('isDesktop returns true for desktop width', () {
        expect(ResponsiveLayoutManager.isDesktop(1000), true);
        expect(ResponsiveLayoutManager.isDesktop(500), false);
      });

      test('isLargeDesktop returns true for large desktop width', () {
        expect(ResponsiveLayoutManager.isLargeDesktop(1400), true);
        expect(ResponsiveLayoutManager.isLargeDesktop(1000), false);
      });
    });

    group('getPadding', () {
      test('returns appropriate padding for each screen type', () {
        final mobilePadding = ResponsiveLayoutManager.getPadding(500);
        final tabletPadding = ResponsiveLayoutManager.getPadding(700);
        final desktopPadding = ResponsiveLayoutManager.getPadding(1000);
        final largeDesktopPadding = ResponsiveLayoutManager.getPadding(1400);

        expect(mobilePadding.top, 16);
        expect(tabletPadding.top, 24);
        expect(desktopPadding.top, 32);
        expect(largeDesktopPadding.top, 48);
      });
    });

    group('getGridColumns', () {
      test('returns 2 columns for mobile', () {
        expect(ResponsiveLayoutManager.getGridColumns(500), 2);
      });

      test('returns 3 columns for tablet', () {
        expect(ResponsiveLayoutManager.getGridColumns(700), 3);
      });

      test('returns 4 columns for desktop', () {
        expect(ResponsiveLayoutManager.getGridColumns(1000), 4);
      });

      test('returns 6 columns for large desktop', () {
        expect(ResponsiveLayoutManager.getGridColumns(1400), 6);
      });
    });

    group('getFontScale', () {
      test('returns appropriate font scale for each screen type', () {
        expect(ResponsiveLayoutManager.getFontScale(500), 1.0);
        expect(ResponsiveLayoutManager.getFontScale(700), 1.1);
        expect(ResponsiveLayoutManager.getFontScale(1000), 1.2);
        expect(ResponsiveLayoutManager.getFontScale(1400), 1.3);
      });
    });

    group('getMaxContentWidth', () {
      test('returns full width for mobile and tablet', () {
        expect(ResponsiveLayoutManager.getMaxContentWidth(500), 500);
        expect(ResponsiveLayoutManager.getMaxContentWidth(700), 700);
      });

      test('returns constrained width for desktop', () {
        expect(ResponsiveLayoutManager.getMaxContentWidth(1000), 1200);
        expect(ResponsiveLayoutManager.getMaxContentWidth(1400), 1400);
      });
    });

    group('getSpacing', () {
      test('returns appropriate spacing for each screen type', () {
        expect(ResponsiveLayoutManager.getSpacing(500), 8);
        expect(ResponsiveLayoutManager.getSpacing(700), 12);
        expect(ResponsiveLayoutManager.getSpacing(1000), 16);
        expect(ResponsiveLayoutManager.getSpacing(1400), 20);
      });
    });

    group('getNavigationRailWidth', () {
      test('returns 80 for compact rail', () {
        expect(ResponsiveLayoutManager.getNavigationRailWidth(false), 80);
      });

      test('returns 256 for extended rail', () {
        expect(ResponsiveLayoutManager.getNavigationRailWidth(true), 256);
      });
    });
  });
}
