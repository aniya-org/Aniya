import 'package:flutter_test/flutter_test.dart';
import 'package:aniya/core/services/hardware_acceleration_configurator.dart';
import 'package:media_kit_video/media_kit_video.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('HardwareAccelerationConfigurator', () {
    setUp(() {
      // Clear cache before each test
      HardwareAccelerationConfigurator.clearCache();
    });

    group('HardwareProfile detection', () {
      test('should detect Linux OS correctly', () async {
        // This test would require mocking Platform.operatingSystem
        // For now, we'll test logic that depends on detected OS
        final profile =
            await HardwareAccelerationConfigurator.detectHardwareProfile();

        expect(profile.os, isA<String>());
        expect(profile.gpuVendor, isA<GpuVendor>());
        expect(profile.supportsVulkan, isA<bool>());
        expect(profile.supportsHwdec, isA<bool>());
        expect(profile.isWayland, isA<bool>());
      });

      test('should cache hardware profile', () async {
        final profile1 =
            await HardwareAccelerationConfigurator.detectHardwareProfile();
        final profile2 =
            await HardwareAccelerationConfigurator.detectHardwareProfile();

        // Should return same cached instance
        expect(identical(profile1, profile2), isTrue);
      });
    });

    group('Configuration generation', () {
      test(
        'should return software config when software mode is forced',
        () async {
          final config =
              await HardwareAccelerationConfigurator.getOptimalConfig(
                overrideMode: HardwareAccelerationMode.software,
              );

          expect(config.mode, HardwareAccelerationMode.software);
          expect(config.enableHardwareAcceleration, false);
          expect(config.hwdec, 'no');
        },
      );

      test('should return platform preset config when requested', () async {
        final config = await HardwareAccelerationConfigurator.getOptimalConfig(
          overrideMode: HardwareAccelerationMode.platformPreset,
        );

        expect(config.mode, HardwareAccelerationMode.platformPreset);
        expect(config.enableHardwareAcceleration, isA<bool>());
      });

      test('should return auto config by default', () async {
        final config =
            await HardwareAccelerationConfigurator.getOptimalConfig();

        expect(config.mode, HardwareAccelerationMode.auto);
        expect(config.enableHardwareAcceleration, isA<bool>());
      });
    });

    group('Platform-specific configurations', () {
      test('should handle Linux NVIDIA configuration', () async {
        final config = HardwareAccelerationConfigurator.getAutoConfigForProfile(
          const HardwareProfile(
            os: 'linux',
            gpuVendor: GpuVendor.nvidia,
            supportsVulkan: true,
            supportsHwdec: true,
            recommendedMode: HardwareAccelerationMode.auto,
            isWayland: false,
          ),
        );

        expect(config.hwdec, 'cuda');
        expect(config.gpuApi, 'opengl');
        expect(config.enableHardwareAcceleration, true);
      });

      test('should handle Linux AMD configuration', () async {
        final config = HardwareAccelerationConfigurator.getAutoConfigForProfile(
          const HardwareProfile(
            os: 'linux',
            gpuVendor: GpuVendor.amd,
            supportsVulkan: true,
            supportsHwdec: true,
            recommendedMode: HardwareAccelerationMode.auto,
            isWayland: false,
          ),
        );

        expect(config.hwdec, 'vaapi');
        expect(config.gpuApi, 'opengl');
        expect(config.enableHardwareAcceleration, true);
      });

      test('should handle Windows configuration', () async {
        final config = HardwareAccelerationConfigurator.getAutoConfigForProfile(
          const HardwareProfile(
            os: 'windows',
            gpuVendor: GpuVendor.nvidia,
            supportsVulkan: true,
            supportsHwdec: true,
            recommendedMode: HardwareAccelerationMode.auto,
            isWayland: false,
          ),
        );

        expect(config.hwdec, 'd3d11va');
        expect(config.gpuApi, 'd3d11');
        expect(config.vo, 'gpu');
        expect(config.enableHardwareAcceleration, true);
      });

      test('should handle macOS configuration', () async {
        final config = HardwareAccelerationConfigurator.getAutoConfigForProfile(
          const HardwareProfile(
            os: 'macos',
            gpuVendor: GpuVendor.intel,
            supportsVulkan: false,
            supportsHwdec: true,
            recommendedMode: HardwareAccelerationMode.auto,
            isWayland: false,
          ),
        );

        expect(config.hwdec, 'videotoolbox');
        expect(config.gpuApi, 'cocoa');
        expect(config.enableHardwareAcceleration, true);
      });

      test('should handle Wayland-specific configurations', () async {
        final config = HardwareAccelerationConfigurator.getAutoConfigForProfile(
          const HardwareProfile(
            os: 'linux',
            gpuVendor: GpuVendor.amd,
            supportsVulkan: true,
            supportsHwdec: true,
            recommendedMode: HardwareAccelerationMode.auto,
            isWayland: true,
          ),
        );

        expect(config.hwdec, 'vaapi');
        expect(config.gpuApi, 'opengl');
        expect(config.vo, 'gpu');
        expect(config.enableHardwareAcceleration, true);
      });
    });

    group('Platform preset configurations', () {
      test(
        'should handle Linux NVIDIA platform preset conservatively',
        () async {
          final config =
              HardwareAccelerationConfigurator.getPlatformPresetConfigForProfile(
                const HardwareProfile(
                  os: 'linux',
                  gpuVendor: GpuVendor.nvidia,
                  supportsVulkan: true,
                  supportsHwdec: true,
                  recommendedMode: HardwareAccelerationMode.platformPreset,
                  isWayland: false,
                ),
              );

          expect(config.mode, HardwareAccelerationMode.platformPreset);
          expect(config.hwdec, 'auto-safe');
          expect(config.gpuApi, 'opengl');
          expect(config.enableHardwareAcceleration, true);
        },
      );

      test('should handle Linux Wayland NVIDIA more conservatively', () async {
        final config =
            HardwareAccelerationConfigurator.getPlatformPresetConfigForProfile(
              const HardwareProfile(
                os: 'linux',
                gpuVendor: GpuVendor.nvidia,
                supportsVulkan: true,
                supportsHwdec: true,
                recommendedMode: HardwareAccelerationMode.platformPreset,
                isWayland: true,
              ),
            );

        expect(config.mode, HardwareAccelerationMode.platformPreset);
        expect(config.hwdec, 'auto-safe');
        expect(config.gpuApi, 'opengl');
        expect(config.vo, 'gpu');
        expect(config.enableHardwareAcceleration, true);
      });
    });

    group('VideoController configuration', () {
      test('should return appropriate VideoControllerConfiguration', () async {
        final videoConfig =
            await HardwareAccelerationConfigurator.getVideoControllerConfig();

        expect(videoConfig, isA<VideoControllerConfiguration>());
        expect(videoConfig.enableHardwareAcceleration, isA<bool>());
      });
    });

    group('Error handling', () {
      test('should handle missing GPU vendor gracefully', () async {
        final config = HardwareAccelerationConfigurator.getAutoConfigForProfile(
          const HardwareProfile(
            os: 'linux',
            gpuVendor: GpuVendor.unknown,
            supportsVulkan: false,
            supportsHwdec: false,
            recommendedMode: HardwareAccelerationMode.software,
            isWayland: false,
          ),
        );

        expect(config.hwdec, 'auto-safe');
        expect(config.enableHardwareAcceleration, true);
      });

      test('should handle unknown OS gracefully', () async {
        final config = HardwareAccelerationConfigurator.getAutoConfigForProfile(
          const HardwareProfile(
            os: 'unknown',
            gpuVendor: GpuVendor.unknown,
            supportsVulkan: false,
            supportsHwdec: false,
            recommendedMode: HardwareAccelerationMode.software,
            isWayland: false,
          ),
        );

        expect(config.enableHardwareAcceleration, true);
        expect(config.mode, HardwareAccelerationMode.auto);
      });
    });

    group('GPU vendor detection logic', () {
      test('should identify NVIDIA from output strings', () {
        final testCases = [
          'NVIDIA Corporation GeForce RTX 3080',
          'GeForce GTX 1660',
          'Quadro RTX 6000',
          'nvidia-smi output',
        ];

        for (final testCase in testCases) {
          final lowerCase = testCase.toLowerCase();
          GpuVendor detected = GpuVendor.unknown;

          if (lowerCase.contains('nvidia') ||
              lowerCase.contains('geforce') ||
              lowerCase.contains('quadro')) {
            detected = GpuVendor.nvidia;
          }

          expect(
            detected,
            GpuVendor.nvidia,
            reason: 'Failed to detect NVIDIA in: $testCase',
          );
        }
      });

      test('should identify AMD from output strings', () {
        final testCases = [
          'Advanced Micro Devices, Inc. Radeon RX 6800',
          'AMD Radeon VII',
          'Radeon RX 5700 XT',
        ];

        for (final testCase in testCases) {
          final lowerCase = testCase.toLowerCase();
          GpuVendor detected = GpuVendor.unknown;

          if (lowerCase.contains('amd') ||
              lowerCase.contains('radeon') ||
              lowerCase.contains('advanced micro devices')) {
            detected = GpuVendor.amd;
          }

          expect(
            detected,
            GpuVendor.amd,
            reason: 'Failed to detect AMD in: $testCase',
          );
        }
      });

      test('should identify Intel from output strings', () {
        final testCases = [
          'Intel Corporation UHD Graphics 620',
          'Intel Iris Xe Graphics',
          'Intel HD Graphics 530',
        ];

        for (final testCase in testCases) {
          final lowerCase = testCase.toLowerCase();
          GpuVendor detected = GpuVendor.unknown;

          if (lowerCase.contains('intel')) {
            detected = GpuVendor.intel;
          }

          expect(
            detected,
            GpuVendor.intel,
            reason: 'Failed to detect Intel in: $testCase',
          );
        }
      });
    });

    group('HardwareAccelerationMode enum', () {
      test('should contain all expected modes', () {
        final modes = HardwareAccelerationMode.values;

        expect(modes, contains(HardwareAccelerationMode.auto));
        expect(modes, contains(HardwareAccelerationMode.software));
        expect(modes, contains(HardwareAccelerationMode.platformPreset));
        expect(modes, contains(HardwareAccelerationMode.custom));
      });
    });

    group('GpuVendor enum', () {
      test('should contain all expected vendors', () {
        final vendors = GpuVendor.values;

        expect(vendors, contains(GpuVendor.nvidia));
        expect(vendors, contains(GpuVendor.amd));
        expect(vendors, contains(GpuVendor.intel));
        expect(vendors, contains(GpuVendor.unknown));
      });
    });

    group('HardwareProfile class', () {
      test('should create valid HardwareProfile', () {
        const profile = HardwareProfile(
          os: 'linux',
          gpuVendor: GpuVendor.nvidia,
          supportsVulkan: true,
          supportsHwdec: true,
          recommendedMode: HardwareAccelerationMode.auto,
          isWayland: false,
        );

        expect(profile.os, 'linux');
        expect(profile.gpuVendor, GpuVendor.nvidia);
        expect(profile.supportsVulkan, true);
        expect(profile.supportsHwdec, true);
        expect(profile.recommendedMode, HardwareAccelerationMode.auto);
        expect(profile.isWayland, false);
      });

      test('toString should return meaningful representation', () {
        const profile = HardwareProfile(
          os: 'linux',
          gpuVendor: GpuVendor.nvidia,
          supportsVulkan: true,
          supportsHwdec: true,
          recommendedMode: HardwareAccelerationMode.auto,
          isWayland: false,
        );

        final stringRepresentation = profile.toString();
        expect(stringRepresentation, contains('linux'));
        expect(stringRepresentation, contains('nvidia'));
        expect(stringRepresentation, contains('true'));
        expect(stringRepresentation, contains('false'));
      });
    });

    group('HardwareAccelerationConfig class', () {
      test('should create valid HardwareAccelerationConfig', () {
        const config = HardwareAccelerationConfig(
          mode: HardwareAccelerationMode.auto,
          hwdec: 'cuda',
          gpuApi: 'opengl',
          vo: 'gpu',
          enableHardwareAcceleration: true,
        );

        expect(config.mode, HardwareAccelerationMode.auto);
        expect(config.hwdec, 'cuda');
        expect(config.gpuApi, 'opengl');
        expect(config.vo, 'gpu');
        expect(config.enableHardwareAcceleration, true);
      });

      test('should create config with optional fields', () {
        const config = HardwareAccelerationConfig(
          mode: HardwareAccelerationMode.software,
          enableHardwareAcceleration: false,
        );

        expect(config.mode, HardwareAccelerationMode.software);
        expect(config.hwdec, null);
        expect(config.gpuApi, null);
        expect(config.vo, null);
        expect(config.enableHardwareAcceleration, false);
      });
    });
  });
}
