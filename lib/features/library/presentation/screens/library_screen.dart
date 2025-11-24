import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/domain/entities/entities.dart';
import '../../../../core/services/responsive_layout_manager.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../core/widgets/app_settings_menu.dart';
import '../../../../core/navigation/navigation_controller.dart';
import '../../../../core/navigation/app_navigation.dart';
import '../viewmodels/library_viewmodel.dart';

/// Screen for displaying user's library with filtering and swipe actions
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  @override
  void initState() {
    super.initState();
    // Load library when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LibraryViewModel>().loadLibrary();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, screenType) {
        return Scaffold(
          body: Consumer<LibraryViewModel>(
            builder: (context, viewModel, child) {
              if (viewModel.isLoading && viewModel.libraryItems.isEmpty) {
                return _buildSkeletonScreen(context);
              }

              if (viewModel.error != null && viewModel.libraryItems.isEmpty) {
                return ErrorView(
                  message: viewModel.error!,
                  onRetry: () => viewModel.loadLibrary(),
                );
              }

              return CustomScrollView(
                slivers: [
                  // App Bar
                  SliverAppBar(
                    title: const Text('Library'),
                    floating: true,
                    actions: [
                      // Filter button
                      PopupMenuButton<LibraryStatus?>(
                        icon: Badge(
                          isLabelVisible: viewModel.filterStatus != null,
                          child: const Icon(Icons.filter_list),
                        ),
                        onSelected: (status) =>
                            viewModel.filterByStatus(status),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: null,
                            child: Row(
                              children: [
                                if (viewModel.filterStatus == null)
                                  const Icon(Icons.check, size: 20),
                                if (viewModel.filterStatus == null)
                                  const SizedBox(width: 8),
                                const Text('All'),
                              ],
                            ),
                          ),
                          ...LibraryStatus.values.map((status) {
                            return PopupMenuItem(
                              value: status,
                              child: Row(
                                children: [
                                  if (viewModel.filterStatus == status)
                                    const Icon(Icons.check, size: 20),
                                  if (viewModel.filterStatus == status)
                                    const SizedBox(width: 8),
                                  Text(_getStatusLabel(status)),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                      AppSettingsMenu(
                        onSettings: () {
                          NavigationController.of(
                            context,
                          ).navigateTo(AppDestination.settings);
                        },
                        onExtensions: () {
                          NavigationController.of(
                            context,
                          ).navigateTo(AppDestination.extensions);
                        },
                        onAccountLink: () {
                          NavigationController.of(
                            context,
                          ).navigateTo(AppDestination.settings);
                        },
                      ),
                    ],
                  ),

                  // Error message if any
                  if (viewModel.error != null &&
                      viewModel.libraryItems.isNotEmpty)
                    SliverToBoxAdapter(
                      child: ErrorMessage(message: viewModel.error!),
                    ),

                  // Library Items by Category
                  if (viewModel.libraryItems.isNotEmpty)
                    _buildLibraryContent(context, viewModel, screenType),

                  // Empty state
                  if (viewModel.libraryItems.isEmpty && !viewModel.isLoading)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.library_books_outlined,
                              size: 64,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Your library is empty',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add content to start building your collection',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildLibraryContent(
    BuildContext context,
    LibraryViewModel viewModel,
    ScreenType screenType,
  ) {
    // Group items by status
    final groupedItems = <LibraryStatus, List<LibraryItemEntity>>{};
    for (final item in viewModel.libraryItems) {
      groupedItems.putIfAbsent(item.status, () => []).add(item);
    }

    final padding = ResponsiveLayoutManager.getPadding(
      MediaQuery.of(context).size.width,
    );
    final columnCount = ResponsiveLayoutManager.getGridColumns(
      MediaQuery.of(context).size.width,
    );

    // Build sections for each status
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final statuses = groupedItems.keys.toList();
        if (index >= statuses.length) return null;

        final status = statuses[index];
        final items = groupedItems[status]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            Padding(
              padding: EdgeInsets.fromLTRB(padding.left, 24, padding.right, 12),
              child: Row(
                children: [
                  Text(
                    _getStatusLabel(status),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      items.length.toString(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Items Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: padding.left),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columnCount,
                childAspectRatio: 0.7,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: items.length,
              itemBuilder: (context, itemIndex) {
                final item = items[itemIndex];
                return _buildLibraryItem(context, item, viewModel);
              },
            ),
          ],
        );
      }, childCount: groupedItems.length),
    );
  }

  Widget _buildLibraryItem(
    BuildContext context,
    LibraryItemEntity item,
    LibraryViewModel viewModel,
  ) {
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete, color: Theme.of(context).colorScheme.onError),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Remove from Library'),
            content: Text(
              'Are you sure you want to remove "${item.media.title}" from your library?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Remove'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        viewModel.removeItem(item.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${item.media.title} removed from library')),
        );
      },
      child: GestureDetector(
        onLongPress: () => _showQuickActions(context, item, viewModel),
        child: MediaCard(
          media: item.media,
          onTap: () => _navigateToMediaDetails(context, item.media),
        ),
      ),
    );
  }

  void _showQuickActions(
    BuildContext context,
    LibraryItemEntity item,
    LibraryViewModel viewModel,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.media.title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            Text(
              'Change Status',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ...LibraryStatus.values.map((status) {
              return ListTile(
                leading: Icon(
                  item.status == status
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                ),
                title: Text(_getStatusLabel(status)),
                selected: item.status == status,
                onTap: () {
                  viewModel.updateStatus(item.id, status);
                  Navigator.pop(context);
                },
              );
            }),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'Remove from Library',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                viewModel.removeItem(item.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToMediaDetails(BuildContext context, MediaEntity media) {
    Navigator.pushNamed(context, '/media-details', arguments: media);
  }

  String _getStatusLabel(LibraryStatus status) {
    switch (status) {
      case LibraryStatus.watching:
        return 'Watching';
      case LibraryStatus.completed:
        return 'Completed';
      case LibraryStatus.onHold:
        return 'On Hold';
      case LibraryStatus.dropped:
        return 'Dropped';
      case LibraryStatus.planToWatch:
        return 'Plan to Watch';
    }
  }

  Widget _buildSkeletonScreen(BuildContext context) {
    final columnCount = ResponsiveLayoutManager.getGridColumns(
      MediaQuery.of(context).size.width,
    );

    return CustomScrollView(
      slivers: [
        // App Bar
        const SliverAppBar(title: Text('Library'), floating: true),
        // Skeleton grid
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columnCount,
              childAspectRatio: 0.7,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => const MediaSkeletonCard(),
              childCount: 6,
            ),
          ),
        ),
      ],
    );
  }
}
