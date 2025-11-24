import 'package:flutter_test/flutter_test.dart';
import 'package:aniya/core/utils/platform_utils.dart';

void main() {
  group('PlatformUtils', () {
    test('isDesktop, isMobile, isWeb are mutually exclusive', () {
      // At most one should be true
      final trueCount = [
        PlatformUtils.isDesktop,
        PlatformUtils.isMobile,
        PlatformUtils.isWeb,
      ].where((v) => v).length;

      expect(trueCount, lessThanOrEqualTo(1));
    });

    test('platform-specific checks are consistent', () {
      // If isAndroid is true, isMobile should be true
      if (PlatformUtils.isAndroid) {
        expect(PlatformUtils.isMobile, true);
      }

      // If isIOS is true, isMobile should be true
      if (PlatformUtils.isIOS) {
        expect(PlatformUtils.isMobile, true);
      }

      // If isWindows, isMacOS, or isLinux is true, isDesktop should be true
      if (PlatformUtils.isWindows ||
          PlatformUtils.isMacOS ||
          PlatformUtils.isLinux) {
        expect(PlatformUtils.isDesktop, true);
      }
    });

    test('desktop platforms are mutually exclusive', () {
      final desktopCount = [
        PlatformUtils.isWindows,
        PlatformUtils.isMacOS,
        PlatformUtils.isLinux,
      ].where((v) => v).length;

      expect(desktopCount, lessThanOrEqualTo(1));
    });

    test('mobile platforms are mutually exclusive', () {
      final mobileCount = [
        PlatformUtils.isAndroid,
        PlatformUtils.isIOS,
      ].where((v) => v).length;

      expect(mobileCount, lessThanOrEqualTo(1));
    });
  });
}
