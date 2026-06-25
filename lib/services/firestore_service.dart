import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../data/price_data.dart';
import '../data/models/admin_config.dart';
import '../data/models/product_model.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const String productsCollection = 'products';
  static const String adminCollection = 'admin';
  static const String adminConfigDoc = 'config';

  /// Real-time stream of all products (home screen listens to this).
  Stream<List<ProductModel>> productsStream() {
    return _db.collection(productsCollection).snapshots().map((snap) {
      final products = <ProductModel>[];
      for (final doc in snap.docs) {
        if (!doc.exists) continue;
        try {
          products.add(ProductModel.fromFirestore(doc));
        } catch (e) {
          debugPrint('Skipping invalid product "${doc.id}": $e');
        }
      }
      products.sort((a, b) => a.nameEn.compareTo(b.nameEn));
      return products;
    });
  }

  /// Fetch single product with history.
  Future<ProductModel?> getProduct(String id) async {
    final doc = await _db.collection(productsCollection).doc(id).get();
    if (!doc.exists) return null;
    return ProductModel.fromFirestore(doc);
  }

  /// Admin: update today's price for a product.
  Future<void> updatePrice(
    String productId,
    double newPrice, {
    String? updatedBy,
  }) async {
    final ref = _db.collection(productsCollection).doc(productId);
    final doc = await ref.get();
    if (!doc.exists) {
      throw StateError('Product "$productId" not found');
    }

    final data = doc.data()!;
    final oldPrice = (data['currentPrice'] as num).toDouble();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    await ref.update({
      'yesterdayPrice': oldPrice,
      'currentPrice': newPrice,
      'updatedAt': FieldValue.serverTimestamp(),
      'history': FieldValue.arrayUnion([
        {'date': today, 'price': newPrice},
      ]),
    });

    await _touchAdminConfig(updatedBy: updatedBy);
  }

  Future<void> _touchAdminConfig({String? updatedBy}) async {
    final patch = <String, dynamic>{
      'lastUpdated': FieldValue.serverTimestamp(),
    };
    if (updatedBy != null) patch['updatedBy'] = updatedBy;
    await _db
        .collection(adminCollection)
        .doc(adminConfigDoc)
        .set(patch, SetOptions(merge: true));
  }

  /// Market message for home screen banner.
  Stream<String> marketMessageStream() {
    return adminConfigStream().map((c) => c?.marketMessage ?? '');
  }

  /// Admin config (last updated, market message, etc.).
  Stream<AdminConfig?> adminConfigStream() {
    return _db.collection(adminCollection).doc(adminConfigDoc).snapshots().map((
      doc,
    ) {
      if (!doc.exists) return null;
      final data = doc.data()!;
      return AdminConfig(
        lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate(),
        updatedBy: data['updatedBy'] as String? ?? '',
        marketMessage: data['marketMessage'] as String? ?? '',
      );
    });
  }

  /// Publishes today's market message for all users (home banner).
  Future<void> publishMarketMessage({
    required String message,
    required String updatedBy,
  }) async {
    await _db.collection(adminCollection).doc(adminConfigDoc).set({
      'marketMessage': message.trim(),
      'lastUpdated': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    }, SetOptions(merge: true));
  }

  static const String notificationsCollection = 'notifications';

  /// Queues a broadcast push for a significant price change.
  /// A Cloud Function listening on `notifications` can send FCM to all tokens.
  Future<void> queuePriceChangeNotification({
    required String productId,
    required String productName,
    required double oldPrice,
    required double newPrice,
    required String updatedBy,
  }) async {
    final changePct = oldPrice == 0
        ? 0.0
        : ((newPrice - oldPrice) / oldPrice * 100).abs();

    await _db.collection(notificationsCollection).add({
      'type': 'price_change',
      'productId': productId,
      'productName': productName,
      'oldPrice': oldPrice,
      'newPrice': newPrice,
      'changePct': changePct,
      'title': '$productName price update',
      'body':
          '$productName moved from ₹${oldPrice.round()} to ₹${newPrice.round()} '
          '(${changePct.toStringAsFixed(1)}%)',
      'updatedBy': updatedBy,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Batch-updates multiple product prices and admin lastUpdated.
  Future<void> batchUpdatePrices(
    Map<String, double> priceByProductId, {
    required String updatedBy,
  }) async {
    if (priceByProductId.isEmpty) return;

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final batch = _db.batch();

    for (final entry in priceByProductId.entries) {
      final ref = _db.collection(productsCollection).doc(entry.key);
      final snap = await ref.get();
      if (!snap.exists) continue;

      final data = snap.data()!;
      final oldPrice = (data['currentPrice'] as num).toDouble();
      final newPrice = entry.value;

      batch.update(ref, {
        'yesterdayPrice': oldPrice,
        'currentPrice': newPrice,
        'updatedAt': FieldValue.serverTimestamp(),
        'history': FieldValue.arrayUnion([
          {'date': today, 'price': newPrice},
        ]),
      });
    }

    batch.set(_db.collection(adminCollection).doc(adminConfigDoc), {
      'lastUpdated': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    }, SetOptions(merge: true));

    await batch.commit();
  }

  /// One-time seed of mock Kerala products + admin config (dev/setup).
  Future<void> seedDatabase({
    String updatedBy = 'admin@keralarate.app',
    String marketMessage = 'Arecanut arrivals high at Mangaluru APMC today',
  }) async {
    final now = DateTime.now();
    final batch = _db.batch();
    final products = _db.collection(productsCollection);
    final admin = _db.collection(adminCollection).doc(adminConfigDoc);

    for (final product in keralaProducts) {
      final weekHigh = product.weekHistory.reduce((a, b) => a > b ? a : b);
      final weekLow = product.weekHistory.reduce((a, b) => a < b ? a : b);

      batch.set(products.doc(product.id), {
        'nameEn': product.nameEn,
        'nameMl': product.nameMl,
        'unit': product.unit,
        'district': product.district,
        'currentPrice': product.currentPrice,
        'yesterdayPrice': product.yesterdayPrice,
        'weekHigh': weekHigh,
        'weekLow': weekLow,
        'updatedAt': Timestamp.fromDate(now),
        'history': _historyEntries(product.monthHistory, now),
      });
    }

    batch.set(admin, {
      'lastUpdated': Timestamp.fromDate(now),
      'updatedBy': updatedBy,
      'marketMessage': marketMessage,
      'adminEmail': updatedBy,
      'adminEmails': [updatedBy],
    });

    await batch.commit();
  }

  List<Map<String, dynamic>> _historyEntries(
    List<double> prices,
    DateTime endDate,
  ) {
    final entries = <Map<String, dynamic>>[];
    for (var i = 0; i < prices.length; i++) {
      final day = endDate.subtract(Duration(days: prices.length - 1 - i));
      final dateStr = DateFormat('yyyy-MM-dd').format(day);
      entries.add({'date': dateStr, 'price': prices[i]});
    }
    return entries;
  }
}
