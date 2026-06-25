import 'dart:math';

import 'models/product_model.dart';

/// All Kerala commodity mock prices (30-day history per product).
final List<ProductModel> keralaProducts = _buildProducts();

List<ProductModel> _buildProducts() {
  const specs = <_ProductSpec>[
    _ProductSpec(
      id: 'arecanut',
      nameEn: 'Arecanut',
      nameMl: 'അടക്ക',
      unit: 'per kg',
      district: 'Kasaragod',
      currentPrice: 420,
      minPrice: 380,
      maxPrice: 480,
      seed: 101,
    ),
    _ProductSpec(
      id: 'black_pepper',
      nameEn: 'Black Pepper',
      nameMl: 'കുരുമുളക്',
      unit: 'per kg',
      district: 'Wayanad',
      currentPrice: 640,
      minPrice: 550,
      maxPrice: 750,
      seed: 202,
    ),
    _ProductSpec(
      id: 'cardamom',
      nameEn: 'Cardamom',
      nameMl: 'ഏലക്ക',
      unit: 'per kg',
      district: 'Idukki',
      currentPrice: 1450,
      minPrice: 1200,
      maxPrice: 1800,
      seed: 303,
    ),
    _ProductSpec(
      id: 'rubber_rss4',
      nameEn: 'Rubber RSS4',
      nameMl: 'റബ്ബർ',
      unit: 'per kg',
      district: 'Kottayam',
      currentPrice: 172,
      minPrice: 150,
      maxPrice: 200,
      seed: 404,
    ),
    _ProductSpec(
      id: 'coconut',
      nameEn: 'Coconut',
      nameMl: 'തേങ്ങ',
      unit: 'per nut',
      district: 'Thrissur',
      currentPrice: 22,
      minPrice: 18,
      maxPrice: 28,
      seed: 505,
    ),
    _ProductSpec(
      id: 'ginger_dry',
      nameEn: 'Ginger dry',
      nameMl: 'ഇഞ്ചി',
      unit: 'per kg',
      district: 'Wayanad',
      currentPrice: 115,
      minPrice: 90,
      maxPrice: 140,
      seed: 606,
    ),
    _ProductSpec(
      id: 'coffee_robusta',
      nameEn: 'Coffee Robusta',
      nameMl: 'കാപ്പി',
      unit: 'per kg',
      district: 'Wayanad',
      currentPrice: 235,
      minPrice: 200,
      maxPrice: 260,
      seed: 707,
    ),
    _ProductSpec(
      id: 'nutmeg',
      nameEn: 'Nutmeg',
      nameMl: 'ജാതിക്ക',
      unit: 'per kg',
      district: 'Kozhikode',
      currentPrice: 720,
      minPrice: 600,
      maxPrice: 900,
      seed: 808,
    ),
    _ProductSpec(
      id: 'cloves',
      nameEn: 'Cloves',
      nameMl: 'ഗ്രാമ്പൂ',
      unit: 'per kg',
      district: 'Thrissur',
      currentPrice: 950,
      minPrice: 800,
      maxPrice: 1100,
      seed: 909,
    ),
    _ProductSpec(
      id: 'turmeric',
      nameEn: 'Turmeric',
      nameMl: 'മഞ്ഞൾ',
      unit: 'per kg',
      district: 'Ernakulam',
      currentPrice: 110,
      minPrice: 80,
      maxPrice: 130,
      seed: 1010,
    ),
  ];

  return specs.map(_productFromSpec).toList();
}

class _ProductSpec {
  const _ProductSpec({
    required this.id,
    required this.nameEn,
    required this.nameMl,
    required this.unit,
    required this.district,
    required this.currentPrice,
    required this.minPrice,
    required this.maxPrice,
    required this.seed,
  });

  final String id;
  final String nameEn;
  final String nameMl;
  final String unit;
  final String district;
  final double currentPrice;
  final double minPrice;
  final double maxPrice;
  final int seed;
}

ProductModel _productFromSpec(_ProductSpec spec) {
  final monthHistory = _generateMonthHistory(
    currentPrice: spec.currentPrice,
    minPrice: spec.minPrice,
    maxPrice: spec.maxPrice,
    seed: spec.seed,
  );
  final weekHistory = monthHistory.sublist(monthHistory.length - 7);

  return ProductModel(
    id: spec.id,
    nameEn: spec.nameEn,
    nameMl: spec.nameMl,
    unit: spec.unit,
    district: spec.district,
    currentPrice: monthHistory.last,
    yesterdayPrice: monthHistory[monthHistory.length - 2],
    weekHistory: weekHistory,
    monthHistory: monthHistory,
  );
}

/// Builds 30 daily prices (oldest → newest) with mean-reverting random walk.
List<double> _generateMonthHistory({
  required double currentPrice,
  required double minPrice,
  required double maxPrice,
  required int seed,
}) {
  const days = 30;
  final rng = Random(seed);
  final span = maxPrice - minPrice;
  final decimals = currentPrice < 50 ? 1 : 0;

  // Start ~2–3 weeks ago near mid-range with product-specific offset.
  double price =
      (minPrice + maxPrice) / 2 + (rng.nextDouble() - 0.5) * span * 0.35;
  price = price.clamp(minPrice, maxPrice);

  final history = <double>[];

  for (var day = 0; day < days - 1; day++) {
    // Gentle pull toward today's market level plus daily noise.
    final targetDrift =
        (currentPrice - price) * (0.04 + rng.nextDouble() * 0.03);
    final seasonal = sin(day / 5.5 + seed * 0.1) * span * 0.012; // slow wave
    final shock = (rng.nextDouble() - 0.5) * span * 0.045;
    price = (price + targetDrift + seasonal + shock).clamp(minPrice, maxPrice);
    history.add(_roundPrice(price, decimals));
  }

  // Yesterday: small step from second-to-last generated day toward today.
  final lastGenerated = history.isNotEmpty ? history.last : price;
  var yesterday =
      lastGenerated +
      (currentPrice - lastGenerated) * (0.35 + rng.nextDouble() * 0.25) +
      (rng.nextDouble() - 0.5) * span * 0.02;
  yesterday = yesterday.clamp(minPrice, maxPrice);
  if ((yesterday - currentPrice).abs() < span * 0.008) {
    yesterday = currentPrice + (rng.nextDouble() > 0.5 ? 1 : -1) * span * 0.015;
    yesterday = yesterday.clamp(minPrice, maxPrice);
  }

  history.add(_roundPrice(yesterday, decimals));
  history.add(_roundPrice(currentPrice, decimals));

  return history;
}

double _roundPrice(double value, int decimals) {
  final factor = pow(10, decimals).toDouble();
  return (value * factor).round() / factor;
}

/// Lookup by product id.
ProductModel? productById(String id) {
  for (final p in keralaProducts) {
    if (p.id == id) return p;
  }
  return null;
}
