import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/domain/entities/entities.dart';
import '../../../../core/widgets/widgets.dart';
import '../viewmodels/media_details_viewmodel.dart';
import '../../../video_player/presentation/screens/video_player_screen.dart';

/// Screen for displaying detailed media information
class MediaDetailsScreen extends StatefulWidget {
  final MediaEntity media;

  const MediaDetailsScreen({super.key, required this.media});

  @override
  State<MediaDetailsScreen> createState() => _MediaDetailsScreenState();
}

class _MediaDetailsScreenState extends State<MediaDetailsScreen> {
  @override
  void initState() {
    super.initState();
    // Load media details when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MediaDetailsViewModel>().loadMediaDetails(
        widget.media.id,
        widget.media.sourceId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<MediaDetailsViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading && viewModel.media == null) {
            return _buildSkeletonScreen(context);
          }

          if (viewModel.error != null && viewModel.media == null) {
            return ErrorView(
              message: viewModel.error!,
              onRetry: () => viewModel.loadMediaDetails(
                widget.media.id,
                widget.media.sourceId,
              ),
            );
          }

          final media = viewModel.media ?? widget.media;

          return CustomScrollView(
            slivers: [
              // App Bar with Banner
              _buildAppBar(context, media),

              // Error message if any
              if (viewModel.error != null)
                SliverToBoxAdapter(
                  child: ErrorMessage(message: viewModel.error!),
                ),

              // Media Info Section
              SliverToBoxAdapter(
                child: _buildMediaInfo(context, media, viewModel),
              ),

              // Episodes/Chapters Section
              if (viewModel.episodes.isNotEmpty)
                _buildEpisodesSection(context, viewModel),
              if (viewModel.chapters.isNotEmpty)
                _buildChaptersSection(context, viewModel),

              // Bottom padding
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, MediaEntity media) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Banner Image
            if (media.bannerImage != null)
              Image.network(
                media.bannerImage!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildBannerPlaceholder(context, media);
                },
              )
            else
              _buildBannerPlaceholder(context, media),

            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    colorScheme.surface.withValues(alpha: 0.8),
                    colorScheme.surface,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerPlaceholder(BuildContext context, MediaEntity media) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          _getTypeIcon(media.type),
          size: 64,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildMediaInfo(
    BuildContext context,
    MediaEntity media,
    MediaDetailsViewModel viewModel,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and Rating
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover Image
              Container(
                width: 100,
                height: 140,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: media.coverImage != null
                    ? Image.network(media.coverImage!, fit: BoxFit.cover)
                    : Container(
                        color: colorScheme.surfaceContainerHighest,
                        child: Icon(
                          _getTypeIcon(media.type),
                          size: 48,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
              ),

              const SizedBox(width: 16),

              // Title and Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      media.title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (media.rating != null)
                      Row(
                        children: [
                          Icon(
                            Icons.star,
                            size: 20,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            media.rating!.toStringAsFixed(1),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      children: [
                        Chip(
                          label: Text(_getTypeLabel(media.type)),
                          visualDensity: VisualDensity.compact,
                        ),
                        Chip(
                          label: Text(_getStatusLabel(media.status)),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Add to Library Button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: viewModel.isInLibrary
                  ? null
                  : () => _showAddToLibraryDialog(context, viewModel),
              icon: Icon(viewModel.isInLibrary ? Icons.check : Icons.add),
              label: Text(
                viewModel.isInLibrary ? 'In Library' : 'Add to Library',
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Synopsis
          if (media.description != null) ...[
            Text(
              'Synopsis',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(media.description!, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
          ],

          // Genres
          if (media.genres.isNotEmpty) ...[
            Text(
              'Genres',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: media.genres.map((genre) {
                return Chip(
                  label: Text(genre),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // Additional Info
          if (media.totalEpisodes != null || media.totalChapters != null) ...[
            Text(
              'Information',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (media.totalEpisodes != null)
              _buildInfoRow(
                context,
                'Episodes',
                media.totalEpisodes.toString(),
              ),
            if (media.totalChapters != null)
              _buildInfoRow(
                context,
                'Chapters',
                media.totalChapters.toString(),
              ),
            _buildInfoRow(context, 'Source', media.sourceName),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodesSection(
    BuildContext context,
    MediaDetailsViewModel viewModel,
  ) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text(
              'Episodes',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: viewModel.episodes.length,
            itemBuilder: (context, index) {
              final episode = viewModel.episodes[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: EpisodeCard(
                  episode: episode,
                  onTap: () => _playEpisode(context, episode),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChaptersSection(
    BuildContext context,
    MediaDetailsViewModel viewModel,
  ) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text(
              'Chapters',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: viewModel.chapters.length,
            itemBuilder: (context, index) {
              final chapter = viewModel.chapters[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(chapter.number.toStringAsFixed(0)),
                  ),
                  title: Text(chapter.title),
                  subtitle: chapter.releaseDate != null
                      ? Text(_formatDate(chapter.releaseDate!))
                      : null,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _readChapter(context, chapter),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAddToLibraryDialog(
    BuildContext context,
    MediaDetailsViewModel viewModel,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add to Library'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: LibraryStatus.values.map((status) {
            return ListTile(
              title: Text(_getLibraryStatusLabel(status)),
              onTap: () {
                viewModel.addMediaToLibrary(status);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _playEpisode(BuildContext context, EpisodeEntity episode) {
    // VideoPlayerScreen automatically loads saved playback position
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(
          episodeId: episode.id,
          sourceId: widget.media.sourceId,
          itemId: widget.media.id,
          episodeNumber: episode.number,
          episodeTitle: episode.title,
        ),
      ),
    );
  }

  void _readChapter(BuildContext context, ChapterEntity chapter) {
    Navigator.pushNamed(context, '/manga-reader', arguments: chapter);
  }

  IconData _getTypeIcon(MediaType type) {
    switch (type) {
      case MediaType.anime:
        return Icons.movie;
      case MediaType.manga:
        return Icons.book;
      case MediaType.movie:
        return Icons.theaters;
      case MediaType.tvShow:
        return Icons.tv;
    }
  }

  String _getTypeLabel(MediaType type) {
    switch (type) {
      case MediaType.anime:
        return 'Anime';
      case MediaType.manga:
        return 'Manga';
      case MediaType.movie:
        return 'Movie';
      case MediaType.tvShow:
        return 'TV Show';
    }
  }

  String _getStatusLabel(MediaStatus status) {
    switch (status) {
      case MediaStatus.ongoing:
        return 'Ongoing';
      case MediaStatus.completed:
        return 'Completed';
      case MediaStatus.upcoming:
        return 'Upcoming';
    }
  }

  String _getLibraryStatusLabel(LibraryStatus status) {
    switch (status) {
      case LibraryStatus.watching:
        return 'Watching';
      case LibraryStatus.currentlyWatching:
        return 'Currently Watching';
      case LibraryStatus.watched:
        return 'Watched';
      case LibraryStatus.completed:
        return 'Completed';
      case LibraryStatus.onHold:
        return 'On Hold';
      case LibraryStatus.dropped:
        return 'Dropped';
      case LibraryStatus.planToWatch:
        return 'Plan to Watch';
      case LibraryStatus.wantToWatch:
        return 'Want to Watch';
      case LibraryStatus.finished:
        return 'Finished';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildSkeletonScreen(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return CustomScrollView(
      slivers: [
        // App Bar with Banner
        SliverAppBar(
          expandedHeight: 300,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: colorScheme.surfaceContainerHighest),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        colorScheme.surface.withValues(alpha: 0.8),
                        colorScheme.surface,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Skeleton content
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover and title skeleton
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerLoading(
                      width: 100,
                      height: 140,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerLoading(
                            width: double.infinity,
                            height: 24,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          const SizedBox(height: 12),
                          ShimmerLoading(
                            width: double.infinity * 0.7,
                            height: 16,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          const SizedBox(height: 12),
                          ShimmerLoading(
                            width: double.infinity * 0.5,
                            height: 16,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Button skeleton
                ShimmerLoading(
                  width: double.infinity,
                  height: 48,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 24),
                // Description skeleton
                ShimmerLoading(
                  width: double.infinity,
                  height: 16,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                ShimmerLoading(
                  width: double.infinity,
                  height: 16,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                ShimmerLoading(
                  width: double.infinity * 0.8,
                  height: 16,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
