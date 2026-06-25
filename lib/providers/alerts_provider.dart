import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/price_alert_model.dart';

class AlertsProvider extends ChangeNotifier {
  static const String storageKey = 'price_alerts_json';

  final List<PriceAlertModel> _alerts = [];
  bool _loaded = false;

  bool get isLoaded => _loaded;
  List<PriceAlertModel> get alerts => List.unmodifiable(_alerts);
  int get count => _alerts.length;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    _alerts.clear();
    if (raw != null && raw.isNotEmpty) {
      final list = jsonDecode(raw) as List<dynamic>;
      _alerts.addAll(
        list.map((e) => PriceAlertModel.fromJson(e as Map<String, dynamic>)),
      );
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> addAlert(PriceAlertModel alert) async {
    _alerts.add(alert);
    notifyListeners();
    await _persist();
  }

  Future<void> removeAlert(String id) async {
    _alerts.removeWhere((a) => a.id == id);
    notifyListeners();
    await _persist();
  }

  Future<void> clear() async {
    _alerts.clear();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_alerts.map((a) => a.toJson()).toList());
    await prefs.setString(storageKey, encoded);
  }
}
