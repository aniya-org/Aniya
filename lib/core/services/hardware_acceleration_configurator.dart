import 'dart:io';
import 'dart:async';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hardware acceleration profile for different platforms and GPU configurations
enum HardwareAccelerationMode { auto, software, platformPreset, custom }

/// GPU vendor information for hardware acceleration decisions
enum GpuVendor { nvidia, amd, intel, unknown }

/// Hardware profile containing platform and GPU information
class HardwareProfile {
  final String os;
  final String? architecture;
  final GpuVendor gpuVendor;
  final bool supportsVulkan;
  final bool supportsHwdec;
  final HardwareAccelerationMode recommendedMode;
  final bool isWayland;

  const HardwareProfile({
    required this.os,
    this.architecture,
    required this.gpuVendor,
    required this.supportsVulkan,
    required this.supportsHwdec,
    required this.recommendedMode,
    required this.isWayland,
  });

  @override
  String toString() =>
      'HardwareProfile(os: $os, gpu: $gpuVendor, hwdec: $supportsHwdec, wayland: $isWayland)';
}

/// Configuration for hardware acceleration settings
class HardwareAccelerationConfig {
  final HardwareAccelerationMode mode;
  final String? hwdec;
  final String? gpuApi;
  final String? vo;
  final bool enableHardwareAcceleration;

  const HardwareAccelerationConfig({
    required this.mode,
    this.hwdec,
    this.gpuApi,
    this.vo,
    required this.enableHardwareAcceleration,
  });
}

/// Service for detecting hardware capabilities and configuring optimal acceleration settings
class HardwareAccelerationConfigurator {
  static HardwareProfile? _cachedProfile;
  static const Duration _detectionTimeout = Duration(seconds: 3);

  /// Detect hardware profile for current platform
  static Future<HardwareProfile> detectHardwareProfile() async {
    if (_cachedProfile != null) {
      return _cachedProfile!;
    }

    final os = _detectOS();
    final architecture = _detectArchitecture();
    final gpuVendor = await _detectGpuVendor();
    final supportsVulkan = await _checkVulkanSupport();
    final supportsHwdec = _assessHwdecSupport(os, gpuVendor);
    final recommendedMode = _getRecommendedMode(os, gpuVendor, supportsHwdec);

    final isWayland = await _detectWayland();

    _cachedProfile = HardwareProfile(
      os: os,
      architecture: architecture,
      gpuVendor: gpuVendor,
      supportsVulkan: supportsVulkan,
      supportsHwdec: supportsHwdec,
      recommendedMode: recommendedMode,
      isWayland: isWayland,
    );

    return _cachedProfile!;
  }

  /// Get optimal hardware acceleration configuration for detected profile
  static Future<HardwareAccelerationConfig> getOptimalConfig({
    HardwareAccelerationMode? overrideMode,
  }) async {
    final profile = await detectHardwareProfile();

    // Check for user preference in settings
    final userMode = await _getUserPreference();
    final mode = overrideMode ?? userMode ?? profile.recommendedMode;

    switch (mode) {
      case HardwareAccelerationMode.software:
        return const HardwareAccelerationConfig(
          mode: HardwareAccelerationMode.software,
          enableHardwareAcceleration: false,
        );

      case HardwareAccelerationMode.platformPreset:
        return _getPlatformPresetConfig(profile);

      case HardwareAccelerationMode.auto:
      default:
        return _getAutoConfig(profile);
    }
  }

  /// Configure player with optimal hardware acceleration settings
  static Future<void> configurePlayer(
    Player player, {
    HardwareAccelerationMode? overrideMode,
    bool enableDebugLogging = false,
  }) async {
    final config = await getOptimalConfig(overrideMode: overrideMode);

    try {
      // Apply player configuration through platform interface
      final platform = player.platform as dynamic;

      if (config.hwdec != null) {
        await platform.setProperty('hwdec', config.hwdec!);
      }
      if (config.gpuApi != null) {
        await platform.setProperty('gpu-api', config.gpuApi!);
      }
      if (config.vo != null) {
        await platform.setProperty('vo', config.vo!);
      }

      // Log configuration if debug logging is enabled
      if (enableDebugLogging) {
        await _logConfiguration(player, config);
      }
    } catch (e) {
      // Fallback to software decoding if hardware configuration fails
      Logger.warning(
        'Hardware acceleration configuration failed: $e',
        tag: 'HardwareConfig',
      );
      Logger.info(
        'Falling back to software decoding...',
        tag: 'HardwareConfig',
      );

      try {
        final platform = player.platform as dynamic;
        await platform.setProperty('hwdec', 'no');
      } catch (fallbackError) {
        Logger.error(
          'Even software decoding configuration failed: $fallbackError',
          tag: 'HardwareConfig',
        );
      }
    }
  }

