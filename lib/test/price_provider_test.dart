// test/price_provider_test.dart
//
// Tests pass a mock data source — no Firebase, no HTTP calls needed.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:spiceroot/data/models/product_model.dart';
import 'package:spiceroot/providers/price_provider.dart';
import 'package:spiceroot/services/price_data_source.dart';

// ─── Mock ─────────────────────────────────────────────────────────────────────

class MockPriceSource implements PriceDataSource {
  MockPriceSource({required this.initial, List<ProductModel>? subsequent})
    : _subsequent = subsequent;

  final List<ProductModel> initial;
  final List<ProductModel>? _subsequent;
  final _controller = StreamController<List<ProductModel>>.broadcast();

  void push(List<ProductModel> products) => _controller.add(products);

  @override
  Future<List<ProductModel>> fetchAllProducts() async => initial;

  @override
  Future<ProductModel> fetchProduct(String productId) async =>
      initial.firstWhere((p) => p.id == productId);

  @override
  Stream<List<ProductModel>> watchAllProducts() => _controller.stream;

  @override
  Future<List<PricePoint>> fetchPriceHistory(
    String productId, {
    DateTime? from,
    DateTime? to,
  }) async => [];

  @override
  Future<void> dispose() => _controller.close();
}

ProductModel _make(String id, double price) => ProductModel(
  id: id,
  nameEn: id,
  nameMl: id,
  unit: 'kg',
  district: 'Test',
  currentPrice: price,
  yesterdayPrice: price - 10,
  weekHistory: List<double>.filled(7, price),
  monthHistory: List<double>.filled(30, price),
  updatedAt: DateTime.now(),
  previousPrice: price - 10,
  priceChange: 10,
);

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  group('PriceProvider', () {
    test('loads initial products from source', () async {
      final source = MockPriceSource(initial: [_make('pepper', 800)]);
      final provider = PriceProvider(source);

      await Future.delayed(const Duration(milliseconds: 100));

      expect(provider.products.length, 1);
      expect(provider.products.first.id, 'pepper');
      expect(provider.isLoading, false);
    });

    test('updates products when source emits', () async {
      final source = MockPriceSource(initial: [_make('cardamom', 2000)]);
      final provider = PriceProvider(source);
      await Future.delayed(const Duration(milliseconds: 100));

      source.push([_make('cardamom', 2200)]);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(provider.products.first.currentPrice, 2200);
    });

    test('fires alert when price crosses threshold upward', () async {
      final source = MockPriceSource(initial: [_make('arecanut', 500)]);
      final provider = PriceProvider(source);
      await Future.delayed(const Duration(milliseconds: 100));

      ProductModel? triggered;
      provider.addAlert(
        productId: 'arecanut',
        targetPrice: 550,
        above: true,
        onTrigger: (p) => triggered = p,
      );

      source.push([_make('arecanut', 560)]);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(triggered, isNotNull);
      expect(triggered!.currentPrice, 560);
    });

    test(
      'does not fire alert when price moves in opposite direction',
      () async {
        final source = MockPriceSource(initial: [_make('arecanut', 600)]);
        final provider = PriceProvider(source);
        await Future.delayed(const Duration(milliseconds: 100));

        bool triggered = false;
        provider.addAlert(
          productId: 'arecanut',
          targetPrice: 550,
          above: true, // alert triggers when price goes ABOVE 550
          onTrigger: (_) => triggered = true,
        );

        // Price drops — should NOT trigger the "above 550" alert.
        source.push([_make('arecanut', 520)]);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(triggered, false);
      },
    );
  });

  group('ProductModel.fromApiJson', () {
    test('parses standard external API shape', () {
      final json = {
        'product_id': 'pepper',
        'product_name': 'Black Pepper',
        'product_name_ml': 'കുരുമുളക്',
        'price': 850.0,
        'prev_price': 800.0,
        'unit': 'kg',
        'updated_at': '2025-06-10T08:00:00Z',
        'category': 'spice',
      };

      final model = ProductModel.fromApiJson(json);

      expect(model.id, 'pepper');
      expect(model.currentPrice, 850.0);
      expect(model.priceChange, 50.0);
      expect(model.nameMl, 'കുരുമുളക്');
    });

    test('handles missing optional fields gracefully', () {
      final json = {'id': 'ginger', 'name': 'Ginger', 'price': 120};
      final model = ProductModel.fromApiJson(json);
      expect(model.id, 'ginger');
      expect(model.priceChange, isNull);
    });
  });
}
