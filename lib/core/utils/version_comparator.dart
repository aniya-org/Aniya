/// Utility class for comparing semantic versions.
///
/// Supports semantic versioning format: major.minor.patch
/// Examples: "1.0.0", "2.1.3", "10.20.30"
class VersionComparator {
  /// Compares two semantic version strings.
  ///
  /// Returns:
  /// - `-1` if [version1] is less than [version2]
  /// - `0` if [version1] equals [version2]
  /// - `1` if [version1] is greater than [version2]
  ///
  /// Handles versions with different number of parts (e.g., "1.0" vs "1.0.0").
  /// Non-numeric parts are treated as 0.
  static int compare(String version1, String version2) {
    final parts1 = _parseVersion(version1);
    final parts2 = _parseVersion(version2);

    // Compare each part
    final maxLength = parts1.length > parts2.length
        ? parts1.length
        : parts2.length;

    for (int i = 0; i < maxLength; i++) {
      final v1 = i < parts1.length ? parts1[i] : 0;
      final v2 = i < parts2.length ? parts2[i] : 0;

      if (v1 < v2) return -1;
      if (v1 > v2) return 1;
    }

    return 0;
  }

  /// Checks if [version1] is greater than [version2].
  static bool isGreaterThan(String version1, String version2) {
    return compare(version1, version2) > 0;
  }

  /// Checks if [version1] is less than [version2].
  static bool isLessThan(String version1, String version2) {
    return compare(version1, version2) < 0;
  }

  /// Checks if [version1] equals [version2].
  static bool isEqual(String version1, String version2) {
    return compare(version1, version2) == 0;
  }

  /// Checks if an update is available by comparing installed and available versions.
  ///
  /// Returns `true` if [availableVersion] is greater than [installedVersion].
  static bool hasUpdateAvailable(
    String installedVersion,
    String? availableVersion,
  ) {
    if (availableVersion == null || availableVersion.isEmpty) {
      return false;
    }
    return isGreaterThan(availableVersion, installedVersion);
  }

  /// Parses a version string into a list of integer parts.
  ///
  /// Handles various formats:
  /// - "1.0.0" -> [1, 0, 0]
  /// - "v1.2.3" -> [1, 2, 3] (strips 'v' prefix)
  /// - "1.0" -> [1, 0]
  /// - "1" -> [1]
  static List<int> _parseVersion(String version) {
    // Remove common prefixes like 'v' or 'V'
    var cleanVersion = version.trim();
    if (cleanVersion.toLowerCase().startsWith('v')) {
      cleanVersion = cleanVersion.substring(1);
    }

    // Split by dots and parse each part
    return cleanVersion.split('.').map((part) {
      // Extract only numeric characters from the beginning
      final numericMatch = RegExp(r'^\d+').firstMatch(part.trim());
      if (numericMatch != null) {
        return int.tryParse(numericMatch.group(0)!) ?? 0;
      }
      return 0;
    }).toList();
  }
}
