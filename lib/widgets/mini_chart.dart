import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/product_model.dart';
import '../theme/app_theme.dart';

class MiniChart extends StatelessWidget {
  const MiniChart({super.key, required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    final history = product.weekHistory;
    if (history.isEmpty) {
      return const SizedBox(height: 40);
    }

    final lineColor = product.isUp
        ? AppTheme.priceUpColor
        : product.isDown
            ? AppTheme.priceDownColor
            : AppTheme.stableColor;

    final spots = List<FlSpot>.generate(
      history.length,
      (i) => FlSpot(i.toDouble(), history[i]),
    );

    final minY = history.reduce((a, b) => a < b ? a : b);
    final maxY = history.reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) * 0.15 + 1;

    return SizedBox(
      height: 40,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (history.length - 1).toDouble(),
          minY: minY - padding,
          maxY: maxY + padding,
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: lineColor,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: lineColor.withValues(alpha: 0.08),
              ),
            ),
          ],
        ),
        duration: Duration.zero,
      ),
    );
  }
}
