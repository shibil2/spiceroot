import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/market_info.dart';
import '../models/product_model.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../widgets/price_badge.dart';
import '../widgets/price_chart.dart';

enum ChartRange { week, month, quarter }

class DetailScreen extends StatefulWidget {
  const DetailScreen({super.key, required this.product});

  final ProductModel product;

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  ChartRange _range = ChartRange.week;
  String? _grade;

  ProductModel get product => widget.product;

  List<String>? get _grades {
    switch (product.id) {
      case 'arecanut':
        return const ['Full', 'Splits', 'Powder'];
      case 'black_pepper':
        return const ['Garbled', 'Ungarbled'];
      default:
        return null;
    }
  }

  List<double> get _chartHistory {
    switch (_range) {
      case ChartRange.week:
        return product.weekHistory;
      case ChartRange.month:
        return product.monthHistory;
      case ChartRange.quarter:
        return product.monthHistory;
    }
  }

  @override
  void initState() {
    super.initState();
    final grades = _grades;
    if (grades != null && grades.isNotEmpty) {
      _grade = grades.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final showMl = settings.showMalayalam;
    final market = marketInfoFor(product);
    final todayHigh = product.weekHistory.reduce((a, b) => a > b ? a : b);
    final todayLow = product.weekHistory.reduce((a, b) => a < b ? a : b);
    final monthHigh =
        product.monthHistory.reduce((a, b) => a > b ? a : b);
    final monthLow =
        product.monthHistory.reduce((a, b) => a < b ? a : b);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(product.nameEn),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => Share.share(FormatUtils.shareMessage(product)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            product.nameEn,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A18),
            ),
          ),
          if (showMl) ...[
            const SizedBox(height: 4),
            Text(
              product.nameMl,
              style: const TextStyle(fontSize: 16, color: Color(0xFF888780)),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            FormatUtils.price(product.currentPrice),
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          PriceBadge(product: product),
          if (_signalBanner() != null) ...[
            const SizedBox(height: 12),
            _signalBanner()!,
          ],
          if (_grades != null) ...[
            const SizedBox(height: 20),
            Text(
              showMl ? 'Grade / ഗ്രേഡ്' : 'Grade',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _grades!.map((g) {
                return ChoiceChip(
                  label: Text(g),
                  selected: _grade == g,
                  selectedColor: AppTheme.primaryColor,
                  labelStyle: TextStyle(
                    color: _grade == g ? Colors.white : AppTheme.primaryColor,
                  ),
                  onSelected: (_) => setState(() => _grade = g),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 20),
          SegmentedButton<ChartRange>(
            segments: const [
              ButtonSegment(value: ChartRange.week, label: Text('1W')),
              ButtonSegment(value: ChartRange.month, label: Text('1M')),
              ButtonSegment(value: ChartRange.quarter, label: Text('3M')),
            ],
            selected: {_range},
            onSelectionChanged: (s) => setState(() => _range = s.first),
          ),
          const SizedBox(height: 12),
          PriceChart(history: _chartHistory),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.6,
            children: [
              _StatCard(
                label: showMl ? 'Today High / ഉയർന്നു' : 'Today High',
                value: FormatUtils.price(todayHigh),
              ),
              _StatCard(
                label: showMl ? 'Today Low / താഴ്ന്നു' : 'Today Low',
                value: FormatUtils.price(todayLow),
              ),
              _StatCard(
                label: showMl ? 'Month High' : 'Month High',
                value: FormatUtils.price(monthHigh),
              ),
              _StatCard(
                label: showMl ? 'Month Low' : 'Month Low',
                value: FormatUtils.price(monthLow),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            showMl ? 'Market info / വിപണി വിവരം' : 'Market info',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Card(
            color: AppTheme.cardColor,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    showMl ? 'Major APMC markets' : 'Major APMC markets',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.stableColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...market.markets.map(
                    (m) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.store,
                            size: 16,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(m)),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 20),
                  Text(
                    showMl ? 'Arrival / എത്തിച്ചേരൽ' : 'Arrival',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.stableColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    market.arrival,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget? _signalBanner() {
    final pct = product.changePct;
    if (pct > 2) {
      return _Banner(
        text: 'Strong Buy Signal | ശക്തമായ വാങ്ങൽ സിഗ്നൽ',
        color: AppTheme.priceUpColor,
      );
    }
    if (pct < -2) {
      return _Banner(
        text: 'Falling — Monitor Closely | താഴ്ന്നു — ശ്രദ്ധിക്കുക',
        color: AppTheme.priceDownColor,
      );
    }
    return null;
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppTheme.stableColor),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
