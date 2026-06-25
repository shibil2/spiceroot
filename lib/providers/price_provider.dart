// lib/providers/price_provider.dart
//
// PriceProvider is now source-agnostic.
// Inject a FirestorePriceService or ExternalPriceService at startup — the
// caching, alerting, and UI-facing API are identical either way.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spiceroot/data/models/price_alert_model.dart';

import '../data/models/product_model.dart';
import '../providers/alerts_provider.dart';
import '../providers/settings_provider.dart';
import '../services/price_data_source.dart';

const _kCacheKey = 'price_cache_v2';
const _kCacheTimestampKey = 'price_cache_ts_v2';
const _kCacheTtlMinutes = 60;

enum MarketMood { up, down, stable }

class PriceProvider extends ChangeNotifier {
  PriceProvider(this._source) {
    _init();
  }

  final PriceDataSource _source;
  bool _loaded = false;
  AlertsProvider? _alertsProvider;
  VoidCallback? _alertsListener;

  bool get isLoaded => _loaded;

  // ─── Public state ─────────────────────────────────────────────────────────

  static const List<String> filterLabels = [
    'All',
    'Arecanut',
    'Pepper',
    'Spices',
    'Rubber',
    'Coconut',
  ];

  List<ProductModel> get products => List.unmodifiable(_products);
  List<ProductModel> get allProducts => List.unmodifiable(_products);
  List<ProductModel> get filteredProducts {
    final query = _searchQuery.trim().toLowerCase();
    return _products.where((p) {
      if (!_matchesFilter(p, _activeFilter)) return false;
      if (query.isEmpty) return true;
      return p.nameEn.toLowerCase().contains(query) ||
          p.nameMl.toLowerCase().contains(query) ||
          p.district.toLowerCase().contains(query);
    }).toList();
  }

  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  bool get isOffline => _isOffline;
  bool get hasError => _errorMessage != null && _errorMessage!.isNotEmpty;
  String get errorMessage => _errorMessage ?? '';
  String get activeFilter => _activeFilter;
  String get marketMessage => _marketMessage;
  DateTime? get lastRefreshed => _lastRefreshed;
  MarketMood get marketMood {
    final avg = _averageChangePct;
    if (avg > 1) return MarketMood.up;
    if (avg < -1) return MarketMood.down;
    return MarketMood.stable;
  }

  String get lastUpdatedLabel {
    if (_lastRefreshed == null) return 'never';
    final mins = DateTime.now().difference(_lastRefreshed!).inMinutes;
    if (mins <= 0) return 'just now';
    if (mins == 1) return '1 min ago';
    return '$mins mins ago';
  }

  String get statusLabel {
    if (_isOffline) {
      return 'Offline — cached prices · Last updated $lastUpdatedLabel';
    }
    return 'Last updated: $lastUpdatedLabel';
  }

  bool _matchesFilter(ProductModel product, String filter) {
    switch (filter) {
      case 'All':
        return true;
      case 'Arecanut':
        return product.id == 'arecanut';
      case 'Pepper':
        return product.id == 'black_pepper';
      case 'Spices':
        return const {
          'cardamom',
          'nutmeg',
          'cloves',
          'turmeric',
          'ginger_dry',
        }.contains(product.id);
      case 'Rubber':
        return product.id == 'rubber_rss4';
      case 'Coconut':
        return product.id == 'coconut';
      default:
        return true;
    }
  }

  // ─── Private state ────────────────────────────────────────────────────────

  final List<ProductModel> _products = [];
  String _activeFilter = 'All';
  String _searchQuery = '';
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _isOffline = false;
  String _marketMessage = '';
  String? _errorMessage;
  DateTime? _lastRefreshed;
  StreamSubscription<List<ProductModel>>? _subscription;
  final List<_AlertRule> _alertRules = [];

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  Future<void> _init() async {
    await _loadCacheFromPrefs(); // show stale data immediately
    _subscribe(); // then stream live updates
    await refresh(); // and fetch fresh data right now
    _loaded = true;
    notifyListeners();
  }

