import 'dart:io';

import 'package:dartotsu_extension_bridge/CloudStream/CloudStreamExtensions.dart';
import 'package:dartotsu_extension_bridge/ExtensionManager.dart';
import 'package:dartotsu_extension_bridge/Models/Source.dart';
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

  final RxList<Source> _installedAnimeExtensions = <Source>[].obs;
  final RxList<Source> _installedMangaExtensions = <Source>[].obs;
  final RxList<Source> _installedNovelExtensions = <Source>[].obs;

  final Rxn<Source> activeAnimeSource = Rxn<Source>();
  final Rxn<Source> activeMangaSource = Rxn<Source>();
  final Rxn<Source> activeNovelSource = Rxn<Source>();

  final RxBool shouldShowExtensions = false.obs;
  final RxnString installingSourceId = RxnString();
  final RxnString uninstallingSourceId = RxnString();
  final RxnString updatingSourceId = RxnString();
  final RxnString operationMessage = RxnString();

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

  final RxBool _isInitializing = false.obs;
  bool get isInitializing => _isInitializing.value;

  @override
  void onInit() {
    super.onInit();
    _restoreRepoSettings();
    _initializeExtensions();
    _ensureDefaultRepos();
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

  Future<void> installCloudStreamExtensionFromUrl(
    String url,
    domain.ItemType itemType,
  ) async {
    final trimmedUrl = url.trim();
    final uri = Uri.tryParse(trimmedUrl);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      throw FormatException('Please enter a valid http(s) URL');
    }

    final bridgeItemType = _mapDomainItemTypeToBridge(itemType);
    final sourceId = _deriveIdFromUrl(uri);
    final sourceName = _deriveNameFromUrl(uri);

    final source = Source(
      id: sourceId,
      name: sourceName,
      extensionType: ExtensionType.cloudstream,
      itemType: bridgeItemType ?? ItemType.anime,
      apkUrl: trimmedUrl,
      lang: 'all',
    );

    installingSourceId.value = source.id;
    _setOperationMessage('Installing $sourceName...');
    try {
      await installSource(source);
      _setOperationMessage('Installed $sourceName', autoClear: true);
    } catch (_) {
      _setOperationMessage('Failed to install $sourceName', autoClear: true);
      rethrow;
    } finally {
      installingSourceId.value = null;
    }
  }

  List<domain.ExtensionEntity> get installedEntities =>
      _mapSourcesToEntities(_allInstalledSources, installed: true);
  List<domain.ExtensionEntity> get availableEntities =>
      _mapSourcesToEntities(_allAvailableSources, installed: false);
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
  ];

  List<Source> get _allAvailableSources => [
    ..._availableAnimeExtensions,
    ..._availableMangaExtensions,
    ..._availableNovelExtensions,
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
    final installedAnime = <Source>[];
    final installedManga = <Source>[];
    final installedNovel = <Source>[];
    final availableAnime = <Source>[];
    final availableManga = <Source>[];
    final availableNovel = <Source>[];

    for (final type in _supportedExtensionTypes) {
      final manager = type.getManager();
      installedAnime.addAll(await manager.getInstalledAnimeExtensions());
      installedManga.addAll(await manager.getInstalledMangaExtensions());
      installedNovel.addAll(await manager.getInstalledNovelExtensions());
      availableAnime.addAll(manager.availableAnimeExtensions.value);
      availableManga.addAll(manager.availableMangaExtensions.value);
      availableNovel.addAll(manager.availableNovelExtensions.value);
    }

    _installedAnimeExtensions.value = installedAnime;
    _installedMangaExtensions.value = installedManga;
    _installedNovelExtensions.value = installedNovel;
    _availableAnimeExtensions.value = availableAnime;
    _availableMangaExtensions.value = availableManga;
    _availableNovelExtensions.value = availableNovel;
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
    shouldShowExtensions.value =
        [
          _activeAnimeRepo.value,
          _activeAniyomiAnimeRepo.value,
          _activeMangaRepo.value,
          _activeAniyomiMangaRepo.value,
          _activeNovelRepo.value,
          _installedAnimeExtensions,
          _installedMangaExtensions,
          _installedNovelExtensions,
        ].any((value) {
          if (value is String) return value.isNotEmpty;
          if (value is List && value.isNotEmpty) return true;
          if (value is RxList && value.isNotEmpty) return true;
          return false;
        });
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
