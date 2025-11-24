import 'package:flutter/material.dart';

/// Settings menu for app bar with options for settings, extensions, and account linking
class AppSettingsMenu extends StatelessWidget {
  final VoidCallback onSettings;
  final VoidCallback onExtensions;
  final VoidCallback onAccountLink;
  final bool showAccountLink;

  const AppSettingsMenu({
    super.key,
    required this.onSettings,
    required this.onExtensions,
    required this.onAccountLink,
    this.showAccountLink = true,
  });

  void _showSettingsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Menu',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                onSettings();
              },
            ),
            ListTile(
              leading: const Icon(Icons.extension),
              title: const Text('Extensions'),
              onTap: () {
                Navigator.pop(context);
                onExtensions();
              },
            ),
            if (showAccountLink)
              ListTile(
                leading: const Icon(Icons.account_circle),
                title: const Text('Link Account'),
                onTap: () {
                  Navigator.pop(context);
                  onAccountLink();
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.more_vert),
      tooltip: 'Menu',
      onPressed: () => _showSettingsBottomSheet(context),
    );
  }
}
