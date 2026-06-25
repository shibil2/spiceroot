import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/alerts_provider.dart';
import '../providers/price_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import 'alerts_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'watchlist_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _tabs = [
    (icon: Icons.home_outlined, active: Icons.home, label: 'Home'),
    (icon: Icons.bookmark_border, active: Icons.bookmark, label: 'Watchlist'),
    (
      icon: Icons.notifications_outlined,
      active: Icons.notifications,
      label: 'Alerts',
    ),
    (icon: Icons.settings_outlined, active: Icons.settings, label: 'Settings'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeAutoRefresh();
      context.read<PriceProvider>().bindAlerts(context.read<AlertsProvider>());
    });
  }

  Future<void> _maybeAutoRefresh() async {
    final settings = context.read<SettingsProvider>();
    final prices = context.read<PriceProvider>();
    if (prices.shouldAutoRefresh(settings.refreshMode)) {
      await prices.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final alertCount = context.watch<AlertsProvider>().count;

    final screens = const [
      HomeScreen(),
      WatchlistScreen(),
      AlertsScreen(),
      SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        backgroundColor: AppTheme.cardColor,
        indicatorColor: AppTheme.primaryColor.withValues(alpha: 0.15),
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: List.generate(_tabs.length, (i) {
          final tab = _tabs[i];
          final isAlerts = i == 2;
          return NavigationDestination(
            icon: isAlerts && alertCount > 0
                ? Badge(label: Text('$alertCount'), child: Icon(tab.icon))
                : Icon(tab.icon),
            selectedIcon: isAlerts && alertCount > 0
                ? Badge(label: Text('$alertCount'), child: Icon(tab.active))
                : Icon(tab.active),
            label: tab.label,
          );
        }),
      ),
    );
  }
}
