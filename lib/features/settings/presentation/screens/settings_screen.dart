import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aniya/core/di/injection_container.dart';
import 'package:aniya/core/theme/theme.dart';
import 'package:aniya/core/services/responsive_layout_manager.dart';
import 'package:aniya/core/enums/tracking_service.dart';
import '../viewmodels/settings_viewmodel.dart';

class SettingsScreen extends StatefulWidget {
  final TrackingService? highlightedService;

  const SettingsScreen({super.key, this.highlightedService});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = sl<SettingsViewModel>();
    // Load settings only once when the screen is initialized
    _viewModel.loadSettings();
    _viewModel.addListener(_onErrorChanged);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onErrorChanged);
    super.dispose();
  }

  void _onErrorChanged() {
    if (_viewModel.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_viewModel.error!),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: _SettingsContent(highlightedService: widget.highlightedService),
    );
  }
}

class _SettingsContent extends StatefulWidget {
  final TrackingService? highlightedService;

  const _SettingsContent({this.highlightedService});

  @override
  State<_SettingsContent> createState() => _SettingsContentState();
}

class _SettingsContentState extends State<_SettingsContent> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _trackingSectionKey = GlobalKey();
  bool _hasScrolledToHighlight = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeScrollToTracking();
  }

  void _maybeScrollToTracking() {
    if (_hasScrolledToHighlight || widget.highlightedService == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final context = _trackingSectionKey.currentContext;
      if (context != null) {
        _hasScrolledToHighlight = true;
        await Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<SettingsViewModel>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final padding = ResponsiveLayoutManager.getPadding(
      MediaQuery.of(context).size.width,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), centerTitle: false),
      body: ListView(
        controller: _scrollController,
        children: [
          _buildSectionHeader(context, 'Appearance', padding),
          _buildThemeSelector(context, viewModel, themeProvider),
          const Divider(),
          _buildSectionHeader(context, 'Playback', padding),
          _buildPlaybackSettings(context, viewModel),
          const Divider(),
          _buildSectionHeader(context, 'Extensions', padding),
          _buildExtensionSettings(context, viewModel),
          const Divider(),
          _buildSectionHeader(
            context,
            'Tracking & Accounts',
            padding,
            key: _trackingSectionKey,
          ),
          _buildTrackingSettings(
            context,
            viewModel,
            highlightService: widget.highlightedService,
          ),
          const Divider(),
          _buildSectionHeader(context, 'Cache Management', padding),
          _buildCacheManagement(context, viewModel),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    EdgeInsets padding, {
    Key? key,
  }) {
    return Padding(
      key: key,
      padding: EdgeInsets.fromLTRB(
        padding.left + 16,
        16,
        padding.right + 16,
        8,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildThemeSelector(
    BuildContext context,
    SettingsViewModel viewModel,
    ThemeProvider themeProvider,
  ) {
    return Column(
      children: [
        RadioListTile<AppThemeMode>(
          title: const Text('Light'),
          subtitle: const Text('Light theme'),
          value: AppThemeMode.light,
          groupValue: themeProvider.themeMode,
          onChanged: (value) {
            if (value != null) {
              themeProvider.setThemeMode(value);
              viewModel.setThemeMode(value);
            }
          },
        ),
        RadioListTile<AppThemeMode>(
          title: const Text('Dark'),
          subtitle: const Text('Dark theme'),
          value: AppThemeMode.dark,
          groupValue: themeProvider.themeMode,
          onChanged: (value) {
            if (value != null) {
              themeProvider.setThemeMode(value);
              viewModel.setThemeMode(value);
            }
          },
        ),
        RadioListTile<AppThemeMode>(
          title: const Text('OLED'),
          subtitle: const Text('Pure black for OLED screens'),
          value: AppThemeMode.oled,
          groupValue: themeProvider.themeMode,
          onChanged: (value) {
            if (value != null) {
              themeProvider.setThemeMode(value);
              viewModel.setThemeMode(value);
            }
          },
        ),
        RadioListTile<AppThemeMode>(
          title: const Text('System'),
          subtitle: const Text('Follow system settings'),
          value: AppThemeMode.system,
          groupValue: themeProvider.themeMode,
          onChanged: (value) {
            if (value != null) {
              themeProvider.setThemeMode(value);
              viewModel.setThemeMode(value);
            }
          },
        ),
      ],
    );
  }

  Widget _buildPlaybackSettings(
    BuildContext context,
    SettingsViewModel viewModel,
  ) {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Auto-play next episode'),
          subtitle: const Text(
            'Automatically play the next episode when the current one ends',
          ),
          value: viewModel.autoPlayNextEpisode,
          onChanged: (value) => viewModel.setAutoPlayNextEpisode(value),
        ),
        ListTile(
          title: const Text('Default Quality'),
          subtitle: Text(viewModel.defaultVideoQuality.name.toUpperCase()),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            // Show quality selector dialog
          },
        ),
      ],
    );
  }

  Widget _buildExtensionSettings(
    BuildContext context,
    SettingsViewModel viewModel,
  ) {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Show NSFW Extensions'),
          subtitle: const Text('Include 18+ extensions in the list'),
          value: viewModel.showNsfwExtensions,
          onChanged: (value) => viewModel.setShowNsfwExtensions(value),
        ),
      ],
    );
  }

  Widget _buildTrackingSettings(
    BuildContext context,
    SettingsViewModel viewModel, {
    TrackingService? highlightService,
  }) {
    return Column(
      children: [
        _buildTrackingTile(
          context,
          viewModel,
          TrackingService.anilist,
          'AniList',
          Icons.analytics_outlined,
          isHighlighted: highlightService == TrackingService.anilist,
        ),
        _buildTrackingTile(
          context,
          viewModel,
          TrackingService.mal,
          'MyAnimeList',
          Icons.list_alt,
          isHighlighted: highlightService == TrackingService.mal,
        ),
        _buildTrackingTile(
          context,
          viewModel,
          TrackingService.simkl,
          'Simkl',
          Icons.tv,
          isHighlighted: highlightService == TrackingService.simkl,
        ),
      ],
    );
  }

  Widget _buildTrackingTile(
    BuildContext context,
    SettingsViewModel viewModel,
    TrackingService service,
    String name,
    IconData icon, {
    bool isHighlighted = false,
  }) {
    final isConnected = viewModel.isTrackingServiceConnected(service);

    final highlightColor = Theme.of(context).colorScheme.tertiaryContainer;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isHighlighted ? highlightColor : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isConnected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Icon(
            icon,
            color: isConnected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        title: Text(name),
        subtitle: Text(isConnected ? 'Connected as User' : 'Not connected'),
        trailing: Tooltip(
          message: isHighlighted
              ? 'Connect $name to continue'
              : (isConnected ? 'Disconnect' : 'Connect'),
          child: FilledButton.tonal(
            onPressed: () {
              if (isConnected) {
                _showDisconnectDialog(context, service, viewModel, name);
              } else {
                viewModel.connectTrackingService(service);
              }
            },
            child: Text(isConnected ? 'Disconnect' : 'Connect'),
          ),
        ),
      ),
    );
  }

  void _showDisconnectDialog(
    BuildContext context,
    TrackingService service,
    SettingsViewModel viewModel,
    String serviceName,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Disconnect $serviceName?'),
        content: Text('Are you sure you want to disconnect from $serviceName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              viewModel.disconnectTrackingService(service);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Disconnected from $serviceName')),
              );
            },
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }

  Widget _buildCacheManagement(
    BuildContext context,
    SettingsViewModel viewModel,
  ) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.storage),
          title: const Text('Provider Cache'),
          subtitle: viewModel.isLoadingCacheStats
              ? const Text('Loading...')
              : Text(
                  '${viewModel.cacheEntryCount} entries • ${viewModel.getFormattedCacheSize()}',
                ),
          trailing: IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => viewModel.loadCacheStatistics(),
            tooltip: 'Refresh statistics',
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'Provider cache stores cross-provider media mappings to speed up loading. '
            'Cache entries expire after 7 days.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: FilledButton.tonal(
            onPressed: viewModel.cacheEntryCount > 0
                ? () => _showClearCacheDialog(context, viewModel)
                : null,
            child: const Text('Clear Cache'),
          ),
        ),
      ],
    );
  }

  void _showClearCacheDialog(
    BuildContext context,
    SettingsViewModel viewModel,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Provider Cache?'),
        content: Text(
          'This will remove ${viewModel.cacheEntryCount} cached provider mappings. '
          'Media details will need to be fetched again from all providers.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await viewModel.clearProviderCache();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cache cleared successfully')),
                );
              }
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
