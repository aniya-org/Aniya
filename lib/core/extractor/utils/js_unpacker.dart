library js_unpacker;

import 'package:aniya/core/utils/logger.dart';

/// Attempts to safely extract and parse packed JavaScript code.
/// This is a basic implementation that handles common packing patterns.
/// Ported from ref/umbrella/src/core/utils/jsUnpacker.ts
String safeUnpack(String packedCode) {
  try {
    // Remove common script wrappers
    var cleaned = packedCode
        .replaceAll(RegExp(r'<script[^>]*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'</script>', caseSensitive: false), '');

    // Handle p,a,c,k,e,d function calls (common packing format)
    final packedMatch = RegExp(
      r"eval\(function\(p,a,c,k,e,d\)\{.*?\}\('([^']+)',(\d+),(\d+),'([^']+)'\.split\('\|'\)",
    ).firstMatch(cleaned);

    if (packedMatch != null) {
      final payload = packedMatch.group(1) ?? '';
      final dictionary = packedMatch.group(4) ?? '';
      final dict = dictionary.split('|');

      // Simple substitution unpacking
      var result = payload;
      for (int index = 0; index < dict.length; index++) {
        final word = dict[index];
        if (word.isNotEmpty) {
          final regex = RegExp(r'\b' + index.toRadixString(36) + r'\b');
          result = result.replaceAll(regex, word);
        }
      }

      return result;
    }

    // If no packed pattern found, return cleaned code
    return cleaned;
  } catch (error) {
    Logger.warning('Failed to safely unpack JavaScript: $error');
    return packedCode; // Return original if unpacking fails
  }
}

/// Safely extracts variable values from JavaScript code without eval()
String? extractVariableValue(String code, String variableName) {
  try {
    final regex = RegExp(
      '$variableName\\s*=\\s*["\']([^"\']+)["\']',
      caseSensitive: false,
    );
    final match = regex.firstMatch(code);
    return match?.group(1);
  } catch (error) {
    Logger.warning('Failed to extract variable $variableName: $error');
    return null;
  }
}

/// Safely extracts function call results from JavaScript code
String? extractFunctionResult(String code, RegExp functionPattern) {
  try {
    final match = functionPattern.firstMatch(code);
    return match?.group(1);
  } catch (error) {
    Logger.warning('Failed to extract function result: $error');
    return null;
  }
}