  /// Get VideoController configuration based on hardware profile
  static Future<VideoControllerConfiguration> getVideoControllerConfig({
    HardwareAccelerationMode? overrideMode,
  }) async {
    final config = await getOptimalConfig(overrideMode: overrideMode);
    return VideoControllerConfiguration(
      enableHardwareAcceleration: config.enableHardwareAcceleration,
    );
  }

  // Private helper methods

  static String _detectOS() {
    if (Platform.isLinux) return 'linux';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }

  static String? _detectArchitecture() {
    try {
      return Platform.operatingSystemVersion;
    } catch (e) {
      return null;
    }
  }

  static Future<GpuVendor> _detectGpuVendor() async {
    if (!Platform.isLinux && !Platform.isWindows) {
      return GpuVendor.unknown;
    }

    try {
      String? output;

      if (Platform.isLinux) {
        // Try multiple GPU detection methods on Linux
        output = await _runCommandWithTimeout('lspci | grep -i vga');
        if (output == null || output.isEmpty) {
          output = await _runCommandWithTimeout('glxinfo | grep -i vendor');
        }
        if (output == null || output.isEmpty) {
          output = await _runCommandWithTimeout('nvidia-smi -L');
        }
      } else if (Platform.isWindows) {
        output = await _runCommandWithTimeout(
          'wmic path win32_VideoController get name',
        );
      }

      if (output != null && output.isNotEmpty) {
        final lowerOutput = output.toLowerCase();
        if (lowerOutput.contains('nvidia') ||
            lowerOutput.contains('geforce') ||
            lowerOutput.contains('quadro')) {
          return GpuVendor.nvidia;
        } else if (lowerOutput.contains('amd') ||
            lowerOutput.contains('radeon') ||
            lowerOutput.contains('advanced micro devices')) {
          return GpuVendor.amd;
        } else if (lowerOutput.contains('intel')) {
          return GpuVendor.intel;
        }
      }
    } catch (e) {
      Logger.debug('GPU detection failed: $e', tag: 'HardwareConfig');
    }

    return GpuVendor.unknown;
  }

  static Future<bool> _checkVulkanSupport() async {
    if (Platform.isAndroid || Platform.isIOS) {
      return true; // Mobile platforms typically support Vulkan
    }

    try {
      final result = await _runCommandWithTimeout('vulkaninfo --summary');
      return result != null &&
          result.isNotEmpty &&
          !result.toLowerCase().contains('error');
    } catch (e) {
      return false;
    }
  }

  static bool _assessHwdecSupport(String os, GpuVendor gpuVendor) {
    // Basic assessment of hardware decoding support
    switch (os) {
      case 'linux':
        // Linux has variable hwdec support depending on drivers
        return gpuVendor != GpuVendor.unknown;
      case 'windows':
        return true; // Windows generally has good hwdec support
      case 'macos':
        return true; // macOS has good hwdec support via VideoToolbox
      case 'android':
        return true; // Android has mediacodec support
      case 'ios':
        return true; // iOS has VideoToolbox support
      default:
        return false;
    }
  }

  static HardwareAccelerationMode _getRecommendedMode(
    String os,
    GpuVendor gpuVendor,
    bool supportsHwdec,
  ) {
    if (!supportsHwdec) {
      return HardwareAccelerationMode.software;
    }

    // Linux with NVIDIA has known issues, recommend platform preset with safeguards
    if (os == 'linux' && gpuVendor == GpuVendor.nvidia) {
      return HardwareAccelerationMode.platformPreset;
    }

    return HardwareAccelerationMode.auto;
  }

