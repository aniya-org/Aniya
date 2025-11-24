import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aniya/core/di/injection_container.dart';
import 'package:aniya/core/theme/theme.dart';
import 'package:aniya/core/services/responsive_layout_manager.dart';
import 'package:aniya/core/enums/tracking_service.dart';
import '../viewmodels/settings_viewmodel.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

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
      child: const _SettingsContent(),
    );
  }
}

class _SettingsContent extends StatelessWidget {
  const _SettingsContent();

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<SettingsViewModel>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final padding = ResponsiveLayoutManager.getPadding(
      MediaQuery.of(context).size.width,
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(
            title: Text('Settings'),
            floating: true,
            pinned: true,
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              _buildSectionHeader(context, 'Appearance', padding),
              _buildThemeSelector(context, viewModel, themeProvider),
              const Divider(),
              _buildSectionHeader(context, 'Playback', padding),
              _buildPlaybackSettings(context, viewModel),
              const Divider(),
              _buildSectionHeader(context, 'Extensions', padding),
              _buildExtensionSettings(context, viewModel),
              const Divider(),
              _buildSectionHeader(context, 'Tracking & Accounts', padding),
              _buildTrackingSettings(context, viewModel),
              const SizedBox(height: 50),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    EdgeInsets padding,
  ) {
    return Padding(
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
    SettingsViewModel viewModel,
  ) {
    return Column(
      children: [
        _buildTrackingTile(
          context,
          viewModel,
          TrackingService.anilist,
          'AniList',
          Icons.analytics_outlined,
        ),
        _buildTrackingTile(
          context,
          viewModel,
          TrackingService.mal,
          'MyAnimeList',
          Icons.list_alt,
        ),
        _buildTrackingTile(
          context,
          viewModel,
          TrackingService.simkl,
          'Simkl',
          Icons.tv,
        ),
      ],
    );
  }

  Widget _buildTrackingTile(
    BuildContext context,
    SettingsViewModel viewModel,
    TrackingService service,
    String name,
    IconData icon,
  ) {
    final isConnected = viewModel.isTrackingServiceConnected(service);

    return ListTile(
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
      trailing: FilledButton.tonal(
        onPressed: () {
          if (isConnected) {
            _showDisconnectDialog(context, service, viewModel, name);
          } else {
            viewModel.connectTrackingService(service);
          }
        },
        child: Text(isConnected ? 'Disconnect' : 'Connect'),
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
}
