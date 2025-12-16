import 'dart:io';

import 'package:dartotsu_extension_bridge/CloudStream/CloudStreamExtensions.dart';
import 'package:dartotsu_extension_bridge/CloudStream/desktop/cloudstream_desktop_channel_handler.dart';
import 'package:dartotsu_extension_bridge/ExtensionManager.dart';
import 'package:dartotsu_extension_bridge/Models/Source.dart';
import 'package:dartotsu_extension_bridge/Extensions/Extensions.dart' as bridge;
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../../../core/constants/default_repositories.dart';
import '../../../core/data/models/repository_config_model.dart';
import '../../../core/domain/entities/extension_entity.dart' as domain;
import '../../../core/utils/logger.dart';

/// Controller responsible for managing extension repositories and installed sources.
///
/// 📝 Inspired by AnymeX SourceController implementation.
class ExtensionsController extends GetxController {
  ExtensionsController({required Box themeBox}) : _themeBox = themeBox;

  final Box _themeBox;

  final RxList<Source> _availableAnimeExtensions = <Source>[].obs;
  final RxList<Source> _availableMangaExtensions = <Source>[].obs;
  final RxList<Source> _availableNovelExtensions = <Source>[].obs;
  final RxList<Source> _availableMovieExtensions = <Source>[].obs;
  final RxList<Source> _availableTvExtensions = <Source>[].obs;
  final RxList<Source> _availableCartoonExtensions = <Source>[].obs;
  final RxList<Source> _availableDocumentaryExtensions = <Source>[].obs;
  final RxList<Source> _availableLivestreamExtensions = <Source>[].obs;
  final RxList<Source> _availableNsfwExtensions = <Source>[].obs;

  final RxList<Source> _installedAnimeExtensions = <Source>[].obs;
  final RxList<Source> _installedMangaExtensions = <Source>[].obs;
  final RxList<Source> _installedNovelExtensions = <Source>[].obs;
  final RxList<Source> _installedMovieExtensions = <Source>[].obs;
  final RxList<Source> _installedTvExtensions = <Source>[].obs;
  final RxList<Source> _installedCartoonExtensions = <Source>[].obs;
  final RxList<Source> _installedDocumentaryExtensions = <Source>[].obs;
  final RxList<Source> _installedLivestreamExtensions = <Source>[].obs;
  final RxList<Source> _installedNsfwExtensions = <Source>[].obs;

  final Rxn<Source> activeAnimeSource = Rxn<Source>();
  final Rxn<Source> activeMangaSource = Rxn<Source>();
  final Rxn<Source> activeNovelSource = Rxn<Source>();

  final RxBool shouldShowExtensions = false.obs;
  final RxnString installingSourceId = RxnString();
  final RxnString uninstallingSourceId = RxnString();
  final RxnString updatingSourceId = RxnString();
  final RxnString operationMessage = RxnString();

  /// CloudStream desktop capabilities (null on Android or if not initialized).
  final Rxn<Map<String, dynamic>> cloudStreamCapabilities = Rxn();

  /// Whether CloudStream can execute JS plugins on desktop.
  bool get canExecuteJsPlugins =>
      cloudStreamCapabilities.value?['canExecuteJs'] == true;

  /// Whether CloudStream can execute DEX plugins on desktop.
  bool get canExecuteDexPlugins =>
      cloudStreamCapabilities.value?['canExecuteDex'] == true;

  /// Whether CloudStream is fully functional (can execute plugins).
  bool get isCloudStreamFunctional =>
      Platform.isAndroid || canExecuteJsPlugins || canExecuteDexPlugins;

  final RxString _activeAnimeRepo = ''.obs;
  final RxString _activeMangaRepo = ''.obs;
  final RxString _activeNovelRepo = ''.obs;
  final RxString _activeAniyomiAnimeRepo = ''.obs;
  final RxString _activeAniyomiMangaRepo = ''.obs;
  final RxString _activeCloudStreamAnimeRepo = ''.obs;
  final RxString _activeCloudStreamMangaRepo = ''.obs;
  final RxString _activeCloudStreamNovelRepo = ''.obs;
  final RxString _activeCloudStreamMovieRepo = ''.obs;
  final RxString _activeCloudStreamTvRepo = ''.obs;
  final RxString _activeCloudStreamCartoonRepo = ''.obs;
  final RxString _activeCloudStreamDocumentaryRepo = ''.obs;
  final RxString _activeCloudStreamLivestreamRepo = ''.obs;
  final RxString _activeCloudStreamNsfwRepo = ''.obs;

  final RxMap<domain.ItemType, List<CloudStreamExtensionGroup>>
  _cloudStreamGroups = {
    for (final type in domain.ItemType.values)
      type: <CloudStreamExtensionGroup>[],
  }.obs;

  final RxMap<String, CloudStreamGroupInstallResult?> _groupInstallStatuses =
      <String, CloudStreamGroupInstallResult?>{}.obs;

  final RxnString installingGroupId = RxnString();

  List<CloudStreamExtensionGroup> cloudStreamGroupsFor(domain.ItemType type) =>
      _cloudStreamGroups[type] ?? const [];

  List<CloudStreamExtensionGroup> get allCloudStreamGroups =>
      _cloudStreamGroups.values.expand((groups) => groups).toList();

  CloudStreamGroupInstallResult? groupInstallStatus(String groupId) =>
      _groupInstallStatuses[groupId];

