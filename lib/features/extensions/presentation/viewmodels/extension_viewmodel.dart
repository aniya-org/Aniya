import 'package:flutter/foundation.dart';
import '../../../../core/domain/entities/extension_entity.dart';
import '../../../../core/domain/usecases/get_available_extensions_usecase.dart';
import '../../../../core/domain/usecases/get_installed_extensions_usecase.dart';
import '../../../../core/domain/usecases/install_extension_usecase.dart';
import '../../../../core/domain/usecases/uninstall_extension_usecase.dart';
import '../../../../core/domain/repositories/repository_repository.dart';
import '../../../../core/data/models/repository_config_model.dart';
import '../../../../core/services/extension_discovery_service.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/utils/error_message_mapper.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/version_comparator.dart';

class ExtensionViewModel extends ChangeNotifier {
  final GetAvailableExtensionsUseCase getAvailableExtensions;
  final GetInstalledExtensionsUseCase getInstalledExtensions;
  final InstallExtensionUseCase installExtension;
  final UninstallExtensionUseCase uninstallExtension;
  final RepositoryRepository? repositoryRepository;
  final ExtensionDiscoveryService? extensionDiscoveryService;
  final PermissionService? permissionService;

  ExtensionViewModel({
    required this.getAvailableExtensions,
    required this.getInstalledExtensions,
    required this.installExtension,
    required this.uninstallExtension,
    this.repositoryRepository,
    this.extensionDiscoveryService,
    this.permissionService,
  });

  // Core extension lists
  List<ExtensionEntity> _availableExtensions = [];
  List<ExtensionEntity> _installedExtensions = [];

  // Loading and error state
  bool _isLoading = false;
  String? _error;
  String? _installationProgress;

  // Track which extension is currently being installed/uninstalled
  String? _installingExtensionId;
  String? _uninstallingExtensionId;

  // Filtering and search state (Task 5.1)
  String _selectedLanguage = 'All';
  String _searchQuery = '';
  ExtensionType _currentExtensionType = ExtensionType.mangayomi;

  // Repository configurations (Task 5.1)
  final Map<ExtensionType, RepositoryConfig> _repositoryConfigs = {};

  // Basic getters
  List<ExtensionEntity> get availableExtensions => _availableExtensions;
  List<ExtensionEntity> get installedExtensions => _installedExtensions;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get installationProgress => _installationProgress;
  String? get installingExtensionId => _installingExtensionId;
  String? get uninstallingExtensionId => _uninstallingExtensionId;

  // Filtering and search getters (Task 5.1)
  String get selectedLanguage => _selectedLanguage;
  String get searchQuery => _searchQuery;
  ExtensionType get currentExtensionType => _currentExtensionType;
  Map<ExtensionType, RepositoryConfig> get repositoryConfigs =>
      _repositoryConfigs;

  // Grouped extensions by ItemType (Task 5.1, 5.2)
  Map<ItemType, List<ExtensionEntity>> get groupedInstalledExtensions {
    return _groupExtensionsByItemType(_installedExtensions);
  }

  Map<ItemType, List<ExtensionEntity>> get groupedAvailableExtensions {
    return _groupExtensionsByItemType(_availableExtensions);
  }

  // Update pending extensions (Task 5.1)
  List<ExtensionEntity> get updatePendingExtensions {
    return _installedExtensions.where((ext) => ext.hasUpdate).toList();
  }

  // Filtered extensions (Task 5.4, 5.6, 5.8)
  List<ExtensionEntity> get filteredInstalledExtensions {
    return _applyFilters(_installedExtensions);
  }

  List<ExtensionEntity> get filteredAvailableExtensions {
    return _applyFilters(_availableExtensions);
  }

  // Extension counts per category (Task 5.10)
  Map<String, int> get extensionCounts {
    return _computeExtensionCounts();
  }

