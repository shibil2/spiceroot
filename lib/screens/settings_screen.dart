import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/price_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import 'admin/admin_login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          settings.showMalayalam ? 'Settings | ക്രമീകരണം' : 'Settings',
        ),
      ),
      body: ListView(
        children: [
          _SectionHeader(
            title: settings.showMalayalam ? 'Language / ഭാഷ' : 'Language',
          ),
          SwitchListTile(
            title: const Text('Show Malayalam names'),
            subtitle: Text(
              settings.showMalayalam
                  ? 'English + Malayalam labels'
                  : 'English only',
            ),
            value: settings.showMalayalam,
            activeThumbColor: AppTheme.primaryColor,
            onChanged: settings.setShowMalayalam,
          ),
          const Divider(),
          _SectionHeader(
            title: settings.showMalayalam ? 'Refresh / പുതുക്കൽ' : 'Refresh',
          ),
          ListTile(
            title: const Text('Auto refresh'),
            trailing: DropdownButton<String>(
              value: settings.refreshModeLabel,
              underline: const SizedBox.shrink(),
              items: SettingsProvider.refreshModeLabels
                  .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                  .toList(),
              onChanged: (v) {
                if (v != null) settings.setRefreshModeFromLabel(v);
              },
            ),
          ),
          const Divider(),
          _SectionHeader(
            title: settings.showMalayalam ? 'Notifications' : 'Notifications',
          ),
          SwitchListTile(
            title: const Text('Price alert notifications'),
            subtitle: const Text('Notify when targets are hit'),
            value: settings.notificationsEnabled,
            activeThumbColor: AppTheme.primaryColor,
            onChanged: settings.setNotificationsEnabled,
          ),
          const Divider(),
          _SectionHeader(title: 'About'),
          const ListTile(
            title: Text('Kerala Rate'),
            subtitle: Text('Version v1.0.0'),
          ),
          const ListTile(subtitle: Text('Made for Kerala farmers & traders')),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextButton(
              onPressed: () => _confirmClearCache(context),
              child: const Text(
                'Clear cached data',
                style: TextStyle(color: AppTheme.priceDownColor),
              ),
            ),
          ),
          Center(
            child: TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AdminLoginScreen(),
                  ),
                );
              },
              child: Text(
                'Admin Login',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.stableColor.withValues(alpha: 0.45),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _confirmClearCache(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear cached data?'),
        content: const Text(
          'This removes saved price cache. Live Firestore prices will reload.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (ok == true && context.mounted) {
      await context.read<PriceProvider>().clearCache();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Cache cleared')));
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.stableColor,
        ),
      ),
    );
  }
}
