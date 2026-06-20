import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class PriceChart extends StatelessWidget {
  const PriceChart({
    super.key,
    required this.history,
    this.height = 200,
    this.showYLabels = true,
  });

  final List<double> history;
  final double height;
  final bool showYLabels;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return SizedBox(height: height);
    }

    final minY = history.reduce((a, b) => a < b ? a : b);
    final maxY = history.reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) * 0.12 + 2;

    final spots = List<FlSpot>.generate(
      history.length,
      (i) => FlSpot(i.toDouble(), history[i]),
    );

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (history.length - 1).toDouble(),
          minY: minY - padding,
          maxY: maxY + padding,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxY - minY) / 4,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.black.withValues(alpha: 0.06),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: showYLabels,
                reservedSize: 44,
                getTitlesWidget: (value, meta) {
                  if (!showYLabels) return const SizedBox.shrink();
                  if (value == meta.min || value == meta.max) {
                    return Text(
                      '₹${value.round()}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.stableColor,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: true),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppTheme.primaryColor,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppTheme.primaryColor.withValues(alpha: 0.2),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 250),
      ),
    );
  }
}
