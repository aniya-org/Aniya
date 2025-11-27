import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/domain/entities/entities.dart';
import '../../../../core/services/responsive_layout_manager.dart';
import '../../../../core/widgets/widgets.dart';
import '../viewmodels/extension_viewmodel.dart';
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
  bool _isAndroid = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);

    // Check if running on Android
    try {
      _isAndroid = Platform.isAndroid;
    } catch (_) {
      _isAndroid = false;
    }

    // Load extensions when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExtensionViewModel>().loadExtensions();
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
          body: Consumer<ExtensionViewModel>(
            builder: (context, viewModel, child) {
              return NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [_buildAppBar(context, viewModel, innerBoxIsScrolled)];
                },
                body: Column(
                  children: [
                    // Installation Progress
                    if (viewModel.installationProgress != null)
                      _buildProgressIndicator(context, viewModel),

                    // Error message
                    if (viewModel.error != null)
                      ErrorMessage(message: viewModel.error!),

                    // Tab Content
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // Installed Anime Tab
                          _buildExtensionList(
                            context,
                            viewModel,
                            installed: true,
                            itemType: ItemType.anime,
                          ),
                          // Available Anime Tab
                          _buildExtensionList(
                            context,
                            viewModel,
                            installed: false,
                            itemType: ItemType.anime,
                          ),
                          // Installed Manga Tab
                          _buildExtensionList(
                            context,
                            viewModel,
                            installed: true,
                            itemType: ItemType.manga,
                          ),
                          // Available Manga Tab
                          _buildExtensionList(
                            context,
                            viewModel,
                            installed: false,
                            itemType: ItemType.manga,
                          ),
                          // Installed Novel Tab
                          _buildExtensionList(
                            context,
                            viewModel,
                            installed: true,
                            itemType: ItemType.novel,
                          ),
                          // Available Novel Tab
                          _buildExtensionList(
                            context,
                            viewModel,
                            installed: false,
                            itemType: ItemType.novel,
                          ),
                          // Installed CloudStream Tab (Requirement 12.1, 12.2, 12.3, 12.4)
                          _buildCloudStreamExtensionList(
                            context,
                            viewModel,
                            installed: true,
                          ),
                          // Available CloudStream Tab (Requirement 12.1, 12.2, 12.3, 12.4)
                          _buildCloudStreamExtensionList(
                            context,
                            viewModel,
                            installed: false,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// Builds the app bar with tabs, search, and actions
  Widget _buildAppBar(
    BuildContext context,
    ExtensionViewModel viewModel,
    bool innerBoxIsScrolled,
  ) {
    final counts = viewModel.extensionCounts;

    return SliverAppBar(
      title: const Text('Extensions'),
      floating: true,
      pinned: true,
      forceElevated: innerBoxIsScrolled,
      actions: [
        // Update All button (if updates available)
        if (viewModel.updatePendingExtensions.isNotEmpty)
          TextButton.icon(
            onPressed: () => viewModel.updateAll(),
            icon: const Icon(Icons.system_update, size: 18),
            label: Text(
              'Update All (${viewModel.updatePendingExtensions.length})',
            ),
          ),
        // Repository settings button (Requirement 2.1)
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => _openRepoSettings(context, viewModel),
          tooltip: 'Repository Settings',
        ),
        // Refresh button
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => viewModel.loadExtensions(),
          tooltip: 'Refresh',
        ),
      ],
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(_isAndroid ? 152 : 112),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Extension type selector (Android only) - Requirement 11.1
            if (_isAndroid) _buildExtensionTypeSelector(context, viewModel),

            // Search bar and language filter - Requirements 7.1, 7.2
            _buildSearchAndFilter(context, viewModel),

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
  Widget _buildExtensionTypeSelector(
    BuildContext context,
    ExtensionViewModel viewModel,
  ) {
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
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<ExtensionType>(
                segments: const [
                  ButtonSegment(
                    value: ExtensionType.mangayomi,
                    label: Text('Mangayomi'),
                  ),
                  ButtonSegment(
                    value: ExtensionType.aniyomi,
                    label: Text('Aniyomi'),
                  ),
                  ButtonSegment(
                    value: ExtensionType.cloudstream,
                    label: Text('CloudStream'),
                  ),
                ],
                selected: {viewModel.currentExtensionType},
                onSelectionChanged: (selected) {
                  viewModel.setExtensionType(selected.first);
                },
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the search bar and language filter (Requirements 7.1, 7.2)
  Widget _buildSearchAndFilter(
    BuildContext context,
    ExtensionViewModel viewModel,
  ) {
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
                onChanged: viewModel.setSearchQuery,
                decoration: InputDecoration(
                  hintText: 'Search extensions...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: viewModel.searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            viewModel.setSearchQuery('');
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
                value: viewModel.selectedLanguage,
                icon: const Icon(Icons.arrow_drop_down, size: 20),
                items: viewModel.availableLanguages.map((lang) {
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
                    viewModel.setLanguageFilter(value);
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
  Widget _buildExtensionList(
    BuildContext context,
    ExtensionViewModel viewModel, {
    required bool installed,
    required ItemType itemType,
  }) {
    final extensions = installed
        ? viewModel.filteredInstalledExtensions
        : viewModel.filteredAvailableExtensions;

    // Filter by item type and exclude already installed from available
    final filteredExtensions = extensions.where((e) {
      // Filter by item type
      if (e.itemType != itemType) return false;
      // For available list, exclude already installed
      if (!installed) {
        return !viewModel.installedExtensions.any((i) => i.id == e.id);
      }
      return true;
    }).toList();

    return ExtensionList(
      extensions: filteredExtensions,
      installed: installed,
      itemType: itemType,
      query: viewModel.searchQuery,
      selectedLanguage: viewModel.selectedLanguage,
      showRecommended: !installed,
      isLoading: viewModel.isLoading,
      updatePendingExtensions: viewModel.updatePendingExtensions,
      onInstall: (extension) => viewModel.install(extension.id, extension.type),
      onUninstall: (extension) =>
          _confirmUninstall(context, extension, viewModel),
      onUpdate: (extension) => viewModel.update(extension.id),
      onTap: (extension) =>
          _showExtensionDetails(context, extension, viewModel),
      isOperationInProgress: viewModel.installationProgress != null,
      installingExtensionId: viewModel.installingExtensionId,
      uninstallingExtensionId: viewModel.uninstallingExtensionId,
    );
  }

  /// Builds the CloudStream extension list (Requirement 12.1, 12.2, 12.3, 12.4)
  ///
  /// CloudStream extensions support multiple content types:
  /// anime, movie, tv_show, cartoon, documentary, livestream
  Widget _buildCloudStreamExtensionList(
    BuildContext context,
    ExtensionViewModel viewModel, {
    required bool installed,
  }) {
    final extensions = installed
        ? viewModel.filteredInstalledExtensions
        : viewModel.filteredAvailableExtensions;

    // Filter CloudStream extensions (type == cloudstream)
    final cloudStreamExtensions = extensions.where((e) {
      // Check if it's a CloudStream extension
      if (e.type != ExtensionType.cloudstream) return false;
      // For available list, exclude already installed
      if (!installed) {
        return !viewModel.installedExtensions.any((i) => i.id == e.id);
      }
      return true;
    }).toList();

    return ExtensionList(
      extensions: cloudStreamExtensions,
      installed: installed,
      itemType: ItemType.anime, // CloudStream can handle multiple types
      query: viewModel.searchQuery,
      selectedLanguage: viewModel.selectedLanguage,
      showRecommended: !installed,
      isLoading: viewModel.isLoading,
      updatePendingExtensions: viewModel.updatePendingExtensions,
      onInstall: (extension) => viewModel.install(extension.id, extension.type),
      onUninstall: (extension) =>
          _confirmUninstall(context, extension, viewModel),
      onUpdate: (extension) => viewModel.update(extension.id),
      onTap: (extension) =>
          _showExtensionDetails(context, extension, viewModel),
      isOperationInProgress: viewModel.installationProgress != null,
    );
  }

  /// Builds the progress indicator for installation/update operations
  Widget _buildProgressIndicator(
    BuildContext context,
    ExtensionViewModel viewModel,
  ) {
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
              viewModel.installationProgress!,
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
  void _openRepoSettings(BuildContext context, ExtensionViewModel viewModel) {
    final currentConfig =
        viewModel.repositoryConfigs[viewModel.currentExtensionType];

    RepoSettingsSheet.show(
      context: context,
      currentConfig: currentConfig,
      currentExtensionType: viewModel.currentExtensionType,
      onSave: (type, config) {
        viewModel.saveRepository(type, config);
      },
      onExtensionTypeChanged: (type) {
        viewModel.setExtensionType(type);
      },
    );
  }

  /// Shows confirmation dialog before uninstalling
  void _confirmUninstall(
    BuildContext context,
    ExtensionEntity extension,
    ExtensionViewModel viewModel,
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
              viewModel.uninstall(extension.id);
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
    ExtensionEntity extension,
    ExtensionViewModel viewModel,
  ) {
    ExtensionDetailsSheet.show(
      context: context,
      extension: extension,
      onInstall: () => viewModel.install(extension.id, extension.type),
      onUninstall: () => viewModel.uninstall(extension.id),
      onUpdate: () => viewModel.update(extension.id),
      isLoading: viewModel.installationProgress != null,
    );
  }
}
