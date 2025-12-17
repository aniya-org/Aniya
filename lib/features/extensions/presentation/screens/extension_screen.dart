import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dartotsu_extension_bridge/ExtensionManager.dart' as bridge;
import 'package:dartotsu_extension_bridge/CloudStream/CloudStreamExtensions.dart'
    show CloudStreamExtensionGroup;
import '../../../../core/domain/entities/entities.dart' as domain;
import '../../../../core/services/responsive_layout_manager.dart';
import '../../controllers/extensions_controller.dart';
import '../widgets/extension_details_sheet.dart';
import '../widgets/extension_list.dart';
import '../widgets/repo_settings_sheet.dart';

/// Screen for managing extensions with 8 tabs
///
/// Displays installed and available extensions for Anime, Manga, Novel,
/// and CloudStream categories with tab badges showing extension counts.
///
/// Requirements: 1.1, 1.4, 7.1, 7.2, 7.4, 11.1, 11.2, 12.1, 12.2, 12.3, 12.4
class ExtensionScreen extends StatefulWidget {
  const ExtensionScreen({super.key});

  @override
  State<ExtensionScreen> createState() => _ExtensionScreenState();
}

class _ExtensionScreenState extends State<ExtensionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  late final ExtensionsController _extensionsController;
  bool _isAndroid = false;
  String _selectedLanguage = 'All';
  String _searchQuery = '';
  domain.ItemType? _selectedCloudStreamCategory;
  bridge.ExtensionType? _currentExtensionType;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 10, vsync: this);
    _extensionsController = Get.find<ExtensionsController>();

    // Check if running on Android
    try {
      _isAndroid = Platform.isAndroid;
    } catch (_) {
      _isAndroid = false;
    }

    // Load extensions when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _extensionsController.fetchRepos();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, screenType) {
        return Scaffold(
          body: Obx(() {
            final isLoading = _extensionsController.isInitializing;
            final operationMessage =
                _extensionsController.operationMessage.value;
            final counts = _computeExtensionCounts();
            final progressText =
                operationMessage ??
                (isLoading ? 'Refreshing extensions...' : null);

            final languages = _buildLanguageList();
            if (!languages.contains(_selectedLanguage)) {
              _selectedLanguage = 'All';
            }

            return NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  _buildAppBar(context, innerBoxIsScrolled, counts, languages),
                ];
              },
              body: Column(
                children: [
                  if (progressText != null)
                    _buildProgressIndicator(context, progressText),

                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildExtensionList(
                          installed: true,
                          itemType: domain.ItemType.anime,
                        ),
                        _buildExtensionList(
                          installed: false,
                          itemType: domain.ItemType.anime,
                        ),
                        _buildExtensionList(
                          installed: true,
                          itemType: domain.ItemType.manga,
                        ),
                        _buildExtensionList(
                          installed: false,
                          itemType: domain.ItemType.manga,
                        ),
                        _buildExtensionList(
                          installed: true,
                          itemType: domain.ItemType.novel,
                        ),
                        _buildExtensionList(
                          installed: false,
                          itemType: domain.ItemType.novel,
                        ),
                        _buildCloudStreamExtensionList(installed: true),
                        _buildCloudStreamExtensionList(installed: false),
                        _buildAniyaExtensionList(installed: true),
                        _buildAniyaExtensionList(installed: false),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        );
      },
    );
  }

  /// Builds the app bar with tabs, search, and actions
  Widget _buildAppBar(
    BuildContext context,
    bool innerBoxIsScrolled,
    Map<String, int> counts,
    List<String> languages,
  ) {
    return SliverAppBar(
      title: const Text('Extensions'),
      floating: true,
      pinned: true,
      forceElevated: innerBoxIsScrolled,
      actions: [
        IconButton(
          icon: const Icon(Icons.link),
          tooltip: 'Install CloudStream extension from URL',
          onPressed: () => _showCloudStreamUrlDialog(context),
        ),
        // Update All button (if updates available)
        if (_extensionsController.updatePendingExtensions.isNotEmpty)
          TextButton.icon(
            onPressed: () => _extensionsController.updateAllPendingExtensions(),
            icon: const Icon(Icons.system_update, size: 18),
            label: Text(
              'Update All (${_extensionsController.updatePendingExtensions.length})',
            ),
          ),
        // Repository settings button (Requirement 2.1)
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => _openRepoSettings(context),
          tooltip: 'Repository Settings',
        ),
        // Refresh button
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => _extensionsController.fetchRepos(),
          tooltip: 'Refresh',
        ),
      ],
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(_isAndroid ? 152 : 112),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Extension type selector (Android only) - Requirement 11.1
            if (_isAndroid) _buildExtensionTypeSelector(context),

            // Search bar and language filter - Requirements 7.1, 7.2
            _buildSearchAndFilter(context, languages),

            // Tab bar with 8 tabs - Requirements 1.1, 1.4, 12.1
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                _buildTab('Installed', 'Anime', counts['installedAnime'] ?? 0),
                _buildTab('Available', 'Anime', counts['availableAnime'] ?? 0),
                _buildTab('Installed', 'Manga', counts['installedManga'] ?? 0),
                _buildTab('Available', 'Manga', counts['availableManga'] ?? 0),
                _buildTab('Installed', 'Novel', counts['installedNovel'] ?? 0),
                _buildTab('Available', 'Novel', counts['availableNovel'] ?? 0),
                _buildTab(
                  'Installed',
                  'CloudStream',
                  counts['installedCloudStream'] ?? 0,
                ),
                _buildTab(
                  'Available',
                  'CloudStream',
                  counts['availableCloudStream'] ?? 0,
                ),
                _buildTab('Installed', 'Aniya', counts['installedAniya'] ?? 0),
                _buildTab('Available', 'Aniya', counts['availableAniya'] ?? 0),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a tab with label and count badge (Requirement 1.4)
  Widget _buildTab(String status, String type, int count) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$status $type'),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Builds the extension type selector for Android (Requirement 11.1, 11.2, 12.1)
  Widget _buildExtensionTypeSelector(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Text(
            'Extension Type:',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<bridge.ExtensionType?>(
                  value: _currentExtensionType,
                  icon: const Icon(Icons.arrow_drop_down, size: 20),
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem<bridge.ExtensionType?>(
                      value: null,
                      child: Text('All'),
                    ),
                    DropdownMenuItem<bridge.ExtensionType?>(
                      value: bridge.ExtensionType.mangayomi,
                      child: Text('Mangayomi'),
                    ),
                    DropdownMenuItem<bridge.ExtensionType?>(
                      value: bridge.ExtensionType.aniyomi,
                      child: Text('Aniyomi'),
                    ),
                    DropdownMenuItem<bridge.ExtensionType?>(
                      value: bridge.ExtensionType.lnreader,
                      child: Text('LnReader'),
                    ),
                    DropdownMenuItem<bridge.ExtensionType?>(
                      value: bridge.ExtensionType.cloudstream,
                      child: Text('CloudStream'),
                    ),
                    DropdownMenuItem<bridge.ExtensionType?>(
                      value: bridge.ExtensionType.aniya,
                      child: Text('Aniya'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _currentExtensionType = value;
                    });
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the search bar and language filter (Requirements 7.1, 7.2)
  Widget _buildSearchAndFilter(BuildContext context, List<String> languages) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Search field (Requirement 7.1)
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search extensions...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest,
                ),
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Language filter dropdown (Requirement 7.2)
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedLanguage,
                icon: const Icon(Icons.arrow_drop_down, size: 20),
                items: languages.map((lang) {
                  return DropdownMenuItem(
                    value: lang,
                    child: Text(
                      lang == 'All' ? 'All Languages' : lang.toUpperCase(),
                      style: theme.textTheme.bodyMedium,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedLanguage = value;
                    });
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the extension list for a specific tab
  Widget _buildExtensionList({
    required bool installed,
    required domain.ItemType itemType,
  }) {
    final filteredExtensions = _getFilteredExtensions(
      installed: installed,
      itemType: itemType,
      extensionType: _currentExtensionType,
    );
    final pending = installed
        ? _getFilteredExtensions(
            installed: true,
            itemType: itemType,
            base: _extensionsController.updatePendingExtensions,
          )
        : <domain.ExtensionEntity>[];

    return ExtensionList(
      extensions: filteredExtensions,
      installed: installed,
      itemType: itemType,
      query: _searchQuery,
      selectedLanguage: _selectedLanguage,
      showRecommended: !installed,
      isLoading: _extensionsController.isInitializing,
      updatePendingExtensions: pending,
      onInstall: (extension) =>
          _extensionsController.installExtensionById(extension.id),
      onUninstall: (extension) => _confirmUninstall(context, extension),
      onUpdate: (extension) =>
          _extensionsController.updateExtensionById(extension.id),
      onTap: (extension) => _showExtensionDetails(context, extension),
      isOperationInProgress:
          _extensionsController.operationMessage.value != null,
      installingExtensionId: _extensionsController.installingSourceId.value,
      uninstallingExtensionId: _extensionsController.uninstallingSourceId.value,
    );
  }

  /// Builds the CloudStream extension list (Requirement 12.1, 12.2, 12.3, 12.4)
  ///
  /// CloudStream extensions support multiple content types:
  /// anime, movie, tv_show, cartoon, documentary, livestream
  Widget _buildCloudStreamExtensionList({required bool installed}) {
    final categoryMetrics = _cloudStreamCategoryCounts(installed: installed);
    final selectedType = _selectedCloudStreamCategory;
    final cloudStreamPool =
        (installed
                ? _extensionsController.installedEntities
                : _extensionsController.availableEntities)
            .where((e) => e.type == domain.ExtensionType.cloudstream)
            .toList();
    final cloudStreamExtensions = _getFilteredExtensions(
      installed: installed,
      cloudStreamOnly: true,
      itemType: selectedType,
      extensionType: _currentExtensionType,
      base: cloudStreamPool,
    );
    final dedupedExtensions = _dedupeCloudStreamExtensions(
      cloudStreamExtensions,
    );

    List<domain.ExtensionEntity> updatePendingList =
        const <domain.ExtensionEntity>[];
    if (installed) {
      final filteredPending = _getFilteredExtensions(
        installed: true,
        cloudStreamOnly: true,
        itemType: selectedType,
        extensionType: _currentExtensionType,
        base: _extensionsController.updatePendingExtensions
            .where((e) => e.type == domain.ExtensionType.cloudstream)
            .toList(),
      );
      updatePendingList = _dedupeCloudStreamExtensions(filteredPending);
    }

    final listWidget = ExtensionList(
      extensions: dedupedExtensions,
      installed: installed,
      isLoading: _extensionsController.isInitializing,
      updatePendingExtensions: updatePendingList,
      onInstall: (extension) =>
          _extensionsController.installExtensionById(extension.id),
      onUninstall: (extension) => _confirmUninstall(context, extension),
      onUpdate: (extension) =>
          _extensionsController.updateExtensionById(extension.id),
      onTap: (extension) => _showExtensionDetails(context, extension),
      isOperationInProgress:
          _extensionsController.operationMessage.value != null,
      installingExtensionId: _extensionsController.installingSourceId.value,
      uninstallingExtensionId: _extensionsController.uninstallingSourceId.value,
      shrinkWrap: !installed,
      physics: installed ? null : const NeverScrollableScrollPhysics(),
    );

    // Check if we should show the desktop warning banner
    final showDesktopWarning = _shouldShowDesktopWarningBanner(
      installed: installed,
      extensions: dedupedExtensions,
    );

    if (installed) {
      return Column(
        children: [
          if (showDesktopWarning) _buildDesktopWarningBanner(context),
          _buildCloudStreamCategoryFilter(categoryMetrics),
          Expanded(child: listWidget),
        ],
      );
    }

    final groups = _extensionsController.allCloudStreamGroups;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        if (showDesktopWarning) _buildDesktopWarningBanner(context),
        _buildCloudStreamCategoryFilter(categoryMetrics),
        if (groups.isNotEmpty) _buildCloudStreamGroupSection(context, groups),
        listWidget,
      ],
    );
  }

  /// Whether to show the desktop warning banner.
  bool _shouldShowDesktopWarningBanner({
    required bool installed,
    required List<domain.ExtensionEntity> extensions,
  }) {
    // Only show on desktop platforms
    if (!Platform.isLinux && !Platform.isWindows) return false;

    // Only show for installed extensions tab
    if (!installed) return false;

    // Check if any installed CloudStream extensions are DEX-only
    final hasNonExecutable = extensions.any(
      (e) => e.isExecutableOnDesktop == false,
    );

    return hasNonExecutable;
  }

  /// Builds the desktop warning banner for DEX-only plugins.
  Widget _buildDesktopWarningBanner(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.secondary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: colorScheme.onSecondaryContainer,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Some plugins require Android',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Plugins marked "DEX" contain Android bytecode and cannot run on desktop. '
                  'Look for JS-based plugins or wait for DEX runtime support.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCloudStreamCategoryFilter(_CloudStreamCategoryMetrics metrics) {
    final counts = metrics.perTypeCounts;
    final total = metrics.uniqueCount;
    final chips = <Widget>[
      ChoiceChip(
        label: Text('All ($total)'),
        selected: _selectedCloudStreamCategory == null,
        onSelected: (_) {
          setState(() => _selectedCloudStreamCategory = null);
        },
      ),
    ];

    for (final type in _extensionsController.cloudStreamItemTypes) {
      chips.add(
        ChoiceChip(
          label: Text('${_formatItemTypeLabel(type)} (${counts[type] ?? 0})'),
          selected: _selectedCloudStreamCategory == type,
          onSelected: (_) {
            setState(() => _selectedCloudStreamCategory = type);
          },
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(spacing: 8, children: chips),
    );
  }

  String _formatItemTypeLabel(domain.ItemType type) {
    final raw = type.toString();
    final lastSegment = raw.contains('.') ? raw.split('.').last : raw;
    if (lastSegment.isEmpty) return 'Unknown';
    final spaced = lastSegment
        .replaceAllMapped(RegExp('([A-Z])'), (match) => ' ${match.group(0)}')
        .replaceAll('_', ' ')
        .trim();
    if (spaced.isEmpty) return 'Unknown';
    return spaced[0].toUpperCase() + spaced.substring(1);
  }

  List<domain.ExtensionEntity> _dedupeCloudStreamExtensions(
    List<domain.ExtensionEntity> extensions,
  ) {
    final seen = <String>{};
    final deduped = <domain.ExtensionEntity>[];
    for (final extension in extensions) {
      final identifier = _cloudStreamIdentifier(extension);
      if (seen.add(identifier)) {
        deduped.add(extension);
      }
    }
    return deduped;
  }

  String _cloudStreamIdentifier(domain.ExtensionEntity extension) {
    final apk = extension.apkUrl;
    if (apk != null && apk.isNotEmpty) return apk;
    if (extension.id.isNotEmpty) return extension.id;
    return '${extension.name}-${extension.version}';
  }

  Widget _buildCloudStreamGroupSection(
    BuildContext context,
    List<CloudStreamExtensionGroup> groups,
  ) {
    if (groups.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final bundleMap = <String, _CloudStreamGroupBundle>{};
    for (final group in groups) {
      final key = _CloudStreamGroupBundle.keyFor(group);
      bundleMap.putIfAbsent(
        key,
        () => _CloudStreamGroupBundle(
          id: key,
          name: group.name,
          repoUrl: group.repoUrl,
          pluginListUrl: group.pluginListUrl,
          repoName: group.repoName,
        ),
      );
      bundleMap[key]!.addGroup(group);
    }
    final bundles = bundleMap.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_mosaic, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Extension Groups',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                bundles.length == 1 ? '1 bundle' : '${bundles.length} bundles',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...bundles.map(
            (bundle) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildCloudStreamGroupCard(bundle),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildCloudStreamGroupCard(_CloudStreamGroupBundle bundle) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final installingId = _extensionsController.installingGroupId.value;
    final combinedFailures = bundle.combineFailures(_extensionsController);
    final isInstalling = bundle.isInstalling(installingId);
    final hasFailures = combinedFailures.isNotEmpty;

    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: hasFailures ? 4 : 1,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: hasFailures ? colorScheme.error : colorScheme.outlineVariant,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(bundle.name, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                bundle.repoName ?? Uri.parse(bundle.repoUrl).host,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: const Icon(Icons.extension, size: 16),
                    label: Text('${bundle.pluginCount} plugins'),
                    side: BorderSide.none,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                  ),
                  Chip(
                    avatar: const Icon(Icons.category, size: 16),
                    label: Text(
                      bundle.itemTypeLabels.length == 1
                          ? bundle.itemTypeLabels.first
                          : '${bundle.itemTypeLabels.length} categories',
                    ),
                    side: BorderSide.none,
                    backgroundColor: colorScheme.surfaceContainerLowest,
                  ),
                ],
              ),
              if (bundle.itemTypeLabels.length > 1) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: bundle.itemTypeLabels
                      .map(
                        (label) => Chip(
                          label: Text(label),
                          visualDensity: VisualDensity.compact,
                          side: BorderSide.none,
                        ),
                      )
                      .toList(),
                ),
              ],
              if (combinedFailures.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Failed installs:',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
                const SizedBox(height: 4),
                ...combinedFailures.entries
                    .take(3)
                    .map(
                      (entry) => Text(
                        '• ${entry.key}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.error,
                        ),
                      ),
                    ),
                if (combinedFailures.length > 3)
                  Text(
                    '+${combinedFailures.length - 3} more',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                    ),
                  ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isInstalling
                      ? null
                      : () => _installCloudStreamBundle(bundle),
                  icon: isInstalling
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download),
                  label: Text(isInstalling ? 'Installing...' : 'Install All'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _installCloudStreamBundle(_CloudStreamGroupBundle bundle) async {
    final installed = <String>[];
    final failures = <String, String>{};
    try {
      for (final group in bundle.groups) {
        final result = await _extensionsController.installCloudStreamGroup(
          group,
        );
        installed.addAll(result.installed);
        failures.addAll(result.failures);
      }
      _showBundleResultSnackBar(bundle.name, installed.length, failures);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to install ${bundle.name}: $error')),
      );
    }
  }

  void _showBundleResultSnackBar(
    String bundleName,
    int successCount,
    Map<String, String> failures,
  ) {
    if (!mounted) return;
    final failureCount = failures.length;
    final theme = Theme.of(context);

    final message = failureCount == 0
        ? 'Installed $bundleName ($successCount plugins)'
        : 'Installed $successCount, $failureCount failed in $bundleName';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: theme.textTheme.bodyMedium),
        backgroundColor: failureCount == 0
            ? theme.colorScheme.primary
            : theme.colorScheme.error,
      ),
    );
  }

  /// Builds the progress indicator for installation/update operations
  Widget _buildProgressIndicator(BuildContext context, String message) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      color: colorScheme.primaryContainer,
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Opens the repository settings sheet (Requirement 2.1)
  void _openRepoSettings(BuildContext context) {
    final effectiveType = _effectiveExtensionType();
    final currentConfig = _extensionsController.getRepositoryConfig(
      effectiveType,
    );

    RepoSettingsSheet.show(
      context: context,
      currentConfig: currentConfig,
      currentExtensionType: _mapBridgeTypeToDomain(effectiveType),
      onSave: (type, config) {
        _extensionsController.applyRepositoryConfig(
          _mapDomainTypeToBridge(type),
          config,
        );
      },
      onExtensionTypeChanged: (type) {
        setState(() {
          _currentExtensionType = _mapDomainTypeToBridge(type);
        });
      },
    );
  }

  /// Shows confirmation dialog before uninstalling
  void _confirmUninstall(
    BuildContext context,
    domain.ExtensionEntity extension,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Uninstall Extension'),
        content: Text(
          'Are you sure you want to uninstall "${extension.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              _extensionsController.uninstallExtensionById(extension.id);
              Navigator.pop(context);
            },
            child: const Text('Uninstall'),
          ),
        ],
      ),
    );
  }

  /// Shows extension details in a bottom sheet
  void _showExtensionDetails(
    BuildContext context,
    domain.ExtensionEntity extension,
  ) {
    ExtensionDetailsSheet.show(
      context: context,
      extension: extension,
      onInstall: () => _extensionsController.installExtensionById(extension.id),
      onUninstall: () =>
          _extensionsController.uninstallExtensionById(extension.id),
      onUpdate: () => _extensionsController.updateExtensionById(extension.id),
      isLoading: _extensionsController.operationMessage.value != null,
    );
  }

  List<String> _buildLanguageList() {
    final languages = _extensionsController.availableLanguages.toSet();
    languages.add('All');
    return languages.toList()..sort();
  }

  Map<domain.ItemType, List<domain.ExtensionEntity>> _groupByItemType(
    List<domain.ExtensionEntity> extensions,
  ) {
    final map = <domain.ItemType, List<domain.ExtensionEntity>>{};
    for (final ext in extensions) {
      map.putIfAbsent(ext.itemType, () => []).add(ext);
    }
    return map;
  }

  Map<String, int> _computeExtensionCounts() {
    final installed = _groupByItemType(_extensionsController.installedEntities);
    final available = _groupByItemType(_extensionsController.availableEntities);
    final installedCloud = _dedupeCloudStreamExtensions(
      _extensionsController.installedEntities
          .where((e) => e.type == domain.ExtensionType.cloudstream)
          .toList(),
    ).length;
    final availableCloud = _dedupeCloudStreamExtensions(
      _extensionsController.availableEntities
          .where((e) => e.type == domain.ExtensionType.cloudstream)
          .toList(),
    ).length;
    final installedAniya = _extensionsController.installedEntities
        .where((e) => e.type == domain.ExtensionType.aniya)
        .length;
    final availableAniya = _extensionsController.availableEntities
        .where((e) => e.type == domain.ExtensionType.aniya)
        .length;

    return {
      'installedAnime': installed[domain.ItemType.anime]?.length ?? 0,
      'availableAnime': available[domain.ItemType.anime]?.length ?? 0,
      'installedManga': installed[domain.ItemType.manga]?.length ?? 0,
      'availableManga': available[domain.ItemType.manga]?.length ?? 0,
      'installedNovel': installed[domain.ItemType.novel]?.length ?? 0,
      'availableNovel': available[domain.ItemType.novel]?.length ?? 0,
      'installedCloudStream': installedCloud,
      'availableCloudStream': availableCloud,
      'installedAniya': installedAniya,
      'availableAniya': availableAniya,
    };
  }

  _CloudStreamCategoryMetrics _cloudStreamCategoryCounts({
    required bool installed,
  }) {
    final identifierBuckets = {
      for (final type in _extensionsController.cloudStreamItemTypes)
        type: <String>{},
    };
    final source = installed
        ? _extensionsController.installedEntities
        : _extensionsController.availableEntities;
    final allIdentifiers = <String>{};
    for (final extension in source) {
      if (extension.type != domain.ExtensionType.cloudstream) continue;
      final identifier = _cloudStreamIdentifier(extension);
      allIdentifiers.add(identifier);
      identifierBuckets
          .putIfAbsent(extension.itemType, () => <String>{})
          .add(identifier);
    }
    final perTypeCounts = {
      for (final entry in identifierBuckets.entries)
        entry.key: entry.value.length,
    };
    return _CloudStreamCategoryMetrics(
      perTypeCounts: perTypeCounts,
      uniqueCount: allIdentifiers.length,
    );
  }

  Widget _buildAniyaExtensionList({required bool installed}) {
    final base = installed
        ? _extensionsController.installedEntities
        : _extensionsController.availableEntities;
    final filtered = _getFilteredExtensions(
      installed: installed,
      base: base.where((e) => e.type == domain.ExtensionType.aniya).toList(),
      extensionType: bridge.ExtensionType.aniya,
    );
    return ExtensionList(
      extensions: filtered,
      installed: installed,
      isLoading: _extensionsController.isInitializing,
      onInstall: (extension) =>
          _extensionsController.installExtensionById(extension.id),
      onUninstall: (extension) => _confirmUninstall(context, extension),
      onUpdate: (extension) =>
          _extensionsController.updateExtensionById(extension.id),
      onTap: (extension) => _showExtensionDetails(context, extension),
      isOperationInProgress:
          _extensionsController.operationMessage.value != null,
      installingExtensionId: _extensionsController.installingSourceId.value,
      uninstallingExtensionId: _extensionsController.uninstallingSourceId.value,
    );
  }

  List<domain.ExtensionEntity> _getFilteredExtensions({
    required bool installed,
    domain.ItemType? itemType,
    bool cloudStreamOnly = false,
    bridge.ExtensionType? extensionType,
    List<domain.ExtensionEntity>? base,
  }) {
    final installedList = _extensionsController.installedEntities;
    final availableList = _extensionsController.availableEntities;
    final installedPairs = installedList
        .map((e) => '${e.id}-${e.itemType.name}')
        .toSet();
    final data = base ?? (installed ? installedList : availableList);

    return data.where((extension) {
      final pairKey = '${extension.id}-${extension.itemType.name}';
      if (!installed && installedPairs.contains(pairKey)) {
        return false;
      }
      if (cloudStreamOnly &&
          extension.type != domain.ExtensionType.cloudstream) {
        return false;
      }
      if (itemType != null && extension.itemType != itemType) {
        return false;
      }
      if (extensionType != null &&
          !_matchesExtensionType(extension.type, extensionType)) {
        return false;
      }
      if (_selectedLanguage != 'All' &&
          extension.language.toLowerCase() != _selectedLanguage.toLowerCase()) {
        return false;
      }
      if (_searchQuery.isNotEmpty &&
          !extension.name.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
  }

  bool _matchesExtensionType(
    domain.ExtensionType extensionType,
    bridge.ExtensionType selected,
  ) {
    switch (selected) {
      case bridge.ExtensionType.mangayomi:
        return extensionType == domain.ExtensionType.mangayomi;
      case bridge.ExtensionType.aniyomi:
        return extensionType == domain.ExtensionType.aniyomi;
      case bridge.ExtensionType.cloudstream:
        return extensionType == domain.ExtensionType.cloudstream;
      case bridge.ExtensionType.lnreader:
        return extensionType == domain.ExtensionType.lnreader;
      case bridge.ExtensionType.aniya:
        return extensionType == domain.ExtensionType.aniya;
    }
  }

  bridge.ExtensionType _effectiveExtensionType() {
    return _currentExtensionType ?? bridge.ExtensionType.mangayomi;
  }

  domain.ExtensionType _mapBridgeTypeToDomain(bridge.ExtensionType type) {
    switch (type) {
      case bridge.ExtensionType.mangayomi:
        return domain.ExtensionType.mangayomi;
      case bridge.ExtensionType.aniyomi:
        return domain.ExtensionType.aniyomi;
      case bridge.ExtensionType.cloudstream:
        return domain.ExtensionType.cloudstream;
      case bridge.ExtensionType.lnreader:
        return domain.ExtensionType.lnreader;
      case bridge.ExtensionType.aniya:
        return domain.ExtensionType.aniya;
    }
  }

  bridge.ExtensionType _mapDomainTypeToBridge(domain.ExtensionType type) {
    switch (type) {
      case domain.ExtensionType.mangayomi:
        return bridge.ExtensionType.mangayomi;
      case domain.ExtensionType.aniyomi:
        return bridge.ExtensionType.aniyomi;
      case domain.ExtensionType.cloudstream:
        return bridge.ExtensionType.cloudstream;
      case domain.ExtensionType.lnreader:
        return bridge.ExtensionType.lnreader;
      case domain.ExtensionType.aniya:
        return bridge.ExtensionType.aniya;
    }
  }

  void _showCloudStreamUrlDialog(BuildContext context) {
    final urlController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              title: const Text('Install CloudStream Extension'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: urlController,
                    decoration: const InputDecoration(
                      labelText: 'Extension URL',
                      hintText: 'https://example.com/repo.json',
                    ),
                    keyboardType: TextInputType.url,
                    autofocus: true,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final url = urlController.text.trim();
                    if (url.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a URL.')),
                      );
                      return;
                    }
                    Navigator.of(dialogContext).pop();
                    try {
                      await _extensionsController
                          .installCloudStreamExtensionFromUrl(url);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Install failed: $e')),
                      );
                    }
                  },
                  child: const Text('Install'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _CloudStreamCategoryMetrics {
  const _CloudStreamCategoryMetrics({
    required this.perTypeCounts,
    required this.uniqueCount,
  });

  final Map<domain.ItemType, int> perTypeCounts;
  final int uniqueCount;
}

class _CloudStreamGroupBundle {
  _CloudStreamGroupBundle({
    required this.id,
    required this.name,
    required this.repoUrl,
    required this.pluginListUrl,
    this.repoName,
  });

  final String id;
  final String name;
  final String repoUrl;
  final String pluginListUrl;
  final String? repoName;
  final List<CloudStreamExtensionGroup> groups = [];
  final Set<String> _itemTypeLabels = {};
  int _pluginCount = 0;

  void addGroup(CloudStreamExtensionGroup group) {
    groups.add(group);
    _pluginCount += group.pluginCount;
    _itemTypeLabels.add(_formatItemType(group.itemType));
  }

  int get pluginCount => _pluginCount;

  List<String> get itemTypeLabels => _itemTypeLabels.toList()..sort();

  bool isInstalling(String? installingId) {
    if (installingId == null) return false;
    return groups.any((group) => group.id == installingId);
  }

  Map<String, String> combineFailures(ExtensionsController controller) {
    final failures = <String, String>{};
    for (final group in groups) {
      final status = controller.groupInstallStatus(group.id);
      if (status == null) continue;
      failures.addAll(status.failures);
    }
    return failures;
  }

  static String keyFor(CloudStreamExtensionGroup group) =>
      '${group.repoUrl}:${group.pluginListUrl}';

  static String _formatItemType(dynamic itemType) {
    if (itemType == null) return 'Unknown';
    final raw = itemType.toString();
    final lastSegment = raw.contains('.') ? raw.split('.').last : raw;
    if (lastSegment.isEmpty) return 'Unknown';
    final spaced = lastSegment
        .replaceAllMapped(RegExp('([A-Z])'), (match) => ' ${match.group(0)}')
        .replaceAll('_', ' ')
        .trim();
    if (spaced.isEmpty) return 'Unknown';
    return spaced[0].toUpperCase() + spaced.substring(1);
  }
}
