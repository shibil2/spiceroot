import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/price_data.dart';
import '../models/price_alert_model.dart';
import '../models/product_model.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../utils/format_utils.dart';
import 'alerts_provider.dart';
import 'settings_provider.dart';

enum MarketMood { up, down, stable }

class PriceProvider extends ChangeNotifier {
  PriceProvider({
    FirestoreService? firestore,
    NotificationService? notifications,
  })  : _firestore = firestore ?? FirestoreService(),
        _notifications = notifications;

  final FirestoreService _firestore;
  final NotificationService? _notifications;

  static const String _cacheKey = 'cached_products_json';
  static const String _cacheTimeKey = 'cached_products_time';

  static const List<String> filterLabels = [
    'All',
    'Arecanut',
    'Pepper',
    'Spices',
    'Rubber',
    'Coconut',
  ];

  List<ProductModel> _products = [];
  String _activeFilter = 'All';
  String _searchQuery = '';
  DateTime _lastUpdated = DateTime.now();
  bool _isRefreshing = false;
  bool _isOffline = false;
  bool _loaded = false;
  bool _isLoading = true;
  String _marketMessage = '';

  StreamSubscription<List<ProductModel>>? _productsSub;
  StreamSubscription<String>? _marketMessageSub;

  AlertsProvider? _alerts;
  final Map<String, double> _previousPrices = {};
  final Set<String> _triggeredAlertIds = {};

  bool get isLoaded => _loaded;
  bool get isLoading => _isLoading;
  bool get isOffline => _isOffline;
  String get activeFilter => _activeFilter;
  String get searchQuery => _searchQuery;
  String get marketMessage => _marketMessage;
  DateTime get lastUpdated => _lastUpdated;
  bool get isRefreshing => _isRefreshing;
  List<ProductModel> get allProducts => List.unmodifiable(_products);

  ProductModel? productById(String id) {
    for (final p in _products) {
      if (p.id == id) return p;
    }
    return productByIdFromData(id);
  }

  Future<ProductModel?> fetchProduct(String id) => _firestore.getProduct(id);

  double get averageChangePct {
    if (_products.isEmpty) return 0;
    final sum = _products.fold<double>(0, (a, p) => a + p.changePct);
    return sum / _products.length;
  }

  MarketMood get marketMood {
    final avg = averageChangePct;
    if (avg > 1) return MarketMood.up;
    if (avg < -1) return MarketMood.down;
    return MarketMood.stable;
  }

  List<ProductModel> get filteredProducts {
    final query = _searchQuery.trim().toLowerCase();
    return _products.where((p) {
      if (!_matchesFilter(p, _activeFilter)) return false;
      if (query.isEmpty) return true;
      return p.nameEn.toLowerCase().contains(query) ||
          p.nameMl.contains(_searchQuery.trim()) ||
          p.district.toLowerCase().contains(query);
    }).toList();
  }

  String get lastUpdatedLabel {
    final mins = DateTime.now().difference(_lastUpdated).inMinutes;
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

  void bindAlerts(AlertsProvider alerts) {
    _alerts = alerts;
  }

  Future<void> init() async {
    await _loadCacheFromPrefs();

    _productsSub = _firestore.productsStream().listen(
      _onProductsUpdated,
      onError: _onProductsError,
    );

    _marketMessageSub = _firestore.marketMessageStream().listen(
      (message) {
        _marketMessage = message;
        notifyListeners();
      },
    );
  }

  void _onProductsUpdated(List<ProductModel> products) {
    if (products.isNotEmpty) {
      if (_previousPrices.isNotEmpty) {
        _checkPriceAlerts(products);
      }
      for (final p in products) {
        _previousPrices[p.id] = p.currentPrice;
      }
      _products = products;
      _lastUpdated = DateTime.now();
      _isOffline = false;
      unawaited(_saveCache());
    }
    _isLoading = false;
    _loaded = true;
    notifyListeners();
  }

  void _checkPriceAlerts(List<ProductModel> products) {
    final alerts = _alerts;
    final notifications = _notifications;
    if (alerts == null || notifications == null || !alerts.isLoaded) return;

    final byId = {for (final p in products) p.id: p};

    for (final PriceAlertModel alert in alerts.alerts) {
      final product = byId[alert.productId];
      if (product == null) continue;

      final current = product.currentPrice;
      final isTriggered = alert.alertAbove
          ? current >= alert.targetPrice
          : current <= alert.targetPrice;
      final wasTriggered = _triggeredAlertIds.contains(alert.id);

      if (isTriggered && !wasTriggered) {
        _triggeredAlertIds.add(alert.id);
        unawaited(
          notifications.showPriceAlert(
            productName: product.nameEn,
            currentPrice: current,
            targetPrice: alert.targetPrice,
            unit: FormatUtils.unitLabel(product),
            productId: product.id,
          ),
        );
      } else if (!isTriggered && wasTriggered) {
        _triggeredAlertIds.remove(alert.id);
      }
    }
  }

  void _onProductsError(Object error, StackTrace stackTrace) {
    debugPrint('Firestore products stream error: $error');
    _isOffline = true;
    _isLoading = false;
    _loaded = true;
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

  Future<bool> refresh() async {
    if (_isRefreshing) return !_isOffline;
    _isRefreshing = true;
    notifyListeners();

    try {
      final product = await _firestore.getProduct(
        _products.isNotEmpty ? _products.first.id : 'arecanut',
      );
      if (product != null) {
        _isOffline = false;
      }
    } catch (e) {
      debugPrint('Refresh check failed: $e');
      _isOffline = true;
    }

    _isRefreshing = false;
    notifyListeners();
    return !_isOffline;
  }

  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_cacheTimeKey);
    _isOffline = false;
    notifyListeners();
  }

  Future<void> goOffline() async {
    _isOffline = true;
    notifyListeners();
  }

  bool shouldAutoRefresh(RefreshMode mode) {
    if (mode == RefreshMode.manual) return false;
    final elapsed = DateTime.now().difference(_lastUpdated);
    if (mode == RefreshMode.hourly) {
      return elapsed.inHours >= 1;
    }
    return elapsed.inDays >= 1;
  }

  Future<void> _loadCacheFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    final timeRaw = prefs.getString(_cacheTimeKey);

    if (raw == null || raw.isEmpty) return;

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final cached = list
          .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
          .toList();
      if (cached.isNotEmpty) {
        _products = cached;
        if (timeRaw != null) {
          _lastUpdated = DateTime.tryParse(timeRaw) ?? DateTime.now();
        }
        _isOffline = true;
        notifyListeners();
      }
    } catch (_) {
      // Ignore corrupt cache.
    }
  }

  Future<void> _saveCache() async {
    if (_products.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_products.map((p) => p.toJson()).toList());
    await prefs.setString(_cacheKey, encoded);
    await prefs.setString(_cacheTimeKey, _lastUpdated.toIso8601String());
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

  @override
  void dispose() {
    _productsSub?.cancel();
    _marketMessageSub?.cancel();
    super.dispose();
  }
}

ProductModel? productByIdFromData(String id) {
  for (final p in keralaProducts) {
    if (p.id == id) return p;
  }
  return null;
}
