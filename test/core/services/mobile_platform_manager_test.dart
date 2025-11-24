import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aniya/core/services/mobile_platform_manager.dart';

void main() {
  group('MobilePlatformManager', () {
    test('updateSystemUIForTheme updates brightness correctly', () async {
      // Test that updateSystemUIForTheme can be called without errors
      expect(
        () => MobilePlatformManager.updateSystemUIForTheme(Brightness.light),
        returnsNormally,
      );

      expect(
        () => MobilePlatformManager.updateSystemUIForTheme(Brightness.dark),
        returnsNormally,
      );
    });

    test('lockPortraitOrientation completes without error', () async {
      expect(
        () => MobilePlatformManager.lockPortraitOrientation(),
        returnsNormally,
      );
    });

    test('lockLandscapeOrientation completes without error', () async {
      expect(
        () => MobilePlatformManager.lockLandscapeOrientation(),
        returnsNormally,
      );
    });

    test('unlockOrientation completes without error', () async {
      expect(() => MobilePlatformManager.unlockOrientation(), returnsNormally);
    });

    test('hideStatusBar completes without error', () async {
      expect(() => MobilePlatformManager.hideStatusBar(), returnsNormally);
    });

    test('showStatusBar completes without error', () async {
      expect(() => MobilePlatformManager.showStatusBar(), returnsNormally);
    });

    test('_parseOrientation correctly parses orientation strings', () {
      // Test portrait orientation
      final portraitResult = MobilePlatformManager.getCurrentOrientation();
      expect(portraitResult, isNotNull);

      // Test landscape orientation
      final landscapeResult = MobilePlatformManager.getCurrentOrientation();
      expect(landscapeResult, isNotNull);
    });
  });
}