  /// Groups extensions by their ItemType (Task 5.2)
  ///
  /// Returns a map where keys are ItemTypes and values are lists of extensions
  /// with that ItemType. All extensions within each group have the same ItemType.
  Map<ItemType, List<ExtensionEntity>> _groupExtensionsByItemType(
    List<ExtensionEntity> extensions,
  ) {
    final Map<ItemType, List<ExtensionEntity>> grouped = {};

    for (final extension in extensions) {
      final itemType = extension.itemType;
      if (!grouped.containsKey(itemType)) {
        grouped[itemType] = [];
      }
      grouped[itemType]!.add(extension);
    }

    return grouped;
  }

  /// Filters extensions by language (Task 5.4)
  ///
  /// Returns only extensions whose language property matches the filter value.
  /// If filter is 'All', returns all extensions.
  List<ExtensionEntity> _filterByLanguage(List<ExtensionEntity> extensions) {
    if (_selectedLanguage == 'All') {
      return extensions;
    }
    return extensions
        .where(
          (ext) =>
              ext.language.toLowerCase() == _selectedLanguage.toLowerCase(),
        )
        .toList();
  }

  /// Filters extensions by search query (Task 5.6)
  ///
  /// Returns only extensions whose name contains the query string (case-insensitive).
  /// If query is empty, returns all extensions.
  List<ExtensionEntity> _filterBySearch(List<ExtensionEntity> extensions) {
    if (_searchQuery.isEmpty) {
      return extensions;
    }
    final query = _searchQuery.toLowerCase();
    return extensions
        .where((ext) => ext.name.toLowerCase().contains(query))
        .toList();
  }

  /// Applies both search and language filters (Task 5.8)
  ///
  /// Returns extensions that satisfy both the name search and language filter criteria.
  List<ExtensionEntity> _applyFilters(List<ExtensionEntity> extensions) {
    var filtered = extensions;
    filtered = _filterByLanguage(filtered);
    filtered = _filterBySearch(filtered);
    return filtered;
  }

  /// Computes extension counts per category for tab badges (Task 5.10)
  ///
  /// Returns a map with counts for each category:
  /// - installedAnime, availableAnime
  /// - installedManga, availableManga
  /// - installedNovel, availableNovel
  /// - installedCloudStream, availableCloudStream (Requirement 12.1)
  /// - updatePending
  Map<String, int> _computeExtensionCounts() {
    final installed = groupedInstalledExtensions;
    final available = groupedAvailableExtensions;

    // Count CloudStream extensions separately by type
    final installedCloudStream = _installedExtensions
        .where((e) => e.type == ExtensionType.cloudstream)
        .length;
    final availableCloudStream = _availableExtensions
        .where((e) => e.type == ExtensionType.cloudstream)
        .length;

    return {
      'installedAnime': installed[ItemType.anime]?.length ?? 0,
      'availableAnime': available[ItemType.anime]?.length ?? 0,
      'installedManga': installed[ItemType.manga]?.length ?? 0,
      'availableManga': available[ItemType.manga]?.length ?? 0,
      'installedNovel': installed[ItemType.novel]?.length ?? 0,
      'availableNovel': available[ItemType.novel]?.length ?? 0,
      'installedCloudStream': installedCloudStream,
      'availableCloudStream': availableCloudStream,
      'updatePending': updatePendingExtensions.length,
      'totalInstalled': _installedExtensions.length,
      'totalAvailable': _availableExtensions.length,
    };
  }

  /// Sets the search query and notifies listeners (Task 5.6)
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Sets the language filter and notifies listeners (Task 5.4)
  void setLanguageFilter(String language) {
    _selectedLanguage = language;
    notifyListeners();
  }

  /// Sets the current extension type and notifies listeners (Task 5.1)
  void setExtensionType(ExtensionType type) {
    _currentExtensionType = type;
    notifyListeners();
  }

