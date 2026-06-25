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

    final current = (data['currentPrice'] as num?)?.toDouble();
    final yesterday = (data['yesterdayPrice'] as num?)?.toDouble();
    if (current == null || yesterday == null) {
      throw StateError(
        'Product "$id" is missing currentPrice or yesterdayPrice',
      );
    }

    final monthHistory = _parseFirestoreHistory(data);
    final weekHistory = _deriveWeekHistory(data, monthHistory);

    return ProductModel(
      id: id,
      nameEn: data['nameEn'] as String? ?? id,
      nameMl: data['nameMl'] as String? ?? '',
      unit: data['unit'] as String? ?? 'per kg',
      district: data['district'] as String? ?? '',
      currentPrice: current,
      yesterdayPrice: yesterday,
      weekHistory: weekHistory,
      monthHistory: monthHistory,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
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

  static List<double> _parseHistoryList(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .map<double?>((item) {
          if (item is num) return item.toDouble();
          if (item is String) return double.tryParse(item);
          if (item is Map) return (item['price'] as num?)?.toDouble();
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
    );
  }
}
