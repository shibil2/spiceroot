// lib/services/price_data_source.dart
//
// Abstract contract every price source must satisfy.
// Swap Firestore ↔ external API by injecting a different implementation.

import '../data/models/product_model.dart';

abstract interface class PriceDataSource {
  /// Returns the full product catalogue with current prices.
  Future<List<ProductModel>> fetchAllProducts();

  /// Returns a single product by its stable identifier.
  Future<ProductModel> fetchProduct(String productId);

  /// Emits a fresh snapshot whenever prices change on the source.
  /// Implementations that poll should emit on each interval tick.
  Stream<List<ProductModel>> watchAllProducts();

  /// Optional: returns timestamped price history for charting.
  /// Return an empty list if the source does not support history.
  Future<List<PricePoint>> fetchPriceHistory(
    String productId, {
    DateTime? from,
    DateTime? to,
  });

  /// Release any resources (timers, HTTP clients, socket connections).
  Future<void> dispose();
}

/// Lightweight value object used in price-history charts.
class PricePoint {
  const PricePoint({required this.timestamp, required this.price});

  final DateTime timestamp;
  final double price;

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'price': price,
  };

  factory PricePoint.fromJson(Map<String, dynamic> json) => PricePoint(
    timestamp: DateTime.parse(json['timestamp'] as String),
    price: (json['price'] as num).toDouble(),
  );
}
