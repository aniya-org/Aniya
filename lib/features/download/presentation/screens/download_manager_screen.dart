import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/domain/entities/download_entity.dart';
import '../../../../core/services/responsive_layout_manager.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/storage_utils.dart';
import '../viewmodels/download_manager_viewmodel.dart';
import '../widgets/download_item_widget.dart';

/// Download Manager Screen
///
/// Provides a comprehensive UI for managing downloads with:
/// - Tab-based layout (Active, Completed, Failed)
/// - Real-time progress updates
/// - Pause/resume/cancel controls
/// - Storage usage indicator
/// - Batch operations
///
/// Based on Flutter best practices for mobile UI design
/// References: background_downloader package implementation
class DownloadManagerScreen extends StatefulWidget {
  const DownloadManagerScreen({super.key});

  @override
  State<DownloadManagerScreen> createState() => _DownloadManagerScreenState();
}

class _DownloadManagerScreenState extends State<DownloadManagerScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addObserver(this);

    // Initialize after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && _isInitialized) {
      // Refresh when app comes to foreground
      _refresh();
    }
  }

  Future<void> _initialize() async {
    if (!mounted) return;

    setState(() {
      _isInitialized = true;
    });

    // Initialize view model
    final viewModel = context.read<DownloadManagerViewModel>();
    await viewModel.loadDownloads();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    await context.read<DownloadManagerViewModel>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        actions: [
          if (_isInitialized) ...[
            // Clear completed button
            Consumer<DownloadManagerViewModel>(
              builder: (context, viewModel, child) {
                return viewModel.completedDownloads.isNotEmpty
                    ? IconButton(
                        onPressed: () => _showClearCompletedDialog(viewModel),
                        icon: const Icon(Icons.clear_all),
                        tooltip: 'Clear completed',
                      )
                    : const SizedBox.shrink();
              },
            ),
            // Retry failed button
            Consumer<DownloadManagerViewModel>(
              builder: (context, viewModel, child) {
                return viewModel.failedDownloads.isNotEmpty
                    ? IconButton(
                        onPressed: () => _retryFailedDownloads(viewModel),
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Retry all',
                      )
                    : const SizedBox.shrink();
              },
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      body: _isInitialized
          ? Consumer<DownloadManagerViewModel>(
              builder: (context, viewModel, child) {
                if (viewModel.isLoading && viewModel.allDownloads.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (viewModel.error != null) {
                  return _buildErrorState(viewModel.error!, viewModel);
                }

                if (viewModel.allDownloads.isEmpty) {
                  return _buildEmptyState();
                }

                return Column(
                  children: [
                    // Storage indicator
                    _buildStorageIndicator(viewModel),

                    // Tab bar
                    _buildTabBar(viewModel),

                    // Tab content
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildDownloadsList(
                            viewModel.activeDownloads,
                            viewModel,
                          ),
                          _buildDownloadsList(
                            viewModel.completedDownloads,
                            viewModel,
                          ),
                          _buildDownloadsList(
                            viewModel.failedDownloads,
                            viewModel,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildStorageIndicator(DownloadManagerViewModel viewModel) {
    final storage = viewModel.storageUsage;
    final totalSizeMB = (storage['totalBytes'] ?? 0) / (1024 * 1024);
    final downloadedSizeMB = (storage['downloadedBytes'] ?? 0) / (1024 * 1024);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Storage Usage',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                '${downloadedSizeMB.toStringAsFixed(1)} MB / ${totalSizeMB.toStringAsFixed(1)} MB',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: totalSizeMB > 0 ? downloadedSizeMB / totalSizeMB : 0,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(DownloadManagerViewModel viewModel) {
    return TabBar(
      controller: _tabController,
      tabs: [
        Tab(text: 'Active (${viewModel.activeCount})'),
        Tab(text: 'Completed (${viewModel.completedCount})'),
        Tab(text: 'Failed (${viewModel.failedCount})'),
      ],
      labelStyle: Theme.of(context).textTheme.titleSmall,
      unselectedLabelStyle: Theme.of(context).textTheme.bodyMedium,
    );
  }

  Widget _buildDownloadsList(
    List<DownloadEntity> downloads,
    DownloadManagerViewModel viewModel,
  ) {
    if (downloads.isEmpty) {
      return _buildEmptyTabState(_tabController.index);
    }

    final padding = ResponsiveLayoutManager.getPadding(
      MediaQuery.of(context).size.width,
    );

    return RefreshIndicator(
      onRefresh: () => _refresh(),
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: padding.left, vertical: 8),
        itemCount: downloads.length,
        itemBuilder: (context, index) {
          final download = downloads[index];
          return DownloadItemWidget(
            download: download,
            onPause: () => viewModel.pauseDownload(download.id),
            onResume: () => viewModel.resumeDownload(download.id),
            onCancel: () => _showCancelDialog(viewModel, download),
            onDelete: () => _showDeleteDialog(viewModel, download),
            onRetry: () => viewModel.resumeDownload(download.id),
            onTap: () => _handleDownloadTap(download),
          );
        },
      ),
    );
  }

  Widget _buildErrorState(String error, DownloadManagerViewModel viewModel) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading downloads',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => viewModel.refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.download_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No downloads',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Downloaded content will appear here',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyTabState(int tabIndex) {
    String message;
    IconData icon;

    switch (tabIndex) {
      case 0:
        message = 'No active downloads';
        icon = Icons.downloading_outlined;
        break;
      case 1:
        message = 'No completed downloads';
        icon = Icons.check_circle_outline;
        break;
      case 2:
        message = 'No failed downloads';
        icon = Icons.error_outline;
        break;
      default:
        message = 'No downloads';
        icon = Icons.download_outlined;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(message, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }

  void _showCancelDialog(
    DownloadManagerViewModel viewModel,
    DownloadEntity download,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Download'),
        content: Text(
          'Are you sure you want to cancel "${download.mediaTitle}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              viewModel.cancelDownload(download.id);
            },
            child: Text(
              'Cancel',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(
    DownloadManagerViewModel viewModel,
    DownloadEntity download,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Download'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "${download.mediaTitle}"?'),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Delete file from device'),
              value: true,
              onChanged: (value) {
                // Handle checkbox if needed
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              viewModel.deleteDownload(download.id);
            },
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearCompletedDialog(DownloadManagerViewModel viewModel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Completed'),
        content: Text(
          'Remove ${viewModel.completedDownloads.length} completed downloads from the list?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              viewModel.clearCompleted();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _retryFailedDownloads(DownloadManagerViewModel viewModel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retry Failed Downloads'),
        content: Text(
          'Retry all ${viewModel.failedDownloads.length} failed downloads?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              viewModel.retryFailedDownloads();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _handleDownloadTap(DownloadEntity download) {
    if (download.status == DownloadStatus.completed) {
      // Open the downloaded file
      Logger.info(
        'Opening downloaded file: ${download.localPath}',
        tag: 'DownloadManagerScreen',
      );
      StorageUtils.openFile(download.localPath);
    } else if (download.status == DownloadStatus.failed) {
      // Show error details
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed for ${download.mediaTitle}'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () {
              context.read<DownloadManagerViewModel>().resumeDownload(
                download.id,
              );
            },
          ),
        ),
      );
    }
  }
}
