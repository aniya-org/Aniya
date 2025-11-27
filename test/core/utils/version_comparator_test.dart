import 'package:flutter_test/flutter_test.dart';
import 'package:aniya/core/utils/version_comparator.dart';

void main() {
  group('VersionComparator', () {
    group('compare', () {
      test('returns 0 for equal versions', () {
        expect(VersionComparator.compare('1.0.0', '1.0.0'), equals(0));
        expect(VersionComparator.compare('2.1.3', '2.1.3'), equals(0));
      });

      test('returns -1 when first version is less', () {
        expect(VersionComparator.compare('1.0.0', '2.0.0'), equals(-1));
        expect(VersionComparator.compare('1.0.0', '1.1.0'), equals(-1));
        expect(VersionComparator.compare('1.0.0', '1.0.1'), equals(-1));
      });

      test('returns 1 when first version is greater', () {
        expect(VersionComparator.compare('2.0.0', '1.0.0'), equals(1));
        expect(VersionComparator.compare('1.1.0', '1.0.0'), equals(1));
        expect(VersionComparator.compare('1.0.1', '1.0.0'), equals(1));
      });

      test('handles versions with different number of parts', () {
        expect(VersionComparator.compare('1.0', '1.0.0'), equals(0));
        expect(VersionComparator.compare('1', '1.0.0'), equals(0));
        expect(VersionComparator.compare('1.0.1', '1.0'), equals(1));
      });

      test('handles v prefix', () {
        expect(VersionComparator.compare('v1.0.0', '1.0.0'), equals(0));
        expect(VersionComparator.compare('V2.0.0', 'v1.0.0'), equals(1));
      });
    });

    group('isGreaterThan', () {
      test('returns true when first version is greater', () {
        expect(VersionComparator.isGreaterThan('2.0.0', '1.0.0'), isTrue);
      });

      test('returns false when first version is not greater', () {
        expect(VersionComparator.isGreaterThan('1.0.0', '2.0.0'), isFalse);
        expect(VersionComparator.isGreaterThan('1.0.0', '1.0.0'), isFalse);
      });
    });

    group('hasUpdateAvailable', () {
      test('returns true when available version is greater', () {
        expect(VersionComparator.hasUpdateAvailable('1.0.0', '2.0.0'), isTrue);
      });

      test('returns false when available version is not greater', () {
        expect(VersionComparator.hasUpdateAvailable('2.0.0', '1.0.0'), isFalse);
        expect(VersionComparator.hasUpdateAvailable('1.0.0', '1.0.0'), isFalse);
      });

      test('returns false when available version is null or empty', () {
        expect(VersionComparator.hasUpdateAvailable('1.0.0', null), isFalse);
        expect(VersionComparator.hasUpdateAvailable('1.0.0', ''), isFalse);
      });
    });
  });
}
