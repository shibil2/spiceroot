import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum RefreshMode { manual, hourly, daily }

class SettingsProvider extends ChangeNotifier {
  static const String keyShowMalayalam = 'show_malayalam';
  static const String keyRefreshMode = 'refresh_mode';
  static const String keyNotifications = 'notifications_enabled';

  bool _showMalayalam = true;
  RefreshMode _refreshMode = RefreshMode.manual;
  bool _notificationsEnabled = true;
  bool _loaded = false;

  bool get isLoaded => _loaded;
  bool get showMalayalam => _showMalayalam;
  RefreshMode get refreshMode => _refreshMode;
  bool get notificationsEnabled => _notificationsEnabled;

  static const List<String> refreshModeLabels = [
    'Manual',
    'Every hour',
    'Daily',
  ];

  String get refreshModeLabel {
    switch (_refreshMode) {
      case RefreshMode.manual:
        return 'Manual';
      case RefreshMode.hourly:
        return 'Every hour';
      case RefreshMode.daily:
        return 'Daily';
    }
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _showMalayalam = prefs.getBool(keyShowMalayalam) ?? true;
    _notificationsEnabled = prefs.getBool(keyNotifications) ?? true;
    final modeIndex = prefs.getInt(keyRefreshMode) ?? 0;
    _refreshMode = RefreshMode.values[modeIndex.clamp(0, 2)];
    _loaded = true;
    notifyListeners();
  }

  Future<void> setShowMalayalam(bool value) async {
    if (_showMalayalam == value) return;
    _showMalayalam = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyShowMalayalam, value);
  }

  Future<void> setRefreshMode(RefreshMode mode) async {
    if (_refreshMode == mode) return;
    _refreshMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyRefreshMode, mode.index);
  }

  Future<void> setRefreshModeFromLabel(String label) async {
    final index = refreshModeLabels.indexOf(label);
    if (index < 0) return;
    await setRefreshMode(RefreshMode.values[index]);
  }

  Future<void> setNotificationsEnabled(bool value) async {
    if (_notificationsEnabled == value) return;
    _notificationsEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyNotifications, value);
  }
}