  void _subscribe() {
    _subscription = _source.watchAllProducts().listen(
      (products) {
        _mergeAndAlert(products);
      },
      onError: (Object error) {
        _errorMessage = error.toString();
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    if (_alertsProvider != null && _alertsListener != null) {
      _alertsProvider!.removeListener(_alertsListener!);
    }
    _source.dispose();
    super.dispose();
  }

  // ─── Public API ───────────────────────────────────────────────────────────

  /// Manual pull-to-refresh.
  Future<bool> refresh() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final products = await _source.fetchAllProducts();
      _mergeAndAlert(products);
      await _saveCache(products);
      _lastRefreshed = DateTime.now();
      _isOffline = false;
      return true;
    } catch (e) {
      _errorMessage = 'Failed to load prices: $e';
      _isOffline = true;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> goOffline() async {
    _isOffline = true;
    _marketMessage = 'Offline mode enabled';
    notifyListeners();
  }

  void setFilter(String filter) {
    if (_activeFilter == filter) return;
    _activeFilter = filter;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    notifyListeners();
  }

  /// Fetch detail for a single product (e.g. when opening a product page).
  Future<ProductModel?> getProduct(String productId) async {
    try {
      return await _source.fetchProduct(productId);
    } catch (e) {
      debugPrint('getProduct error: $e');
      for (final p in _products) {
        if (p.id == productId) return p;
      }
      return null;
    }
  }

  /// Lookup a loaded product by its ID for UI consumers.
  ProductModel? productById(String productId) {
    for (final product in _products) {
      if (product.id == productId) return product;
    }
    return null;
  }

  /// Register a price-threshold alert.
  /// [onTrigger] is called on the UI isolate whenever [productId]'s price
  /// crosses [targetPrice] in the direction specified by [above].
  void addAlert({
    required String productId,
    required double targetPrice,
    required bool above,
    required void Function(ProductModel product) onTrigger,
  }) {
    _alertRules.add(
      _AlertRule(
        productId: productId,
        targetPrice: targetPrice,
        above: above,
        onTrigger: onTrigger,
      ),
    );
  }

  void removeAlert(String productId) =>
      _alertRules.removeWhere((r) => r.productId == productId);

  void bindAlerts(AlertsProvider alertsProvider) {
    if (_alertsProvider == alertsProvider) return;
    if (_alertsProvider != null && _alertsListener != null) {
      _alertsProvider!.removeListener(_alertsListener!);
    }
    _alertsProvider = alertsProvider;
    _alertsListener = () => _syncAlerts(alertsProvider.alerts);
    alertsProvider.addListener(_alertsListener!);
    _syncAlerts(alertsProvider.alerts);
  }

  void _syncAlerts(List<PriceAlertModel> alerts) {
    _alertRules.clear();
    for (final alert in alerts) {
      addAlert(
        productId: alert.productId,
        targetPrice: alert.targetPrice,
        above: alert.alertAbove,
        onTrigger: (_) {},
      );
    }
  }

  bool shouldAutoRefresh(RefreshMode mode) {
    if (mode == RefreshMode.manual) return false;
    final last = _lastRefreshed;
    if (last == null) return true;
    final diff = DateTime.now().difference(last);
    if (mode == RefreshMode.hourly) {
      return diff.inMinutes >= 60;
    }
    return diff.inHours >= 24;
  }

  // ─── Price history (delegated to source) ─────────────────────────────────

  Future<List<PricePoint>> fetchPriceHistory(
    String productId, {
    DateTime? from,
    DateTime? to,
  }) => _source.fetchPriceHistory(productId, from: from, to: to);

  // ─── Caching ──────────────────────────────────────────────────────────────

  Future<void> _saveCache(List<ProductModel> products) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = json.encode(
        products.map((p) => p.toCacheJson()).toList(),
      );
      await prefs.setString(_kCacheKey, encoded);
      await prefs.setString(
        _kCacheTimestampKey,
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      debugPrint('Cache write error: $e');
    }
  }

  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kCacheKey);
      await prefs.remove(_kCacheTimestampKey);
      _products.clear();
      _lastRefreshed = null;
      _isOffline = false;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Cache clear error: $e');
    }
  }

  Future<void> _loadCacheFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCacheKey);
      final tsRaw = prefs.getString(_kCacheTimestampKey);
      if (raw == null) return;

      // Treat cache as stale after TTL but still show it rather than nothing.
      final ts = tsRaw != null ? DateTime.tryParse(tsRaw) : null;
      final isStale =
          ts == null ||
          DateTime.now().difference(ts).inMinutes > _kCacheTtlMinutes;

      final List<dynamic> decoded = json.decode(raw) as List<dynamic>;
      final cached = decoded
          .map((e) => ProductModel.fromCacheJson(e as Map<String, dynamic>))
          .toList();

      _products
        ..clear()
        ..addAll(cached);

      if (isStale) {
        _errorMessage = 'Showing cached data — refreshing…';
      }
      _lastRefreshed = ts;
      _isOffline = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Cache read error: $e');
    }
  }

  // ─── Alert logic ──────────────────────────────────────────────────────────

  double get _averageChangePct {
    if (_products.isEmpty) return 0;
    final sum = _products.fold<double>(0, (acc, p) => acc + p.changePct);
    return sum / _products.length;
  }

  void _mergeAndAlert(List<ProductModel> incoming) {
    final previousById = {for (final p in _products) p.id: p};

    _products.clear();
    _products.addAll(incoming);

    for (final rule in _alertRules) {
      ProductModel? updated;
      for (final p in incoming) {
        if (p.id == rule.productId) {
          updated = p;
          break;
        }
      }
      final previous = previousById[rule.productId];
      if (updated == null || previous == null) continue;

      final crossedUp =
          rule.above &&
          updated.currentPrice >= rule.targetPrice &&
          previous.currentPrice < rule.targetPrice;
      final crossedDown =
          !rule.above &&
          updated.currentPrice <= rule.targetPrice &&
          previous.currentPrice > rule.targetPrice;

      if (crossedUp || crossedDown) {
        rule.onTrigger(updated);
      }
    }

    notifyListeners();
  }
}

// ─── Internal ─────────────────────────────────────────────────────────────────

class _AlertRule {
  const _AlertRule({
    required this.productId,
    required this.targetPrice,
    required this.above,
    required this.onTrigger,
  });

  final String productId;
  final double targetPrice;
  final bool above;
  final void Function(ProductModel) onTrigger;
}
