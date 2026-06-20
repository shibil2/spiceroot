import 'package:flutter/material.dart';

import '../models/product_model.dart';
import '../theme/app_theme.dart';

class PriceBadge extends StatelessWidget {
  const PriceBadge({super.key, required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    final change = product.change;
    final absChange = change.abs();
    final amount = absChange == absChange.roundToDouble()
        ? absChange.toInt().toString()
        : absChange.toStringAsFixed(1);

    late final Color bg;
    late final Color fg;
    late final String label;

    if (product.isUp) {
      bg = AppTheme.priceUpColor.withValues(alpha: 0.12);
      fg = AppTheme.priceUpColor;
      label = '+₹$amount ▲';
    } else if (product.isDown) {
      bg = AppTheme.priceDownColor.withValues(alpha: 0.12);
      fg = AppTheme.priceDownColor;
      label = '-₹$amount ▼';
    } else {
      bg = AppTheme.stableColor.withValues(alpha: 0.12);
      fg = AppTheme.stableColor;
      label = '₹0 →';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
