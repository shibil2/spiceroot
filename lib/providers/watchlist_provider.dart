import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WatchlistProvider extends ChangeNotifier {
  static const String storageKey = 'watchlist_ids';

  final Set<String> _ids = {};
  bool _loaded = false;

  bool get isLoaded => _loaded;
  Set<String> get ids => Set.unmodifiable(_ids);
  int get count => _ids.length;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _ids
      ..clear()
      ..addAll(prefs.getStringList(storageKey) ?? const []);
    _loaded = true;
    notifyListeners();
  }

  bool isWatched(String productId) => _ids.contains(productId);

  Future<void> toggle(String productId) async {
    if (_ids.contains(productId)) {
      _ids.remove(productId);
    } else {
      _ids.add(productId);
    }
    notifyListeners();
    await _persist();
  }

  Future<void> clear() async {
    _ids.clear();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(storageKey, _ids.toList());
  }
}
