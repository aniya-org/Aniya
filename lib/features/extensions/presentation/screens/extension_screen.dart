import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/domain/entities/entities.dart';
import '../../../../core/services/responsive_layout_manager.dart';
import '../../../../core/widgets/widgets.dart';
import '../viewmodels/extension_viewmodel.dart';

/// Screen for managing extensions
class ExtensionScreen extends StatefulWidget {
  const ExtensionScreen({super.key});

  @override
  State<ExtensionScreen> createState() => _ExtensionScreenState();
}

class _ExtensionScreenState extends State<ExtensionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Load extensions when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExtensionViewModel>().loadExtensions();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
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
                  return [
                    // App Bar
                    SliverAppBar(
                      title: const Text('Extensions'),
                      floating: true,
                      pinned: true,
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: () => viewModel.loadExtensions(),
                          tooltip: 'Refresh',
                        ),
                      ],
                      bottom: TabBar(
                        controller: _tabController,
                        tabs: [
                          Tab(
                            text:
                                'Installed (${viewModel.installedExtensions.length})',
                          ),
                          Tab(
                            text:
                                'Available (${viewModel.availableExtensions.length})',
                          ),
                        ],
                      ),
                    ),
                  ];
                },
                body: Column(
                  children: [
                    // Installation Progress
                    if (viewModel.installationProgress != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        color: Theme.of(context).colorScheme.primaryContainer,
                        child: Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                viewModel.installationProgress!,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Error message
                    if (viewModel.error != null)
                      ErrorMessage(message: viewModel.error!),

                    // Tab Content
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // Installed Extensions Tab
                          _buildInstalledTab(context, viewModel),

                          // Available Extensions Tab
                          _buildAvailableTab(context, viewModel),
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

  Widget _buildInstalledTab(
    BuildContext context,
    ExtensionViewModel viewModel,
  ) {
    if (viewModel.isLoading && viewModel.installedExtensions.isEmpty) {
      return _buildSkeletonList(context);
    }

    if (viewModel.installedExtensions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.extension_off,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No extensions installed',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Install extensions to access content',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    // Group by type
    final groupedExtensions = _groupExtensionsByType(
      viewModel.installedExtensions,
    );

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedExtensions.length,
      itemBuilder: (context, index) {
        final type = groupedExtensions.keys.elementAt(index);
        final extensions = groupedExtensions[type]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (index > 0) const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _getTypeLabel(type),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            ...extensions.map((extension) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ExtensionCard(
                  extension: extension,
                  onUninstall: () =>
                      _confirmUninstall(context, extension, viewModel),
                  onTap: () => _showExtensionDetails(context, extension),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildAvailableTab(
    BuildContext context,
    ExtensionViewModel viewModel,
  ) {
    if (viewModel.isLoading && viewModel.availableExtensions.isEmpty) {
      return _buildSkeletonList(context);
    }

    // Filter out already installed extensions
    final installedIds = viewModel.installedExtensions.map((e) => e.id).toSet();
    final availableExtensions = viewModel.availableExtensions
        .where((e) => !installedIds.contains(e.id))
        .toList();

    if (availableExtensions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'All extensions installed',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'You have installed all available extensions',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    // Group by type
    final groupedExtensions = _groupExtensionsByType(availableExtensions);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedExtensions.length,
      itemBuilder: (context, index) {
        final type = groupedExtensions.keys.elementAt(index);
        final extensions = groupedExtensions[type]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (index > 0) const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _getTypeLabel(type),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            ...extensions.map((extension) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ExtensionCard(
                  extension: extension,
                  onInstall: () =>
                      viewModel.install(extension.id, extension.type),
                  onTap: () => _showExtensionDetails(context, extension),
                  isInstalling: viewModel.installationProgress != null,
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Map<ExtensionType, List<ExtensionEntity>> _groupExtensionsByType(
    List<ExtensionEntity> extensions,
  ) {
    final grouped = <ExtensionType, List<ExtensionEntity>>{};
    for (final extension in extensions) {
      grouped.putIfAbsent(extension.type, () => []).add(extension);
    }
    return grouped;
  }

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

  void _showExtensionDetails(BuildContext context, ExtensionEntity extension) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: extension.iconUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            extension.iconUrl!,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Icon(
                          Icons.extension,
                          size: 32,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        extension.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Version ${extension.version}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildDetailRow(context, 'Type', _getTypeLabel(extension.type)),
            _buildDetailRow(
              context,
              'Language',
              extension.language.toUpperCase(),
            ),
            _buildDetailRow(
              context,
              'Status',
              extension.isInstalled ? 'Installed' : 'Not Installed',
            ),
            if (extension.isNsfw) _buildDetailRow(context, 'Content', 'NSFW'),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  String _getTypeLabel(ExtensionType type) {
    switch (type) {
      case ExtensionType.cloudstream:
        return 'CloudStream';
      case ExtensionType.aniyomi:
        return 'Aniyomi';
      case ExtensionType.mangayomi:
        return 'Mangayomi';
      case ExtensionType.lnreader:
        return 'LnReader';
    }
  }

  Widget _buildSkeletonList(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SkeletonListItem(
          height: 80,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
