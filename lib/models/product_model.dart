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
  });

  double get change => currentPrice - yesterdayPrice;
  double get changePct => yesterdayPrice == 0 ? 0 : (change / yesterdayPrice) * 100;
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
      throw StateError('Product "$id" is missing currentPrice or yesterdayPrice');
    }

    final monthHistory = _parseHistoryPrices(data['history']);
    final weekHistory = monthHistory.length >= 7
        ? monthHistory.sublist(monthHistory.length - 7)
        : List<double>.from(monthHistory);

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
      (a, b) => (a['date'] as String? ?? '').compareTo(b['date'] as String? ?? ''),
    );

    return entries
        .map((e) => (e['price'] as num?)?.toDouble())
        .whereType<double>()
        .toList();
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
      };

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as String,
      nameEn: json['nameEn'] as String,
      nameMl: json['nameMl'] as String,
      unit: json['unit'] as String,
      district: json['district'] as String,
      currentPrice: (json['currentPrice'] as num).toDouble(),
      yesterdayPrice: (json['yesterdayPrice'] as num).toDouble(),
      weekHistory: (json['weekHistory'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(),
      monthHistory: (json['monthHistory'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(),
    );
  }
}