  Map<String, CloudStreamGroupInstallResult?> get groupInstallStatuses =>
      _groupInstallStatuses;

  Future<void> _reloadCloudStreamPlugins() async {
    // CloudStream is supported on Android, Linux, and Windows
    if (!GetPlatform.isAndroid &&
        !GetPlatform.isLinux &&
        !GetPlatform.isWindows) {
      return;
    }
    const channel = MethodChannel('cloudstreamExtensionBridge');
    try {
      await channel.invokeMethod('initializePlugins');
      // cloudstream:reloadPlugins may not be implemented on desktop
      try {
        await channel.invokeMethod('cloudstream:reloadPlugins');
      } catch (e) {
        // Ignore - desktop may not support this method
        Logger.debug('cloudstream:reloadPlugins not available: $e');
      }
      final manager = ExtensionType.cloudstream.getManager();
      if (manager is CloudStreamExtensions) {
        for (final type in _cloudStreamItemTypes) {
          await _fetchCloudStreamForType(manager, type);
        }
        await manager.refreshInstalledLists();
        await _sortAllExtensions();
      }
      // Update capabilities after reload
      await _fetchCloudStreamCapabilities();
    } catch (e) {
      Logger.warning('Failed to reload CloudStream plugins: $e');
    }
  }

  /// Fetch CloudStream desktop capabilities.
  Future<void> _fetchCloudStreamCapabilities() async {
    if (Platform.isAndroid) {
      // On Android, CloudStream is fully functional via native bridge
      cloudStreamCapabilities.value = {
        'platform': 'android',
        'isInitialized': true,
        'canExecuteJs': false, // Not applicable on Android
        'canExecuteDex': true, // Native DEX execution
        'canUseExtractors': true,
      };
      return;
    }

    if (!Platform.isLinux && !Platform.isWindows) {
      cloudStreamCapabilities.value = null;
      return;
    }

    // On desktop, get capabilities from the desktop bridge
    final handler = CloudStreamDesktopChannelHandler.instance;
    if (handler.isSetup) {
      cloudStreamCapabilities.value = handler.bridge.getCapabilities();
    } else {
      cloudStreamCapabilities.value = {
        'platform': Platform.operatingSystem,
        'isInitialized': false,
        'canExecuteJs': false,
        'canExecuteDex': false,
        'canUseExtractors': false,
        'error': 'Desktop bridge not initialized',
      };
    }
  }

  final RxBool _isInitializing = false.obs;
  bool get isInitializing => _isInitializing.value;

  @override
  void onInit() {
    super.onInit();
    _restoreRepoSettings();
    _initializeExtensions();
    _ensureDefaultRepos();
    _fetchCloudStreamCapabilities();
  }

  Future<void> applyCloudStreamRepoUrlForAllTypes(String repoUrl) async {
    for (final type in _cloudStreamItemTypes) {
      await applyCloudStreamRepoUrl(type, repoUrl);
    }
  }

  void _ensureDefaultRepos() {
    bool updated = false;
    if (_activeAniyomiAnimeRepo.value.isEmpty) {
      _activeAniyomiAnimeRepo.value = DefaultRepositories.aniyomiAnimeRepo;
      updated = true;
    }
    if (_activeAniyomiMangaRepo.value.isEmpty) {
      _activeAniyomiMangaRepo.value = DefaultRepositories.aniyomiMangaRepo;
      updated = true;
    }
    if (_activeAnimeRepo.value.isEmpty) {
      _activeAnimeRepo.value = DefaultRepositories.mangayomiAnimeRepo;
      updated = true;
    }
    if (_activeMangaRepo.value.isEmpty) {
      _activeMangaRepo.value = DefaultRepositories.mangayomiMangaRepo;
      updated = true;
    }
    if (_activeNovelRepo.value.isEmpty) {
      _activeNovelRepo.value = DefaultRepositories.mangayomiNovelRepo;
      updated = true;
    }
    if (updated) {
      _persistRepoSettings();
    }
  }

  Future<void> installCloudStreamExtensionFromUrl(String url) async {
    final trimmedUrl = url.trim();
    final uri = Uri.tryParse(trimmedUrl);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      throw FormatException('Please enter a valid http(s) URL');
    }

    final lowerPath = uri.path.toLowerCase();
    final looksLikeManifest = lowerPath.endsWith('.json');

    if (looksLikeManifest) {
      await applyCloudStreamRepoUrlForAllTypes(trimmedUrl);
      _setOperationMessage(
        'Repository applied to all CloudStream categories',
        autoClear: true,
      );
      return;
    }

    final bridgeItemType = ItemType.anime;
    final sourceId = _deriveIdFromUrl(uri);
    final sourceName = _deriveNameFromUrl(uri);

    final source = Source(
      id: sourceId,
      name: sourceName,
      extensionType: ExtensionType.cloudstream,
      itemType: bridgeItemType,
      apkUrl: trimmedUrl,
      lang: 'all',
    );

