import 'package:intl/intl.dart';

import '../models/product_model.dart';

abstract final class FormatUtils {
  static final NumberFormat _inr = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  static String price(double value) {
    if (value < 50 && value != value.roundToDouble()) {
      return '₹${value.toStringAsFixed(1)}';
    }
    return _inr.format(value);
  }

  static String changeString(ProductModel product) {
    final pct = product.changePct;
    final sign = pct >= 0 ? '+' : '';
    return '$sign${pct.toStringAsFixed(1)}%';
  }

  static String unitLabel(ProductModel product) {
    if (product.unit.contains('nut')) return 'per nut';
    return 'per kg';
  }

  static String shareMessage(ProductModel product) {
    final changeStr = changeString(product);
    final unit = unitLabel(product);
    return '${product.nameEn} today: ${price(product.currentPrice)}/$unit ($changeStr) - Kerala Rate App';
  }
}
