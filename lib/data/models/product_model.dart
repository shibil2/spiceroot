import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModel {
  final String id;
  final String nameEn;
  final String nameMl;
  final String unit;
  final String district;
  final double currentPrice;
  final double yesterdayPrice;
  final List<double> weekHistory;
  final List<double> monthHistory;
  final DateTime? updatedAt;
  final double? previousPrice;
  final double? priceChange;

  const ProductModel({
    required this.id,
    required this.nameEn,
    required this.nameMl,
    required this.unit,
    required this.district,
    required this.currentPrice,
    required this.yesterdayPrice,
    required this.weekHistory,
    required this.monthHistory,
    this.updatedAt,
    this.previousPrice,
    this.priceChange,
  });

  double get change => currentPrice - yesterdayPrice;

  double get changePct =>
      yesterdayPrice == 0 ? 0 : (change / yesterdayPrice) * 100;

  bool get isUp => change > 0;

  bool get isDown => change < 0;

  /// Parses a Firestore `products/{id}` document.
  factory ProductModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    if (!doc.exists) {
      throw StateError('Product document "${doc.id}" does not exist');
    }
    final data = doc.data()!;
    final id = doc.id;

    final current = _parseNumber(
      data['currentPrice'] ?? data['price'] ?? data['current_price'],
    );
    final yesterday = _parseNumber(
      data['yesterdayPrice'] ??
          data['previousPrice'] ??
          data['prevPrice'] ??
          data['yesterday_price'],
    );
    if (current == null || yesterday == null) {
      throw StateError(
        'Product "$id" is missing currentPrice or yesterdayPrice',
      );
    }

    final monthHistory = _parseFirestoreHistory(data);
    final weekHistory = _deriveWeekHistory(data, monthHistory);

    return ProductModel(
      id: id,
      nameEn:
          data['nameEn'] as String? ??
          data['name'] as String? ??
          data['product_name'] as String? ??
          id,
      nameMl: data['nameMl'] as String? ?? data['name_ml'] as String? ?? '',
      unit: data['unit'] as String? ?? 'per kg',
      district: data['district'] as String? ?? '',
      currentPrice: current,
      yesterdayPrice: yesterday,
      weekHistory: weekHistory,
      monthHistory: monthHistory,
      updatedAt: _parseTimestamp(
        data['updatedAt'] ?? data['lastUpdated'] ?? data['updated_at'],
      ),
    );
  }

  static List<double> _parseHistoryPrices(dynamic historyRaw) {
    if (historyRaw is! List) return [];

    final entries = <Map<String, dynamic>>[];
    for (final item in historyRaw) {
      if (item is Map) {
        entries.add(Map<String, dynamic>.from(item));
      }
    }

    entries.sort(
      (a, b) =>
          (a['date'] as String? ?? '').compareTo(b['date'] as String? ?? ''),
    );

    return entries
        .map((e) => (e['price'] as num?)?.toDouble())
        .whereType<double>()
        .toList();
  }

  static double? _parseNumber(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static List<double> _parseHistoryList(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .map<double?>((item) {
          if (item is num) return item.toDouble();
          if (item is String) return double.tryParse(item);
          if (item is Map) return _parseNumber(item['price']);
          return null;
        })
        .whereType<double>()
        .toList();
  }

  static List<double> _parseFirestoreHistory(Map<String, dynamic> data) {
    final historyFromHistoryField = _parseHistoryPrices(data['history']);
    if (historyFromHistoryField.isNotEmpty) return historyFromHistoryField;

    final monthHistoryField = _parseHistoryList(data['monthHistory']);
    if (monthHistoryField.isNotEmpty) return monthHistoryField;

    final weekHistoryField = _parseHistoryList(data['weekHistory']);
    if (weekHistoryField.isNotEmpty) return weekHistoryField;

    return const [];
  }

  static List<double> _deriveWeekHistory(
    Map<String, dynamic> data,
    List<double> monthHistory,
  ) {
    if (monthHistory.length >= 7) {
      return monthHistory.sublist(monthHistory.length - 7);
    }

    final weekHistoryField = _parseHistoryList(data['weekHistory']);
    if (weekHistoryField.isNotEmpty) return weekHistoryField;

    return List<double>.from(monthHistory);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nameEn': nameEn,
    'nameMl': nameMl,
    'unit': unit,
    'district': district,
    'currentPrice': currentPrice,
    'yesterdayPrice': yesterdayPrice,
    'weekHistory': weekHistory,
    'monthHistory': monthHistory,
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
  };

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final monthHistory = _parseHistoryList(json['monthHistory']);
    final weekHistory = _parseHistoryList(json['weekHistory']);
    final derivedWeekHistory = weekHistory.isNotEmpty
        ? weekHistory
        : monthHistory.length >= 7
        ? monthHistory.sublist(monthHistory.length - 7)
        : List<double>.from(monthHistory);
    final derivedMonthHistory = monthHistory.isNotEmpty
        ? monthHistory
        : List<double>.from(weekHistory);

    return ProductModel(
      id: json['id'] as String,
      nameEn: json['nameEn'] as String,
      nameMl: json['nameMl'] as String,
      unit: json['unit'] as String,
      district: json['district'] as String,
      currentPrice: (json['currentPrice'] as num).toDouble(),
      yesterdayPrice: (json['yesterdayPrice'] as num).toDouble(),
      weekHistory: derivedWeekHistory,
      monthHistory: derivedMonthHistory,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
      previousPrice: (json['previousPrice'] as num?)?.toDouble(),
      priceChange: (json['priceChange'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toCacheJson() => {
    'id': id,
    'nameEn': nameEn,
    'nameMl': nameMl,
    'unit': unit,
    'district': district,
    'currentPrice': currentPrice,
    'yesterdayPrice': yesterdayPrice,
    'weekHistory': weekHistory,
    'monthHistory': monthHistory,
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    if (previousPrice != null) 'previousPrice': previousPrice,
    if (priceChange != null) 'priceChange': priceChange,
  };

  factory ProductModel.fromCacheJson(Map<String, dynamic> json) {
    return ProductModel.fromJson(json);
  }

  factory ProductModel.fromApiJson(Map<String, dynamic> json) {
    final current = _parseNumber(
      json['rate'] ??
          json['price'] ??
          json['current_price'] ??
          json['currentPrice'],
    );
    final previous = _parseNumber(
      json['prev_price'] ??
          json['previous_price'] ??
          json['previousPrice'] ??
          json['yesterdayPrice'],
    );

    return ProductModel(
      id: (json['product_id'] ?? json['id'] ?? '').toString(),
      nameEn:
          json['title'] as String? ??
          json['product_name'] as String? ??
          json['name'] as String? ??
          json['nameEn'] as String? ??
          '',
      nameMl:
          json['product_name_ml'] as String? ??
          json['name_ml'] as String? ??
          json['nameMl'] as String? ??
          '',
      unit: json['measured_in'] as String? ?? json['unit'] as String? ?? 'kg',
      district: json['district'] as String? ?? '',
      currentPrice: current ?? 0.0,
      yesterdayPrice: previous ?? 0.0,
      weekHistory: _parseHistoryList(
        json['weekHistory'] ?? json['week_history'],
      ),
      monthHistory: _parseHistoryList(
        json['monthHistory'] ?? json['month_history'],
      ),
      updatedAt: _parseTimestamp(
        json['updated_at'] ?? json['updatedAt'] ?? json['lastUpdated'],
      ),
      previousPrice: previous,
      priceChange: current != null && previous != null
          ? current - previous
          : null,
    );
  }
}