    installingSourceId.value = source.id;
    _setOperationMessage('Installing $sourceName...');
    try {
      await installSource(source);
      _setOperationMessage('Installed $sourceName', autoClear: true);
      await _reloadCloudStreamPlugins();
    } catch (_) {
      _setOperationMessage('Failed to install $sourceName', autoClear: true);
      rethrow;
    } finally {
      installingSourceId.value = null;
    }
  }

  Future<void> applyCloudStreamRepoUrl(
    domain.ItemType itemType,
    String repoUrl,
  ) async {
    final trimmedUrl = repoUrl.trim();
    final uri = Uri.tryParse(trimmedUrl);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      throw FormatException('Please enter a valid http(s) URL');
    }

    _setCloudStreamRepo(itemType, trimmedUrl);

    try {
      final manager = ExtensionType.cloudstream.getManager();
      if (manager is CloudStreamExtensions) {
        await _fetchCloudStreamForType(manager, itemType);
      }
      await _sortAllExtensions();
    } catch (error, stackTrace) {
      Logger.error(
        'Failed to apply CloudStream repo for $itemType',
        tag: 'ExtensionsController',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  List<domain.ExtensionEntity> get installedEntities => _dedupeExtensions(
    _mapSourcesToEntities(_allInstalledSources, installed: true),
  );
  List<domain.ExtensionEntity> get availableEntities => _dedupeExtensions(
    _mapSourcesToEntities(_allAvailableSources, installed: false),
  );
  List<domain.ExtensionEntity> get updatePendingExtensions =>
      installedEntities.where((ext) => ext.hasUpdate).toList();
  List<String> get availableLanguages {
    final languages = <String>{'All'};
    for (final extension in [...installedEntities, ...availableEntities]) {
      languages.add(extension.language);
    }
    return languages.toList()..sort();
  }

  Source? findInstalledSource(String id) =>
      _firstWhereOrNull(_allInstalledSources, (s) => s.id == id);

  Source? findAvailableSource(String id) =>
      _firstWhereOrNull(_allAvailableSources, (s) => s.id == id);

  String get activeAnimeRepo => _activeAnimeRepo.value;
  String get activeMangaRepo => _activeMangaRepo.value;
  String get activeNovelRepo => _activeNovelRepo.value;
  String get activeAniyomiAnimeRepo => _activeAniyomiAnimeRepo.value;
  String get activeAniyomiMangaRepo => _activeAniyomiMangaRepo.value;

  Future<void> fetchRepos() async {
    _isInitializing.value = true;
    try {
      for (final type in _supportedExtensionTypes) {
        final manager = type.getManager();
        if (type == ExtensionType.cloudstream &&
            manager is CloudStreamExtensions) {
          for (final domainType in _cloudStreamItemTypes) {
            await _fetchCloudStreamForType(manager, domainType);
          }
          continue;
        }

        await manager.fetchAvailableAnimeExtensions([
          _getRepoForType(type, isAnime: true),
        ]);
        await manager.fetchAvailableMangaExtensions([
          _getRepoForType(type, isAnime: false),
        ]);
        await manager.fetchAvailableNovelExtensions([_activeNovelRepo.value]);
      }

      await _sortAllExtensions();
      await _reloadCloudStreamPlugins();
    } catch (error, stack) {
      Logger.error(
        'Failed to fetch extension repos',
        tag: 'ExtensionsController',
        error: error,
        stackTrace: stack,
      );
    } finally {
      _isInitializing.value = false;
    }
  }

  Future<void> installSource(Source source) async {
    try {
      final manager = source.extensionType?.getManager();
      if (manager == null) {
        throw StateError('Missing extension manager for ${source.id}');
      }
      await manager.installSource(source);
      await _sortAllExtensions();
      if (source.extensionType == ExtensionType.cloudstream) {
        await _reloadCloudStreamPlugins();
      }
    } catch (error, stack) {
      Logger.error(
        'Failed to install ${source.name}',
        tag: 'ExtensionsController',
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<void> uninstallSource(Source source) async {
    try {
      final manager = source.extensionType?.getManager();
      if (manager == null) {
        throw StateError('Missing extension manager for ${source.id}');
      }
      await manager.uninstallSource(source);
      await _sortAllExtensions();
    } catch (error, stack) {
      Logger.error(
        'Failed to uninstall ${source.name}',
        tag: 'ExtensionsController',
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<void> updateExtension(Source source) async {
    try {
      final manager = source.extensionType?.getManager();
      if (manager == null) {
        throw StateError('Missing extension manager for ${source.id}');
      }
      await manager.updateSource(source);
      await _sortAllExtensions();
    } catch (error, stack) {
      Logger.error(
        'Failed to update ${source.name}',
        tag: 'ExtensionsController',
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  RepositoryConfig getRepositoryConfig(ExtensionType type) {
    if (type == ExtensionType.cloudstream) {
      return RepositoryConfig(
        animeRepoUrl: _valueOrNull(_activeCloudStreamAnimeRepo.value),
        mangaRepoUrl: _valueOrNull(_activeCloudStreamMangaRepo.value),
        novelRepoUrl: _valueOrNull(_activeCloudStreamNovelRepo.value),
        movieRepoUrl: _valueOrNull(_activeCloudStreamMovieRepo.value),
        tvShowRepoUrl: _valueOrNull(_activeCloudStreamTvRepo.value),
        cartoonRepoUrl: _valueOrNull(_activeCloudStreamCartoonRepo.value),
        documentaryRepoUrl: _valueOrNull(
          _activeCloudStreamDocumentaryRepo.value,
        ),
        livestreamRepoUrl: _valueOrNull(_activeCloudStreamLivestreamRepo.value),
        nsfwRepoUrl: _valueOrNull(_activeCloudStreamNsfwRepo.value),
      );
    }

    final animeRepo = type == ExtensionType.aniyomi
        ? _activeAniyomiAnimeRepo.value
        : _activeAnimeRepo.value;
    final mangaRepo = type == ExtensionType.aniyomi
        ? _activeAniyomiMangaRepo.value
        : _activeMangaRepo.value;
    final novelRepo = type == ExtensionType.mangayomi
        ? _activeNovelRepo.value
        : '';

    return RepositoryConfig(
      animeRepoUrl: _valueOrNull(animeRepo),
      mangaRepoUrl: _valueOrNull(mangaRepo),
      novelRepoUrl: _valueOrNull(novelRepo),
    );
  }

  Future<void> installExtensionById(String sourceId) async {
    final source = findAvailableSource(sourceId);
    if (source == null) {
      Logger.warning(
        'Source $sourceId not found in available list',
        tag: 'ExtensionsController',
      );
      return;
    }

    installingSourceId.value = sourceId;
    _setOperationMessage('Installing ${source.name ?? 'extension'}...');
    try {
      await installSource(source);
      _setOperationMessage(
        'Installed ${source.name ?? 'extension'}',
        autoClear: true,
      );
    } catch (_) {
      _setOperationMessage(
        'Failed to install ${source.name ?? 'extension'}',
        autoClear: true,
      );
    } finally {
      installingSourceId.value = null;
    }
  }

  Future<void> uninstallExtensionById(String sourceId) async {
    final source = findInstalledSource(sourceId);
    if (source == null) {
      Logger.warning(
        'Source $sourceId not found in installed list',
        tag: 'ExtensionsController',
      );
      return;
    }

    uninstallingSourceId.value = sourceId;
    _setOperationMessage('Uninstalling ${source.name ?? 'extension'}...');
    try {
      await uninstallSource(source);
      _setOperationMessage(
        'Uninstalled ${source.name ?? 'extension'}',
        autoClear: true,
      );
    } catch (_) {
      _setOperationMessage(
        'Failed to uninstall ${source.name ?? 'extension'}',
        autoClear: true,
      );
    } finally {
      uninstallingSourceId.value = null;
    }
  }

  Future<void> updateExtensionById(String sourceId) async {
    final source = findInstalledSource(sourceId);
    if (source == null) {
      Logger.warning(
        'Source $sourceId not found for update',
        tag: 'ExtensionsController',
      );
      return;
    }

    updatingSourceId.value = sourceId;
    _setOperationMessage('Updating ${source.name ?? 'extension'}...');
    try {
      await updateExtension(source);
      _setOperationMessage(
        'Updated ${source.name ?? 'extension'}',
        autoClear: true,
      );
    } catch (_) {
      _setOperationMessage(
        'Failed to update ${source.name ?? 'extension'}',
        autoClear: true,
      );
    } finally {
      updatingSourceId.value = null;
    }
  }

  Future<void> updateAllPendingExtensions() async {
    final pending = updatePendingExtensions;
    if (pending.isEmpty) {
      _setOperationMessage('No updates available', autoClear: true);
      return;
    }

    int successCount = 0;
    int failCount = 0;
    for (var i = 0; i < pending.length; i++) {
      final extension = pending[i];
      _setOperationMessage(
        'Updating ${extension.name} (${i + 1}/${pending.length})...',
      );
      try {
        await updateExtensionById(extension.id);
        successCount++;
      } catch (_) {
        failCount++;
      }
    }

    updatingSourceId.value = null;
    if (failCount == 0) {
      _setOperationMessage(
        'All $successCount extensions updated',
        autoClear: true,
      );
    } else if (successCount == 0) {
      _setOperationMessage('Failed to update extensions', autoClear: true);
    } else {
      _setOperationMessage(
        '$successCount updated, $failCount failed',
        autoClear: true,
      );
    }
  }

  Future<void> applyRepositoryConfig(
    ExtensionType type,
    RepositoryConfig config,
  ) async {
    if (type == ExtensionType.cloudstream) {
      _setCloudStreamRepo(domain.ItemType.anime, config.animeRepoUrl ?? '');
      _setCloudStreamRepo(domain.ItemType.manga, config.mangaRepoUrl ?? '');
      _setCloudStreamRepo(domain.ItemType.novel, config.novelRepoUrl ?? '');
      _setCloudStreamRepo(domain.ItemType.movie, config.movieRepoUrl ?? '');
      _setCloudStreamRepo(domain.ItemType.tvShow, config.tvShowRepoUrl ?? '');
      _setCloudStreamRepo(domain.ItemType.cartoon, config.cartoonRepoUrl ?? '');
      _setCloudStreamRepo(
        domain.ItemType.documentary,
        config.documentaryRepoUrl ?? '',
      );
      _setCloudStreamRepo(
        domain.ItemType.livestream,
        config.livestreamRepoUrl ?? '',
      );
      _setCloudStreamRepo(domain.ItemType.nsfw, config.nsfwRepoUrl ?? '');
    } else {
      _setAnimeRepo(config.animeRepoUrl ?? '', type);
      _setMangaRepo(config.mangaRepoUrl ?? '', type);
      if (type == ExtensionType.mangayomi) {
        _setNovelRepo(config.novelRepoUrl ?? '');
      }
    }
    await fetchRepos();
  }

  List<Source> get _allInstalledSources => [
    ..._installedAnimeExtensions,
    ..._installedMangaExtensions,
    ..._installedNovelExtensions,
    ..._installedMovieExtensions,
    ..._installedTvExtensions,
    ..._installedCartoonExtensions,
    ..._installedDocumentaryExtensions,
    ..._installedLivestreamExtensions,
    ..._installedNsfwExtensions,
  ];

  List<Source> get _allAvailableSources => [
    ..._availableAnimeExtensions,
    ..._availableMangaExtensions,
    ..._availableNovelExtensions,
    ..._availableMovieExtensions,
    ..._availableTvExtensions,
    ..._availableCartoonExtensions,
    ..._availableDocumentaryExtensions,
    ..._availableLivestreamExtensions,
    ..._availableNsfwExtensions,
  ];

  Iterable<ExtensionType> get _supportedExtensionTypes sync* {
    for (final type in ExtensionType.values) {
      if (!Platform.isAndroid && type == ExtensionType.aniyomi) continue;
      yield type;
    }
  }

  Future<void> _initializeExtensions() async {
    _isInitializing.value = true;
    try {
      await _sortAllExtensions();
      _restoreActiveSources();
      _updateShouldShowExtensions();
    } catch (error, stack) {
      Logger.error(
        'Failed to initialize extensions',
        tag: 'ExtensionsController',
        error: error,
        stackTrace: stack,
      );
    } finally {
      _isInitializing.value = false;
    }
  }

  Future<void> _sortAllExtensions() async {
    final installedByType = {
      for (final domainType in domain.ItemType.values) domainType: <Source>[],
    };
    final availableByType = {
      for (final domainType in domain.ItemType.values) domainType: <Source>[],
    };

    for (final extensionType in _supportedExtensionTypes) {
      final manager = extensionType.getManager();
      for (final domainType in domain.ItemType.values) {
        final bridgeType = _mapDomainItemTypeToBridge(domainType);
        if (bridgeType == null) continue;

        final installed = await _getInstalledForManager(manager, bridgeType);
        if (installed.isNotEmpty) {
          installedByType[domainType]!.addAll(installed);
        }

        final available = _getAvailableForManager(manager, bridgeType);
        if (available.isNotEmpty) {
          availableByType[domainType]!.addAll(available);
        }
      }
    }

    _installedAnimeExtensions.value = installedByType[domain.ItemType.anime]!;
    _installedMangaExtensions.value = installedByType[domain.ItemType.manga]!;
    _installedNovelExtensions.value = installedByType[domain.ItemType.novel]!;
    _installedMovieExtensions.value = installedByType[domain.ItemType.movie]!;
    _installedTvExtensions.value = installedByType[domain.ItemType.tvShow]!;
    _installedCartoonExtensions.value =
        installedByType[domain.ItemType.cartoon]!;
    _installedDocumentaryExtensions.value =
        installedByType[domain.ItemType.documentary]!;
    _installedLivestreamExtensions.value =
        installedByType[domain.ItemType.livestream]!;
    _installedNsfwExtensions.value = installedByType[domain.ItemType.nsfw]!;

    _availableAnimeExtensions.value = availableByType[domain.ItemType.anime]!;
    _availableMangaExtensions.value = availableByType[domain.ItemType.manga]!;
    _availableNovelExtensions.value = availableByType[domain.ItemType.novel]!;
    _availableMovieExtensions.value = availableByType[domain.ItemType.movie]!;
    _availableTvExtensions.value = availableByType[domain.ItemType.tvShow]!;
    _availableCartoonExtensions.value =
        availableByType[domain.ItemType.cartoon]!;
    _availableDocumentaryExtensions.value =
        availableByType[domain.ItemType.documentary]!;
    _availableLivestreamExtensions.value =
        availableByType[domain.ItemType.livestream]!;
    _availableNsfwExtensions.value = availableByType[domain.ItemType.nsfw]!;

    _updateShouldShowExtensions();
  }

  Future<void> _captureCloudStreamGroups(
    domain.ItemType itemType,
    List<CloudStreamExtensionGroup> groups,
  ) async {
    _cloudStreamGroups[itemType] = List<CloudStreamExtensionGroup>.from(groups);
    _cloudStreamGroups.refresh();
  }

  final List<domain.ItemType> _cloudStreamItemTypes = const [
    domain.ItemType.anime,
    domain.ItemType.manga,
    domain.ItemType.novel,
    domain.ItemType.movie,
    domain.ItemType.tvShow,
    domain.ItemType.cartoon,
    domain.ItemType.documentary,
    domain.ItemType.livestream,
    domain.ItemType.nsfw,
  ];

  List<domain.ItemType> get cloudStreamItemTypes =>
      List<domain.ItemType>.unmodifiable(_cloudStreamItemTypes);

  Future<void> _fetchCloudStreamForType(
    CloudStreamExtensions manager,
    domain.ItemType domainType,
  ) async {
    final repos = _getCloudStreamReposForItem(domainType);
    switch (domainType) {
      case domain.ItemType.anime:
        await manager.fetchAvailableAnimeExtensions(repos);
        break;
      case domain.ItemType.manga:
        await manager.fetchAvailableMangaExtensions(repos);
        break;
      case domain.ItemType.novel:
        await manager.fetchAvailableNovelExtensions(repos);
        break;
      case domain.ItemType.movie:
        await manager.fetchAvailableMovieExtensions(repos);
        break;
      case domain.ItemType.tvShow:
        await manager.fetchAvailableTvShowExtensions(repos);
        break;
      case domain.ItemType.cartoon:
        await manager.fetchAvailableCartoonExtensions(repos);
        break;
      case domain.ItemType.documentary:
        await manager.fetchAvailableDocumentaryExtensions(repos);
        break;
      case domain.ItemType.livestream:
        await manager.fetchAvailableLivestreamExtensions(repos);
        break;
      case domain.ItemType.nsfw:
        await manager.fetchAvailableNsfwExtensions(repos);
        break;
    }

    final bridgeType = _mapDomainItemTypeToBridge(domainType);
    if (bridgeType != null) {
      await _captureCloudStreamGroups(
        domainType,
        manager.getAvailableGroups(bridgeType),
      );
    }
  }

  Future<CloudStreamGroupInstallResult> installCloudStreamGroup(
    CloudStreamExtensionGroup group, {
    bool continueOnError = true,
  }) async {
    final manager = ExtensionType.cloudstream.getManager();
    if (manager is! CloudStreamExtensions) {
      throw StateError('CloudStream manager unavailable');
    }
    _setOperationMessage('Installing ${group.name} (bundle)...');
    installingGroupId.value = group.id;
    try {
      final result = await manager.installExtensionGroup(
        group,
        continueOnError: continueOnError,
      );
      _groupInstallStatuses[group.id] = result;
      await _sortAllExtensions();
      await _reloadCloudStreamPlugins();
      return result;
    } catch (error, stack) {
      Logger.error(
        'Failed to install group ${group.name}',
        tag: 'ExtensionsController',
        error: error,
        stackTrace: stack,
      );
      rethrow;
    } finally {
      _setOperationMessage(
        'Completed group install for ${group.name}',
        autoClear: true,
      );
      installingGroupId.value = null;
    }
  }

  void _restoreRepoSettings() {
    _activeAnimeRepo.value =
        _themeBox.get('activeAnimeRepo', defaultValue: '') as String;
    _activeMangaRepo.value =
        _themeBox.get('activeMangaRepo', defaultValue: '') as String;
    _activeNovelRepo.value =
        _themeBox.get('activeNovelRepo', defaultValue: '') as String;
    _activeAniyomiAnimeRepo.value =
        _themeBox.get('activeAniyomiAnimeRepo', defaultValue: '') as String;
    _activeAniyomiMangaRepo.value =
        _themeBox.get('activeAniyomiMangaRepo', defaultValue: '') as String;
    _activeCloudStreamAnimeRepo.value =
        _themeBox.get('activeCloudStreamAnimeRepo', defaultValue: '') as String;
    _activeCloudStreamMangaRepo.value =
        _themeBox.get('activeCloudStreamMangaRepo', defaultValue: '') as String;
    _activeCloudStreamNovelRepo.value =
        _themeBox.get('activeCloudStreamNovelRepo', defaultValue: '') as String;
    _activeCloudStreamMovieRepo.value =
        _themeBox.get('activeCloudStreamMovieRepo', defaultValue: '') as String;
    _activeCloudStreamTvRepo.value =
        _themeBox.get('activeCloudStreamTvRepo', defaultValue: '') as String;
    _activeCloudStreamCartoonRepo.value =
        _themeBox.get('activeCloudStreamCartoonRepo', defaultValue: '')
            as String;
    _activeCloudStreamDocumentaryRepo.value =
        _themeBox.get('activeCloudStreamDocumentaryRepo', defaultValue: '')
            as String;
    _activeCloudStreamLivestreamRepo.value =
        _themeBox.get('activeCloudStreamLivestreamRepo', defaultValue: '')
            as String;
    _activeCloudStreamNsfwRepo.value =
        _themeBox.get('activeCloudStreamNsfwRepo', defaultValue: '') as String;
  }

  void _persistRepoSettings() {
    _themeBox
      ..put('activeAnimeRepo', _activeAnimeRepo.value)
      ..put('activeMangaRepo', _activeMangaRepo.value)
      ..put('activeNovelRepo', _activeNovelRepo.value)
      ..put('activeAniyomiAnimeRepo', _activeAniyomiAnimeRepo.value)
      ..put('activeAniyomiMangaRepo', _activeAniyomiMangaRepo.value)
      ..put('activeCloudStreamAnimeRepo', _activeCloudStreamAnimeRepo.value)
      ..put('activeCloudStreamMangaRepo', _activeCloudStreamMangaRepo.value)
      ..put('activeCloudStreamNovelRepo', _activeCloudStreamNovelRepo.value)
      ..put('activeCloudStreamMovieRepo', _activeCloudStreamMovieRepo.value)
      ..put('activeCloudStreamTvRepo', _activeCloudStreamTvRepo.value)
      ..put('activeCloudStreamCartoonRepo', _activeCloudStreamCartoonRepo.value)
      ..put(
        'activeCloudStreamDocumentaryRepo',
        _activeCloudStreamDocumentaryRepo.value,
      )
      ..put(
        'activeCloudStreamLivestreamRepo',
        _activeCloudStreamLivestreamRepo.value,
      )
      ..put('activeCloudStreamNsfwRepo', _activeCloudStreamNsfwRepo.value);
    _updateShouldShowExtensions();
  }

  void _restoreActiveSources() {
    activeAnimeSource.value =
        _firstWhereOrNull(
          _installedAnimeExtensions,
          (s) => s.id == _themeBox.get('activeSourceId'),
        ) ??
        _firstOrNull(_installedAnimeExtensions);
    activeMangaSource.value =
        _firstWhereOrNull(
          _installedMangaExtensions,
          (s) => s.id == _themeBox.get('activeMangaSourceId'),
        ) ??
        _firstOrNull(_installedMangaExtensions);
    activeNovelSource.value =
        _firstWhereOrNull(
          _installedNovelExtensions,
          (s) => s.id == _themeBox.get('activeNovelSourceId'),
        ) ??
        _firstOrNull(_installedNovelExtensions);
  }

  void _updateShouldShowExtensions() {
    final repos = [
      _activeAnimeRepo.value,
      _activeMangaRepo.value,
      _activeNovelRepo.value,
      _activeAniyomiAnimeRepo.value,
      _activeAniyomiMangaRepo.value,
      _activeCloudStreamAnimeRepo.value,
      _activeCloudStreamMangaRepo.value,
      _activeCloudStreamNovelRepo.value,
      _activeCloudStreamMovieRepo.value,
      _activeCloudStreamTvRepo.value,
      _activeCloudStreamCartoonRepo.value,
      _activeCloudStreamDocumentaryRepo.value,
      _activeCloudStreamLivestreamRepo.value,
      _activeCloudStreamNsfwRepo.value,
    ];

    final hasRepoConfigured = repos.any((repo) => repo.isNotEmpty);
    final hasInstalled = _allInstalledSources.isNotEmpty;
    shouldShowExtensions.value = hasRepoConfigured || hasInstalled;
  }

  void _setAnimeRepo(String value, ExtensionType type) {
    if (type == ExtensionType.aniyomi) {
      _activeAniyomiAnimeRepo.value = value;
    } else {
      _activeAnimeRepo.value = value;
    }
    _persistRepoSettings();
  }

  void _setMangaRepo(String value, ExtensionType type) {
    if (type == ExtensionType.aniyomi) {
      _activeAniyomiMangaRepo.value = value;
    } else {
      _activeMangaRepo.value = value;
    }
    _persistRepoSettings();
  }

  void _setNovelRepo(String value) {
    _activeNovelRepo.value = value;
    _persistRepoSettings();
  }

  void _setCloudStreamRepo(domain.ItemType type, String value) {
    switch (type) {
      case domain.ItemType.anime:
        _activeCloudStreamAnimeRepo.value = value;
        break;
      case domain.ItemType.manga:
        _activeCloudStreamMangaRepo.value = value;
        break;
      case domain.ItemType.novel:
        _activeCloudStreamNovelRepo.value = value;
        break;
      case domain.ItemType.movie:
        _activeCloudStreamMovieRepo.value = value;
        break;
      case domain.ItemType.tvShow:
        _activeCloudStreamTvRepo.value = value;
        break;
      case domain.ItemType.cartoon:
        _activeCloudStreamCartoonRepo.value = value;
        break;
      case domain.ItemType.documentary:
        _activeCloudStreamDocumentaryRepo.value = value;
        break;
      case domain.ItemType.livestream:
        _activeCloudStreamLivestreamRepo.value = value;
        break;
      case domain.ItemType.nsfw:
        _activeCloudStreamNsfwRepo.value = value;
        break;
    }
    _persistRepoSettings();
  }

  String _getRepoForType(ExtensionType type, {required bool isAnime}) {
    if (type == ExtensionType.aniyomi) {
      return isAnime
          ? _activeAniyomiAnimeRepo.value
          : _activeAniyomiMangaRepo.value;
    }
    return isAnime ? _activeAnimeRepo.value : _activeMangaRepo.value;
  }

  List<String> _getCloudStreamReposForItem(domain.ItemType itemType) {
    final value = () {
      switch (itemType) {
        case domain.ItemType.anime:
          return _activeCloudStreamAnimeRepo.value;
        case domain.ItemType.manga:
          return _activeCloudStreamMangaRepo.value;
        case domain.ItemType.novel:
          return _activeCloudStreamNovelRepo.value;
        case domain.ItemType.movie:
          return _activeCloudStreamMovieRepo.value;
        case domain.ItemType.tvShow:
          return _activeCloudStreamTvRepo.value;
        case domain.ItemType.cartoon:
          return _activeCloudStreamCartoonRepo.value;
        case domain.ItemType.documentary:
          return _activeCloudStreamDocumentaryRepo.value;
        case domain.ItemType.livestream:
          return _activeCloudStreamLivestreamRepo.value;
        case domain.ItemType.nsfw:
          return _activeCloudStreamNsfwRepo.value;
      }
    }();

    return value.isEmpty ? <String>[] : [value];
  }

  String? _valueOrNull(String value) => value.isEmpty ? null : value;

  domain.ExtensionEntity? _mapSourceToEntity(
    Source source, {
    required bool installed,
  }) {
    final mappedType = _mapBridgeType(source.extensionType);
    final itemType = _mapItemType(source.itemType);
    if (mappedType == null || itemType == null) return null;
    return domain.ExtensionEntity(
      id: source.id ?? '',
      name: source.name ?? 'Unknown',
      version: source.version ?? '0.0.0',
      versionLast: source.versionLast,
      type: mappedType,
      itemType: itemType,
      language: (source.lang ?? 'en').toLowerCase(),
      isInstalled: installed,
      isNsfw: source.isNsfw ?? false,
      hasUpdate: source.hasUpdate ?? false,
      iconUrl: source.iconUrl,
      apkUrl: source.apkUrl,
      description: null,
    );
  }

  List<domain.ExtensionEntity> _mapSourcesToEntities(
    List<Source> sources, {
    required bool installed,
  }) {
    return sources
        .map((source) => _mapSourceToEntity(source, installed: installed))
        .whereType<domain.ExtensionEntity>()
        .toList();
  }

  List<domain.ExtensionEntity> _dedupeExtensions(
    List<domain.ExtensionEntity> extensions,
  ) {
    final seen = <String>{};
    final deduped = <domain.ExtensionEntity>[];
    for (final extension in extensions) {
      final identifier = () {
        final apk = extension.apkUrl;
        if (apk != null && apk.isNotEmpty) return apk;
        if (extension.id.isNotEmpty) return extension.id;
        return '${extension.name}-${extension.version}';
      }();
      final key =
          '${extension.type.name}:${extension.itemType.name}:$identifier';
      if (seen.add(key)) {
        deduped.add(extension);
      }
    }
    return deduped;
  }

  T? _firstWhereOrNull<T>(Iterable<T> items, bool Function(T element) test) {
    for (final item in items) {
      if (test(item)) return item;
    }
    return null;
  }

  T? _firstOrNull<T>(List<T> items) => items.isNotEmpty ? items.first : null;

  void _setOperationMessage(String message, {bool autoClear = false}) {
    operationMessage.value = message;
    if (autoClear) {
      Future.delayed(const Duration(seconds: 2), () {
        if (operationMessage.value == message) {
          operationMessage.value = null;
        }
      });
    }
  }

  domain.ExtensionType? _mapBridgeType(ExtensionType? type) {
    switch (type) {
      case ExtensionType.cloudstream:
        return domain.ExtensionType.cloudstream;
      case ExtensionType.aniyomi:
        return domain.ExtensionType.aniyomi;
      case ExtensionType.mangayomi:
        return domain.ExtensionType.mangayomi;
      case ExtensionType.lnreader:
        return domain.ExtensionType.lnreader;
      case ExtensionType.aniya:
        return domain.ExtensionType.aniya;
      default:
        return null;
    }
  }

  domain.ItemType? _mapItemType(ItemType? itemType) {
    switch (itemType) {
      case ItemType.anime:
        return domain.ItemType.anime;
      case ItemType.manga:
        return domain.ItemType.manga;
      case ItemType.novel:
        return domain.ItemType.novel;
      case ItemType.movie:
        return domain.ItemType.movie;
      case ItemType.tvShow:
        return domain.ItemType.tvShow;
      case ItemType.cartoon:
        return domain.ItemType.cartoon;
      case ItemType.documentary:
        return domain.ItemType.documentary;
      case ItemType.livestream:
        return domain.ItemType.livestream;
      case ItemType.nsfw:
        return domain.ItemType.nsfw;
      default:
        return null;
    }
  }

  ItemType? _mapDomainItemTypeToBridge(domain.ItemType itemType) {
    switch (itemType) {
      case domain.ItemType.anime:
        return ItemType.anime;
      case domain.ItemType.manga:
        return ItemType.manga;
      case domain.ItemType.novel:
        return ItemType.novel;
      case domain.ItemType.movie:
        return ItemType.movie;
      case domain.ItemType.tvShow:
        return ItemType.tvShow;
      case domain.ItemType.cartoon:
        return ItemType.cartoon;
      case domain.ItemType.documentary:
        return ItemType.documentary;
      case domain.ItemType.livestream:
        return ItemType.livestream;
      case domain.ItemType.nsfw:
        return ItemType.nsfw;
    }
  }

  Future<List<Source>> _getInstalledForManager(
    bridge.Extension manager,
    ItemType itemType,
  ) {
    switch (itemType) {
      case ItemType.anime:
        return manager.getInstalledAnimeExtensions();
      case ItemType.manga:
        return manager.getInstalledMangaExtensions();
      case ItemType.novel:
        return manager.getInstalledNovelExtensions();
      case ItemType.movie:
        return manager.getInstalledMovieExtensions();
      case ItemType.tvShow:
        return manager.getInstalledTvShowExtensions();
      case ItemType.cartoon:
        return manager.getInstalledCartoonExtensions();
      case ItemType.documentary:
        return manager.getInstalledDocumentaryExtensions();
      case ItemType.livestream:
        return manager.getInstalledLivestreamExtensions();
      case ItemType.nsfw:
        return manager.getInstalledNsfwExtensions();
    }
  }

  List<Source> _getAvailableForManager(
    bridge.Extension manager,
    ItemType itemType,
  ) {
    switch (itemType) {
      case ItemType.anime:
        return manager.availableAnimeExtensions.value;
      case ItemType.manga:
        return manager.availableMangaExtensions.value;
      case ItemType.novel:
        return manager.availableNovelExtensions.value;
      case ItemType.movie:
        return manager.availableMovieExtensions.value;
      case ItemType.tvShow:
        return manager.availableTvShowExtensions.value;
      case ItemType.cartoon:
        return manager.availableCartoonExtensions.value;
      case ItemType.documentary:
        return manager.availableDocumentaryExtensions.value;
      case ItemType.livestream:
        return manager.availableLivestreamExtensions.value;
      case ItemType.nsfw:
        return manager.availableNsfwExtensions.value;
    }
  }

  String _deriveIdFromUrl(Uri uri) {
    final segment = uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last
        : uri.host;
    return segment.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  }

  String _deriveNameFromUrl(Uri uri) {
    final segment = uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last
        : uri.host;
    return segment.isNotEmpty ? segment : uri.toString();
  }
}