  /// Saves repository configuration for an extension type
  Future<void> saveRepository(
    ExtensionType type,
    RepositoryConfig config,
  ) async {
    if (repositoryRepository == null) {
      _error = 'Repository management not available';
      notifyListeners();
      return;
    }

    try {
      final result = await repositoryRepository!.saveRepositoryConfig(
        type,
        config,
      );
      result.fold(
        (failure) {
          _error = ErrorMessageMapper.mapFailureToMessage(failure);
          Logger.error(
            'Failed to save repository config for type: $type',
            tag: 'ExtensionViewModel',
            error: failure,
          );
        },
        (_) {
          _repositoryConfigs[type] = config;
          // Reload extensions after saving new repository
          loadExtensions();
        },
      );
    } catch (e, stackTrace) {
      _error = 'An unexpected error occurred. Please try again.';
      Logger.error(
        'Unexpected error saving repository config',
        tag: 'ExtensionViewModel',
        error: e,
        stackTrace: stackTrace,
      );
    }
    notifyListeners();
  }

  /// Loads repository configurations for all extension types
  Future<void> _loadRepositoryConfigs() async {
    if (repositoryRepository == null) return;

    for (final type in ExtensionType.values) {
      try {
        final result = await repositoryRepository!.getRepositoryConfig(type);
        result.fold(
          (failure) {
            Logger.warning(
              'Failed to load repository config for type: $type',
              tag: 'ExtensionViewModel',
            );
          },
          (config) {
            _repositoryConfigs[type] = config;
          },
        );
      } catch (e, stackTrace) {
        Logger.error(
          'Error loading repository config for type: $type',
          tag: 'ExtensionViewModel',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
  }

  /// Detects updates for installed extensions by comparing with available versions (Task 6.2)
  ///
  /// For each installed extension, checks if there's a corresponding available extension
  /// with a higher version. If so, sets the hasUpdate flag to true and stores the
  /// latest available version in versionLast.
  ///
  /// Requirements: 6.1, 10.4
  List<ExtensionEntity> _detectUpdates(
    List<ExtensionEntity> installed,
    List<ExtensionEntity> available,
  ) {
    // Create a map of available extensions by ID for quick lookup
    final availableMap = <String, ExtensionEntity>{};
    for (final ext in available) {
      availableMap[ext.id] = ext;
    }

    // Check each installed extension for updates
    return installed.map((installedExt) {
      final availableExt = availableMap[installedExt.id];

      if (availableExt == null) {
        // No available version found, no update available
        return installedExt;
      }

      // Compare versions using the VersionComparator
      final hasUpdate = VersionComparator.hasUpdateAvailable(
        installedExt.version,
        availableExt.version,
      );

      if (hasUpdate) {
        // Update the extension with hasUpdate flag and latest version
        return installedExt.copyWith(
          hasUpdate: true,
          versionLast: availableExt.version,
          apkUrl: availableExt.apkUrl,
        );
      }

      return installedExt;
    }).toList();
  }

  Future<void> loadExtensions() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Load repository configurations first
      await _loadRepositoryConfigs();

      // Load all extension types
      final extensionTypes = ExtensionType.values;

      List<ExtensionEntity> allAvailable = [];
      List<ExtensionEntity> allInstalled = [];

      for (final type in extensionTypes) {
        try {
          // Get repository URLs for this extension type
          final repoConfig = _repositoryConfigs[type];
          final repos = repoConfig?.allUrls;

          // Only pass repos if there are actual URLs configured
          final reposToUse = (repos != null && repos.isNotEmpty) ? repos : null;

          Logger.debug(
            'Loading extensions for type: $type with repos: $reposToUse',
            tag: 'ExtensionViewModel',
          );

          // Load available extensions for this type with repository URLs
          final availableResult = await getAvailableExtensions(
            type,
            repos: reposToUse,
          );
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

      // Discover additional installed extensions (Task 12.3)
      // Requirement 10.2: Add discovered extensions to installed list
      if (extensionDiscoveryService != null) {
        try {
          final discoveryResult = await extensionDiscoveryService!
              .discoverInstalledExtensions();

          if (discoveryResult.success) {
            // Merge discovered extensions with loaded extensions
            allInstalled = _mergeDiscoveredExtensions(
              allInstalled,
              discoveryResult.discoveredExtensions,
            );

            Logger.info(
              'Discovered ${discoveryResult.discoveredExtensions.length} additional extensions',
              tag: 'ExtensionViewModel',
            );
          } else {
            // Log discovery errors but continue
            for (final error in discoveryResult.errors) {
              Logger.warning(
                'Extension discovery error: $error',
                tag: 'ExtensionViewModel',
              );
            }
          }
        } catch (e, stackTrace) {
          // Log error but continue with loaded extensions
          Logger.error(
            'Error during extension discovery',
            tag: 'ExtensionViewModel',
            error: e,
            stackTrace: stackTrace,
          );
        }
      }

      _availableExtensions = allAvailable;
      // Detect updates by comparing installed vs available versions (Task 6.2, 10.4)
      // Requirement 10.4: Check for available updates against repository data
      _installedExtensions = _detectUpdates(allInstalled, allAvailable);
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

  /// Merges discovered extensions with already loaded extensions (Task 12.3)
  ///
  /// Adds discovered extensions to the installed list, avoiding duplicates.
  /// Requirement 10.2: Add discovered extensions to installed list
  List<ExtensionEntity> _mergeDiscoveredExtensions(
    List<ExtensionEntity> loaded,
    List<ExtensionEntity> discovered,
  ) {
    // Create a set of existing extension IDs for quick lookup
    final existingIds = loaded.map((e) => e.id).toSet();

    // Add discovered extensions that aren't already in the loaded list
    final merged = List<ExtensionEntity>.from(loaded);
    for (final ext in discovered) {
      if (!existingIds.contains(ext.id)) {
        merged.add(ext);
        existingIds.add(ext.id);
      }
    }

    return merged;
  }

  /// Installs an extension with list transition management (Task 8.1)
  ///
  /// On success: Moves extension from available to installed list
  /// On failure: Retains extension in available list
  ///
  /// Requirements: 4.3, 4.4
  Future<void> install(String extensionId, ExtensionType type) async {
    // Request install packages permission first
    if (permissionService != null) {
      final hasPermission = await permissionService!.requestInstallPackagesPermission();
      if (!hasPermission) {
        _error = 'Install packages permission is required to install extensions';
        notifyListeners();
        return;
      }
    }

    _installingExtensionId = extensionId;
    _installationProgress = 'Installing extension...';
    _error = null;
    notifyListeners();

    // Find the extension in available list before installation
    final extensionToInstall = _availableExtensions.firstWhere(
      (ext) => ext.id == extensionId,
      orElse: () => ExtensionEntity(
        id: extensionId,
        name: 'Unknown',
        version: '0.0.0',
        type: type,
        language: 'en',
        isInstalled: false,
        isNsfw: false,
      ),
    );

    try {
      final result = await installExtension(extensionId, type);

      result.fold(
        (failure) {
          // On failure: Retain extension in available list (Requirement 4.4)
          _error = ErrorMessageMapper.mapFailureToMessage(failure);
          _installationProgress = null;
          Logger.error(
            'Failed to install extension: $extensionId',
            tag: 'ExtensionViewModel',
            error: failure,
          );
        },
        (_) {
          // On success: Move extension from available to installed (Requirement 4.3)
          _installationProgress = 'Installation complete';
          _moveExtensionToInstalled(extensionToInstall);
        },
      );
    } catch (e, stackTrace) {
      // On failure: Retain extension in available list (Requirement 4.4)
      _error = 'An unexpected error occurred. Please try again.';
      _installationProgress = null;
      Logger.error(
        'Unexpected error installing extension: $extensionId',
        tag: 'ExtensionViewModel',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      _installingExtensionId = null;
      notifyListeners();
      // Clear installation progress after a delay
      Future.delayed(const Duration(seconds: 2), () {
        _installationProgress = null;
        notifyListeners();
      });
    }
  }

  /// Moves an extension from available to installed list (Task 8.1)
  ///
  /// Creates a new installed version of the extension and removes it from available.
  /// Requirements: 4.3
  void _moveExtensionToInstalled(ExtensionEntity extension) {
    // Create installed version of the extension
    final installedExtension = extension.copyWith(
      isInstalled: true,
      hasUpdate: false,
    );

    // Remove from available list
    _availableExtensions = _availableExtensions
        .where((ext) => ext.id != extension.id)
        .toList();

    // Add to installed list (avoid duplicates)
    if (!_installedExtensions.any((ext) => ext.id == extension.id)) {
      _installedExtensions = [..._installedExtensions, installedExtension];
    } else {
      // Update existing entry
      _installedExtensions = _installedExtensions.map((ext) {
        if (ext.id == extension.id) {
          return installedExtension;
        }
        return ext;
      }).toList();
    }

    Logger.info(
      'Extension ${extension.name} moved to installed list',
      tag: 'ExtensionViewModel',
    );
  }

  /// Uninstalls an extension with list transition management (Task 8.4)
  ///
  /// On success: Moves extension from installed to available list
  /// On failure: Retains extension in installed list
  ///
  /// Requirements: 5.3, 5.4
  Future<void> uninstall(String extensionId) async {
    _uninstallingExtensionId = extensionId;
    _error = null;
    notifyListeners();

    // Find the extension in installed list before uninstallation
    final extensionToUninstall = _installedExtensions.firstWhere(
      (ext) => ext.id == extensionId,
      orElse: () => throw Exception('Extension not found in installed list'),
    );

    try {
      final result = await uninstallExtension(extensionId);

      result.fold(
        (failure) {
          // On failure: Retain extension in installed list (Requirement 5.4)
          _error = ErrorMessageMapper.mapFailureToMessage(failure);
          Logger.error(
            'Failed to uninstall extension: $extensionId',
            tag: 'ExtensionViewModel',
            error: failure,
          );
        },
        (_) {
          // On success: Move extension from installed to available (Requirement 5.3)
          _moveExtensionToAvailable(extensionToUninstall);
        },
      );
    } catch (e, stackTrace) {
      // On failure: Retain extension in installed list (Requirement 5.4)
      _error = 'An unexpected error occurred. Please try again.';
      Logger.error(
        'Unexpected error uninstalling extension: $extensionId',
        tag: 'ExtensionViewModel',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      _uninstallingExtensionId = null;
      notifyListeners();
    }
  }

  /// Moves an extension from installed to available list (Task 8.4)
  ///
  /// Creates an available version of the extension and removes it from installed.
  /// Requirements: 5.3
  void _moveExtensionToAvailable(ExtensionEntity extension) {
    // Create available version of the extension
    final availableExtension = extension.copyWith(
      isInstalled: false,
      hasUpdate: false,
    );

    // Remove from installed list
    _installedExtensions = _installedExtensions
        .where((ext) => ext.id != extension.id)
        .toList();

    // Add to available list (avoid duplicates)
    if (!_availableExtensions.any((ext) => ext.id == extension.id)) {
      _availableExtensions = [..._availableExtensions, availableExtension];
    } else {
      // Update existing entry
      _availableExtensions = _availableExtensions.map((ext) {
        if (ext.id == extension.id) {
          return availableExtension;
        }
        return ext;
      }).toList();
    }

    Logger.info(
      'Extension ${extension.name} moved to available list',
      tag: 'ExtensionViewModel',
    );
  }

  /// Updates a single extension to its latest version (Task 8.7)
  ///
  /// Downloads and installs the new version, then refreshes the extension list.
  /// Requirements: 6.3, 6.5
  Future<void> update(String extensionId) async {
    final extension = _installedExtensions.firstWhere(
      (ext) => ext.id == extensionId,
      orElse: () => throw Exception('Extension not found'),
    );

    if (!extension.hasUpdate) {
      _error = 'No update available for this extension';
      notifyListeners();
      return;
    }

    _installationProgress = 'Updating ${extension.name}...';
    _error = null;
    notifyListeners();

    try {
      final result = await installExtension(extensionId, extension.type);

      result.fold(
        (failure) {
          _error = ErrorMessageMapper.mapFailureToMessage(failure);
          _installationProgress = null;
          Logger.error(
            'Failed to update extension: $extensionId',
            tag: 'ExtensionViewModel',
            error: failure,
          );
        },
        (_) {
          // Update successful - update the extension in the installed list
          _installationProgress = 'Update complete';
          _updateExtensionVersion(extension);
        },
      );
    } catch (e, stackTrace) {
      _error = 'An unexpected error occurred. Please try again.';
      _installationProgress = null;
      Logger.error(
        'Unexpected error updating extension: $extensionId',
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

  /// Updates the extension version in the installed list after successful update
  ///
  /// Sets the version to versionLast and clears the hasUpdate flag.
  /// Requirements: 6.5
  void _updateExtensionVersion(ExtensionEntity extension) {
    _installedExtensions = _installedExtensions.map((ext) {
      if (ext.id == extension.id) {
        return ext.copyWith(
          version: ext.versionLast ?? ext.version,
          versionLast: null,
          hasUpdate: false,
        );
      }
      return ext;
    }).toList();

    Logger.info(
      'Extension ${extension.name} updated to version ${extension.versionLast}',
      tag: 'ExtensionViewModel',
    );
  }

  /// Updates all extensions with pending updates (Task 8.7)
  ///
  /// Iterates through all extensions with hasUpdate=true and updates them.
  /// Requirements: 6.4, 6.5
  Future<void> updateAll() async {
    final pendingUpdates = updatePendingExtensions;

    if (pendingUpdates.isEmpty) {
      _installationProgress = 'No updates available';
      notifyListeners();
      Future.delayed(const Duration(seconds: 2), () {
        _installationProgress = null;
        notifyListeners();
      });
      return;
    }

    _installationProgress = 'Updating ${pendingUpdates.length} extensions...';
    _error = null;
    notifyListeners();

    int successCount = 0;
    int failCount = 0;

    for (int i = 0; i < pendingUpdates.length; i++) {
      final extension = pendingUpdates[i];
      _installationProgress =
          'Updating ${extension.name} (${i + 1}/${pendingUpdates.length})...';
      notifyListeners();

      try {
        final result = await installExtension(extension.id, extension.type);

        result.fold(
          (failure) {
            failCount++;
            Logger.error(
              'Failed to update extension: ${extension.id}',
              tag: 'ExtensionViewModel',
              error: failure,
            );
          },
          (_) {
            successCount++;
            _updateExtensionVersion(extension);
          },
        );
      } catch (e, stackTrace) {
        failCount++;
        Logger.error(
          'Unexpected error updating extension: ${extension.id}',
          tag: 'ExtensionViewModel',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }

    // Show completion message
    if (failCount == 0) {
      _installationProgress = 'All $successCount extensions updated';
    } else if (successCount == 0) {
      _installationProgress = 'Failed to update all extensions';
      _error = 'All updates failed. Please try again.';
    } else {
      _installationProgress = '$successCount updated, $failCount failed';
    }

    notifyListeners();

    Future.delayed(const Duration(seconds: 3), () {
      _installationProgress = null;
      notifyListeners();
    });
  }

  /// Returns a list of unique languages from all extensions
  List<String> get availableLanguages {
    final languages = <String>{'All'};
    for (final ext in [..._installedExtensions, ..._availableExtensions]) {
      languages.add(ext.language);
    }
    return languages.toList()..sort();
  }
}
