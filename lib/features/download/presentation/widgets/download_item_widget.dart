import 'package:flutter/material.dart';

import '../../../../core/domain/entities/download_entity.dart';
import '../../../../core/utils/storage_utils.dart';

/// Individual download item widget with progress indicator and controls
/// Based on Material Design 3 guidelines for list items
/// References: background_downloader package UI patterns
class DownloadItemWidget extends StatelessWidget {
  final DownloadEntity download;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onCancel;
  final VoidCallback? onDelete;
  final VoidCallback? onRetry;
  final VoidCallback? onTap;

  const DownloadItemWidget({
    super.key,
    required this.download,
    this.onPause,
    this.onResume,
    this.onCancel,
    this.onDelete,
    this.onRetry,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title and subtitle
              _buildTitleSection(context),
              const SizedBox(height: 12),

              // Progress section
              if (_showProgress) ...[
                _buildProgressSection(context),
                const SizedBox(height: 12),
              ],

              // Bottom row with info and actions
              _buildBottomSection(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleSection(BuildContext context) {
    String title = download.mediaTitle;
    String subtitle = '';

    // Add episode/chapter info if available
    if (download.episodeNumber != null) {
      subtitle = 'Episode ${download.episodeNumber}';
    } else if (download.chapterNumber != null) {
      subtitle = 'Chapter ${download.chapterNumber}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            _buildStatusChip(context),
          ],
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusChip(BuildContext context) {
    Color color;
    String label;
    IconData icon;

    switch (download.status) {
      case DownloadStatus.queued:
        color = Theme.of(context).colorScheme.primary;
        label = 'Queued';
        icon = Icons.schedule;
        break;
      case DownloadStatus.downloading:
        color = Theme.of(context).colorScheme.primary;
        label = 'Downloading';
        icon = Icons.downloading;
        break;
      case DownloadStatus.paused:
        color = Theme.of(context).colorScheme.secondary;
        label = 'Paused';
        icon = Icons.pause;
        break;
      case DownloadStatus.completed:
        color = Colors.green;
        label = 'Completed';
        icon = Icons.check_circle;
        break;
      case DownloadStatus.failed:
        color = Theme.of(context).colorScheme.error;
        label = 'Failed';
        icon = Icons.error;
        break;
      case DownloadStatus.cancelled:
        color = Theme.of(context).colorScheme.outline;
        label = 'Cancelled';
        icon = Icons.cancel;
        break;
    }

    return Chip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide(color: color.withOpacity(0.3)),
    );
  }

  Widget _buildProgressSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress bar
        LinearProgressIndicator(
          value: download.progress.clamp(0.0, 1.0),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          valueColor: AlwaysStoppedAnimation<Color>(
            _getProgressColor(context),
          ),
        ),
        const SizedBox(height: 8),

        // Progress text
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${(download.progress * 100).toInt()}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (download.totalBytes > 0)
              Text(
                '${StorageUtils.formatBytes(download.downloadedBytes)} / ${StorageUtils.formatBytes(download.totalBytes)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomSection(BuildContext context) {
    return Row(
      children: [
        // Left side - File info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (download.totalBytes > 0)
                Text(
                  StorageUtils.formatBytes(download.totalBytes),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (download.completedAt != null)
                Text(
                  'Completed ${_formatDate(download.completedAt!)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),

        // Right side - Action buttons
        Row(
          mainAxisSize: MainAxisSize.min,
          children: _buildActionButtons(context),
        ),
      ],
    );
  }

  List<Widget> _buildActionButtons(BuildContext context) {
    List<Widget> buttons = [];

    switch (download.status) {
      case DownloadStatus.queued:
      case DownloadStatus.downloading:
        buttons.add(
          IconButton(
            onPressed: onPause,
            icon: const Icon(Icons.pause),
            tooltip: 'Pause',
          ),
        );
        buttons.add(
          IconButton(
            onPressed: onCancel,
            icon: const Icon(Icons.cancel),
            tooltip: 'Cancel',
          ),
        );
        break;

      case DownloadStatus.paused:
        buttons.add(
          IconButton(
            onPressed: onResume,
            icon: const Icon(Icons.play_arrow),
            tooltip: 'Resume',
          ),
        );
        buttons.add(
          IconButton(
            onPressed: onCancel,
            icon: const Icon(Icons.cancel),
            tooltip: 'Cancel',
          ),
        );
        break;

      case DownloadStatus.completed:
        buttons.add(
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
          ),
        );
        break;

      case DownloadStatus.failed:
      case DownloadStatus.cancelled:
        buttons.add(
          IconButton(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            tooltip: 'Retry',
          ),
        );
        buttons.add(
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
          ),
        );
        break;
    }

    return buttons;
  }

  Color _getProgressColor(BuildContext context) {
    if (download.status == DownloadStatus.failed) {
      return Theme.of(context).colorScheme.error;
    } else if (download.status == DownloadStatus.paused) {
      return Theme.of(context).colorScheme.secondary;
    }
    return Theme.of(context).colorScheme.primary;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} min${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  bool get _showProgress {
    return download.status == DownloadStatus.queued ||
           download.status == DownloadStatus.downloading ||
           download.status == DownloadStatus.paused;
  }
}