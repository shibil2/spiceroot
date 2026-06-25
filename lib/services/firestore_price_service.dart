// lib/services/firestore_price_service.dart
//
// Original Firestore-backed implementation, now conforming to PriceDataSource.
// Kept intact so you can switch back to it instantly at the injection site.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/models/product_model.dart';
import 'price_data_source.dart';

class FirestorePriceService implements PriceDataSource {
  FirestorePriceService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('products');

  @override
  Future<List<ProductModel>> fetchAllProducts() async {
    final snap = await _col.orderBy('nameEn').get();
    return snap.docs.map((d) => ProductModel.fromFirestore(d)).toList();
  }

  @override
  Future<ProductModel> fetchProduct(String productId) async {
    final doc = await _col.doc(productId).get();
    if (!doc.exists) throw StateError('Product $productId not found');
    return ProductModel.fromFirestore(doc);
  }

  @override
  Stream<List<ProductModel>> watchAllProducts() {
    return _col
        .orderBy('nameEn')
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => ProductModel.fromFirestore(d)).toList(),
        );
  }

  @override
  Future<List<PricePoint>> fetchPriceHistory(
    String productId, {
    DateTime? from,
    DateTime? to,
  }) async {
    Query<Map<String, dynamic>> q = _db
        .collection('price_history')
        .where('productId', isEqualTo: productId);

    if (from != null) q = q.where('timestamp', isGreaterThanOrEqualTo: from);
    if (to != null) q = q.where('timestamp', isLessThanOrEqualTo: to);

    final snap = await q.orderBy('timestamp').get();
    return snap.docs.map((d) {
      final data = d.data();
      return PricePoint(
        timestamp: (data['timestamp'] as Timestamp).toDate(),
        price: (data['price'] as num).toDouble(),
      );
    }).toList();
  }

  @override
  Future<void> dispose() async {
    // Firestore manages its own connection pool — nothing to close here.
  }
}
