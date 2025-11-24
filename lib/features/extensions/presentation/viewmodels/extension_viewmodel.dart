import 'package:flutter/foundation.dart';
import '../../../../core/domain/entities/extension_entity.dart';
import '../../../../core/domain/usecases/get_available_extensions_usecase.dart';
import '../../../../core/domain/usecases/get_installed_extensions_usecase.dart';
import '../../../../core/domain/usecases/install_extension_usecase.dart';
import '../../../../core/domain/usecases/uninstall_extension_usecase.dart';
import '../../../../core/utils/error_message_mapper.dart';
import '../../../../core/utils/logger.dart';

class ExtensionViewModel extends ChangeNotifier {
  final GetAvailableExtensionsUseCase getAvailableExtensions;
  final GetInstalledExtensionsUseCase getInstalledExtensions;
  final InstallExtensionUseCase installExtension;
  final UninstallExtensionUseCase uninstallExtension;

  ExtensionViewModel({
    required this.getAvailableExtensions,
    required this.getInstalledExtensions,
    required this.installExtension,
    required this.uninstallExtension,
  });

  List<ExtensionEntity> _availableExtensions = [];
  List<ExtensionEntity> _installedExtensions = [];
  bool _isLoading = false;
  String? _error;
  String? _installationProgress;

  List<ExtensionEntity> get availableExtensions => _availableExtensions;
  List<ExtensionEntity> get installedExtensions => _installedExtensions;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get installationProgress => _installationProgress;

  Future<void> loadExtensions() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Load all extension types
      final extensionTypes = ExtensionType.values;

      List<ExtensionEntity> allAvailable = [];
      List<ExtensionEntity> allInstalled = [];

      for (final type in extensionTypes) {
        try {
          // Load available extensions for this type
          final availableResult = await getAvailableExtensions(type);
          availableResult.fold((failure) {
            // Log error but continue loading other extensions (error isolation)
            Logger.error(
              'Failed to load available extensions for type: $type',
              tag: 'ExtensionViewModel',
              error: failure,
            );
          }, (extensions) => allAvailable.addAll(extensions));

          // Load installed extensions for this type
          final installedResult = await getInstalledExtensions(type);
          installedResult.fold((failure) {
            // Log error but continue loading other extensions (error isolation)
            Logger.error(
              'Failed to load installed extensions for type: $type',
              tag: 'ExtensionViewModel',
              error: failure,
            );
          }, (extensions) => allInstalled.addAll(extensions));
        } catch (e, stackTrace) {
          // Log error but continue with other extension types (error isolation)
          Logger.error(
            'Error loading extensions for type: $type',
            tag: 'ExtensionViewModel',
            error: e,
            stackTrace: stackTrace,
          );
        }
      }

      _availableExtensions = allAvailable;
      _installedExtensions = allInstalled;
    } catch (e, stackTrace) {
      _error = 'An unexpected error occurred. Please try again.';
      Logger.error(
        'Unexpected error in loadExtensions',
        tag: 'ExtensionViewModel',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> install(String extensionId, ExtensionType type) async {
    _installationProgress = 'Installing extension...';
    _error = null;
    notifyListeners();

    try {
      final result = await installExtension(extensionId, type);

      result.fold(
        (failure) {
          _error = ErrorMessageMapper.mapFailureToMessage(failure);
          _installationProgress = null;
          Logger.error(
            'Failed to install extension: $extensionId',
            tag: 'ExtensionViewModel',
            error: failure,
          );
        },
        (_) {
          _installationProgress = 'Installation complete';
          // Reload extensions to update the lists
          loadExtensions();
        },
      );
    } catch (e, stackTrace) {
      _error = 'An unexpected error occurred. Please try again.';
      _installationProgress = null;
      Logger.error(
        'Unexpected error installing extension: $extensionId',
        tag: 'ExtensionViewModel',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      notifyListeners();
      // Clear installation progress after a delay
      Future.delayed(const Duration(seconds: 2), () {
        _installationProgress = null;
        notifyListeners();
      });
    }
  }

  Future<void> uninstall(String extensionId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await uninstallExtension(extensionId);

      result.fold(
        (failure) {
          _error = ErrorMessageMapper.mapFailureToMessage(failure);
          Logger.error(
            'Failed to uninstall extension: $extensionId',
            tag: 'ExtensionViewModel',
            error: failure,
          );
        },
        (_) {
          // Reload extensions to update the lists
          loadExtensions();
        },
      );
    } catch (e, stackTrace) {
      _error = 'An unexpected error occurred. Please try again.';
      Logger.error(
        'Unexpected error uninstalling extension: $extensionId',
        tag: 'ExtensionViewModel',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