  static HardwareAccelerationConfig _getAutoConfig(HardwareProfile profile) {
    switch (profile.os) {
      case 'linux':
        // Wayland-specific configurations
        if (profile.isWayland) {
          if (profile.gpuVendor == GpuVendor.nvidia) {
            return const HardwareAccelerationConfig(
              mode: HardwareAccelerationMode.auto,
              hwdec: 'cuda',
              gpuApi: 'opengl',
              vo: 'gpu',
              enableHardwareAcceleration: true,
            );
          } else if (profile.gpuVendor == GpuVendor.amd) {
            return const HardwareAccelerationConfig(
              mode: HardwareAccelerationMode.auto,
              hwdec: 'vaapi',
              gpuApi: 'opengl',
              vo: 'gpu',
              enableHardwareAcceleration: true,
            );
          }
        }

        // X11 or fallback configurations
        if (profile.gpuVendor == GpuVendor.nvidia) {
          return const HardwareAccelerationConfig(
            mode: HardwareAccelerationMode.auto,
            hwdec: 'cuda',
            gpuApi: 'opengl',
            enableHardwareAcceleration: true,
          );
        } else if (profile.gpuVendor == GpuVendor.amd) {
          return const HardwareAccelerationConfig(
            mode: HardwareAccelerationMode.auto,
            hwdec: 'vaapi',
            gpuApi: 'opengl',
            enableHardwareAcceleration: true,
          );
        } else if (profile.gpuVendor == GpuVendor.intel) {
          return const HardwareAccelerationConfig(
            mode: HardwareAccelerationMode.auto,
            hwdec: 'vaapi',
            gpuApi: 'opengl',
            enableHardwareAcceleration: true,
          );
        }

        // Safe fallback for Linux
        return const HardwareAccelerationConfig(
          mode: HardwareAccelerationMode.auto,
          hwdec: 'auto-safe',
          gpuApi: 'opengl',
          enableHardwareAcceleration: true,
        );

      case 'windows':
        return HardwareAccelerationConfig(
          mode: HardwareAccelerationMode.auto,
          hwdec: profile.gpuVendor == GpuVendor.nvidia ? 'd3d11va' : 'auto',
          gpuApi: 'd3d11',
          vo: 'gpu',
          enableHardwareAcceleration: true,
        );

      case 'macos':
        return const HardwareAccelerationConfig(
          mode: HardwareAccelerationMode.auto,
          hwdec: 'videotoolbox',
          gpuApi: 'cocoa',
          enableHardwareAcceleration: true,
        );

      case 'android':
        return const HardwareAccelerationConfig(
          mode: HardwareAccelerationMode.auto,
          hwdec: 'mediacodec',
          enableHardwareAcceleration: true,
        );

      case 'ios':
        return const HardwareAccelerationConfig(
          mode: HardwareAccelerationMode.auto,
          hwdec: 'videotoolbox',
          enableHardwareAcceleration: true,
        );

      default:
        return const HardwareAccelerationConfig(
          mode: HardwareAccelerationMode.auto,
          enableHardwareAcceleration: true,
        );
    }
  }

  static HardwareAccelerationConfig _getPlatformPresetConfig(
    HardwareProfile profile,
  ) {
    switch (profile.os) {
      case 'linux':
        if (profile.isWayland) {
          switch (profile.gpuVendor) {
            case GpuVendor.nvidia:
              return const HardwareAccelerationConfig(
                mode: HardwareAccelerationMode.platformPreset,
                hwdec: 'auto-safe',
                gpuApi: 'opengl',
                enableHardwareAcceleration:
                    false, // Force software on NVIDIA Linux for stability
              );
            case GpuVendor.amd:
              return const HardwareAccelerationConfig(
                mode: HardwareAccelerationMode
                    .software, // Force software for AMD Linux to prevent crashes
                hwdec: 'no',
                enableHardwareAcceleration: false,
              );
            case GpuVendor.intel:
              return const HardwareAccelerationConfig(
                mode: HardwareAccelerationMode.platformPreset,
                hwdec: 'vaapi',
                gpuApi: 'opengl',
                enableHardwareAcceleration: true,
              );
            default:
              return const HardwareAccelerationConfig(
                mode: HardwareAccelerationMode.platformPreset,
                hwdec: 'auto-safe',
                enableHardwareAcceleration:
                    false, // Conservative fallback for unknown
              );
          }
        } else {
          // X11 configurations
          switch (profile.gpuVendor) {
            case GpuVendor.nvidia:
              return const HardwareAccelerationConfig(
                mode: HardwareAccelerationMode.platformPreset,
                hwdec: 'auto-safe', // Still conservative for NVIDIA
                gpuApi: 'opengl',
                enableHardwareAcceleration: true,
              );
            case GpuVendor.amd:
              return const HardwareAccelerationConfig(
                mode: HardwareAccelerationMode.platformPreset,
                hwdec: 'vaapi',
                gpuApi: 'opengl',
                enableHardwareAcceleration: true,
              );
            case GpuVendor.intel:
              return const HardwareAccelerationConfig(
                mode: HardwareAccelerationMode.platformPreset,
                hwdec: 'vaapi',
                gpuApi: 'opengl',
                enableHardwareAcceleration: true,
              );
            default:
              return const HardwareAccelerationConfig(
                mode: HardwareAccelerationMode.platformPreset,
                hwdec: 'auto-safe',
                enableHardwareAcceleration: false,
              );
          }
        }

      case 'windows':
        return const HardwareAccelerationConfig(
          mode: HardwareAccelerationMode.platformPreset,
          hwdec: 'd3d11va',
          gpuApi: 'd3d11',
          vo: 'gpu',
          enableHardwareAcceleration: true,
        );

      case 'macos':
        return const HardwareAccelerationConfig(
          mode: HardwareAccelerationMode.platformPreset,
          hwdec: 'videotoolbox',
          gpuApi: 'cocoa',
          enableHardwareAcceleration: true,
        );

      case 'android':
        return const HardwareAccelerationConfig(
          mode: HardwareAccelerationMode.platformPreset,
          hwdec: 'mediacodec',
          enableHardwareAcceleration: true,
        );

      case 'ios':
        return const HardwareAccelerationConfig(
          mode: HardwareAccelerationMode.platformPreset,
          hwdec: 'videotoolbox',
          enableHardwareAcceleration: true,
        );

      default:
        return const HardwareAccelerationConfig(
          mode: HardwareAccelerationMode.platformPreset,
          enableHardwareAcceleration:
              false, // Conservative for unknown platforms
        );
    }
  }

