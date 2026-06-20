import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/price_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/product_card.dart';
import 'detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<PriceProvider, SettingsProvider>(
      builder: (context, provider, settings, _) {
        final products = provider.filteredProducts;
        final today = DateFormat('d MMMM yyyy').format(DateTime.now());
        final showMl = settings.showMalayalam;

        return Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kerala Rate | കേരള നിരക്ക്',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                Text(
                  today,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
            actions: [
              if (provider.isRefreshing)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh prices',
                  onPressed: () async {
                    final ok = await provider.refresh();
                    if (!context.mounted) return;
                    if (!ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Offline — using cached prices'),
                        ),
                      );
                    }
                  },
                ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (v) async {
                  if (v == 'offline') {
                    await provider.goOffline();
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'offline',
                    child: Text('Simulate offline'),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (provider.isOffline)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  color: AppTheme.stableColor.withValues(alpha: 0.15),
                  child: Text(
                    showMl
                        ? 'Offline — cached prices | ഓഫ്‌ലൈൻ'
                        : 'Offline — showing cached prices',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.stableColor,
                    ),
                  ),
                ),
              if (provider.marketMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Card(
                    color: AppTheme.cardColor,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        provider.marketMessage,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ),
              _MarketMoodBanner(mood: provider.marketMood, showMl: showMl),
              _FilterChipsRow(
                labels: PriceProvider.filterLabels,
                active: provider.activeFilter,
                onSelected: provider.setFilter,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: provider.setSearchQuery,
                  decoration: InputDecoration(
                    hintText: 'Search products / ഉൽപ്പന്നം തിരയുക',
                    filled: true,
                    fillColor: AppTheme.cardColor,
                    prefixIcon: const Icon(Icons.search, size: 22),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.black.withValues(alpha: 0.08),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.black.withValues(alpha: 0.08),
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              Expanded(
                child: provider.isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryColor,
                        ),
                      )
                    : products.isEmpty
                    ? Center(
                        child: Text(
                          provider.allProducts.isEmpty
                              ? (showMl
                                    ? 'No prices yet.\nSeed Firestore or check connection.'
                                    : 'No prices yet.\nSeed Firestore or check connection.')
                              : 'No products match your search',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppTheme.stableColor),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 8),
                        itemCount: products.length + 1,
                        itemBuilder: (context, index) {
                          if (index == products.length) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              child: Text(
                                provider.statusLabel,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.stableColor,
                                ),
                              ),
                            );
                          }
                          final product = products[index];
                          return ProductCard(
                            product: product,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      DetailScreen(product: product),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MarketMoodBanner extends StatelessWidget {
  const _MarketMoodBanner({required this.mood, required this.showMl});

  final MarketMood mood;
  final bool showMl;

  @override
  Widget build(BuildContext context) {
    late final Color bg;
    late final Color fg;
    late final String text;

    switch (mood) {
      case MarketMood.up:
        bg = AppTheme.priceUpColor;
        fg = Colors.white;
        text = 'Market Up ↑ | വിപണി ഉയർന്നു';
      case MarketMood.down:
        bg = AppTheme.priceDownColor;
        fg = Colors.white;
        text = 'Market Down ↓ | വിപണി താണു';
      case MarketMood.stable:
        bg = AppTheme.stableColor;
        fg = Colors.white;
        text = 'Stable → | സ്ഥിരം';
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      color: bg,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: fg,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _FilterChipsRow extends StatelessWidget {
  const _FilterChipsRow({
    required this.labels,
    required this.active,
    required this.onSelected,
  });

  final List<String> labels;
  final String active;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final label = labels[index];
          final isActive = label == active;
          return FilterChip(
            label: Text(label),
            selected: isActive,
            showCheckmark: false,
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isActive ? Colors.white : AppTheme.primaryColor,
            ),
            backgroundColor: AppTheme.cardColor,
            selectedColor: AppTheme.primaryColor,
            side: BorderSide(
              color: isActive
                  ? AppTheme.primaryColor
                  : AppTheme.primaryColor.withValues(alpha: 0.5),
            ),
            onSelected: (_) => onSelected(label),
          );
        },
      ),
    );
  }
}
