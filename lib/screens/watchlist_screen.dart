import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models/product_model.dart';
import '../providers/price_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/watchlist_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/product_card.dart';
import 'detail_screen.dart';

class WatchlistScreen extends StatelessWidget {
  const WatchlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          settings.showMalayalam ? 'Watchlist | വാച്ച്‌ലിസ്റ്റ്' : 'Watchlist',
        ),
      ),
      body: Consumer2<WatchlistProvider, PriceProvider>(
        builder: (context, watchlist, prices, _) {
          if (!watchlist.isLoaded || !prices.isLoaded) {
            return const Center(child: CircularProgressIndicator());
          }

          final products = watchlist.ids
              .map(prices.productById)
              .whereType<ProductModel>()
              .toList();

          if (products.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.bookmark_border,
                      size: 64,
                      color: AppTheme.stableColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      settings.showMalayalam
                          ? 'No products saved yet.\nTap ☆ on any product to watch it.'
                          : 'No products saved yet.\nTap ☆ on any product to watch it.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppTheme.stableColor,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return ProductCard(
                product: product,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DetailScreen(product: product),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