  static Future<String?> _runCommandWithTimeout(String command) async {
    try {
      final result = await Process.run('bash', [
        '-c',
        command,
      ]).timeout(_detectionTimeout);

      if (result.exitCode == 0) {
        return result.stdout.trim();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<void> _logConfiguration(
    Player player,
    HardwareAccelerationConfig config,
  ) async {
    try {
      final platform = player.platform as dynamic;
      final hwdec = await platform.getProperty('hwdec-current');
      final gpuApi = await platform.getProperty('gpu-api');
      final vo = await platform.getProperty('vo');

      Logger.info(
        '=== Hardware Acceleration Configuration ===',
        tag: 'HardwareConfig',
      );
      Logger.info('Mode: ${config.mode}', tag: 'HardwareConfig');
      Logger.info('HW Decoding: ${config.hwdec}', tag: 'HardwareConfig');
      Logger.info('GPU API: ${config.gpuApi}', tag: 'HardwareConfig');
      Logger.info('Video Output: ${config.vo}', tag: 'HardwareConfig');
      Logger.info('Current HWDEC: $hwdec', tag: 'HardwareConfig');
      Logger.info('Current GPU API: $gpuApi', tag: 'HardwareConfig');
      Logger.info('Current VO: $vo', tag: 'HardwareConfig');
      Logger.info(
        '=====================================',
        tag: 'HardwareConfig',
      );
    } catch (e) {
      Logger.warning('Failed to log configuration: $e', tag: 'HardwareConfig');
    }
  }

  /// Detect Wayland display server on Linux
  static Future<bool> _detectWayland() async {
    if (!Platform.isLinux) return false;

    try {
      // Check environment variables
      final waylandDisplay = Platform.environment['WAYLAND_DISPLAY'];
      if (waylandDisplay != null && waylandDisplay.isNotEmpty) {
        return true;
      }

      final xdgSessionType = Platform.environment['XDG_SESSION_TYPE'];
      if (xdgSessionType?.toLowerCase() == 'wayland') {
        return true;
      }

      // Try to detect via loginctl
      final result = await _runCommandWithTimeout(
        'loginctl session-status | head -n 1',
      );
      if (result != null && result.toLowerCase().contains('wayland')) {
        return true;
      }
    } catch (e) {
      Logger.debug('Wayland detection failed: $e', tag: 'HardwareConfig');
    }

    return false;
  }

  /// Get user preference from shared preferences
  static Future<HardwareAccelerationMode?> _getUserPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeString = prefs.getString('hardware_acceleration_mode');
      if (modeString != null) {
        return HardwareAccelerationMode.values.firstWhere(
          (mode) => mode.toString() == modeString,
          orElse: () => HardwareAccelerationMode.auto,
        );
      }
    } catch (e) {
      Logger.debug('Failed to get user preference: $e', tag: 'HardwareConfig');
    }
    return null;
  }

  /// Save user preference to shared preferences
  static Future<void> saveUserPreference(HardwareAccelerationMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('hardware_acceleration_mode', mode.toString());
      Logger.info(
        'Saved hardware acceleration preference: $mode',
        tag: 'HardwareConfig',
      );
    } catch (e) {
      Logger.warning(
        'Failed to save user preference: $e',
        tag: 'HardwareConfig',
      );
    }
  }

  /// Clear cached hardware profile (useful for testing)
  static void clearCache() {
    _cachedProfile = null;
  }
}
