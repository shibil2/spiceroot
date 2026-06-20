import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product_model.dart';
import '../providers/settings_provider.dart';
import '../providers/watchlist_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import 'mini_chart.dart';
import 'price_badge.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.showBookmark = true,
  });

  final ProductModel product;
  final VoidCallback onTap;
  final bool showBookmark;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final watchlist = context.watch<WatchlistProvider>();
    final watched = watchlist.isWatched(product.id);
    final showMl = settings.showMalayalam;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: AppTheme.cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.nameEn,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A18),
                          ),
                        ),
                        if (showMl) ...[
                          const SizedBox(height: 2),
                          Text(
                            product.nameMl,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF888780),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        _DistrictChip(district: product.district),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (showBookmark)
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            watched ? Icons.star : Icons.star_border,
                            color: watched
                                ? AppTheme.primaryColor
                                : AppTheme.stableColor,
                            size: 22,
                          ),
                          onPressed: () => watchlist.toggle(product.id),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        FormatUtils.price(product.currentPrice),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A18),
                        ),
                      ),
                      const SizedBox(height: 6),
                      PriceBadge(product: product),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              MiniChart(product: product),
            ],
          ),
        ),
      ),
    );
  }
}

class _DistrictChip extends StatelessWidget {
  const _DistrictChip({required this.district});

  final String district;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        district,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }
}
