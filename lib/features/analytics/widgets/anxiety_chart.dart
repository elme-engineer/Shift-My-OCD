import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../models/daily_stats.dart';

/// Grouped bar chart: app_opens (anxiety) vs tag_scans (real checks)
/// over the last 7 days. Highlighting the gap is the whole point —
/// when the orange bars (opens) tower over the blue bars (scans),
/// the user is opening the app to look at status without checking.
class AnxietyChart extends StatelessWidget {
  const AnxietyChart({super.key, required this.statsByDay});

  /// Map of dateKey ("YYYY-MM-DD") -> DailyStats. May be partial —
  /// missing days are rendered as zero bars.
  final Map<String, DailyStats> statsByDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = _last7Days();
    final groups = <BarChartGroupData>[];
    var maxY = 1.0;

    for (var i = 0; i < days.length; i++) {
      final key = days[i];
      final s = statsByDay[key];
      final opens = (s?.appOpens ?? 0).toDouble();
      final scans = (s?.tagScans ?? 0).toDouble();
      if (opens > maxY) maxY = opens;
      if (scans > maxY) maxY = scans;

      groups.add(BarChartGroupData(
        x: i,
        barsSpace: 4,
        barRods: [
          BarChartRodData(
            toY: opens,
            color: theme.colorScheme.tertiary,
            width: 10,
            borderRadius: BorderRadius.circular(4),
          ),
          BarChartRodData(
            toY: scans,
            color: theme.colorScheme.primary,
            width: 10,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ));
    }

    // Round maxY up to the next multiple of 5 for nicer gridlines.
    maxY = ((maxY / 5).ceil() * 5).toDouble().clamp(5.0, double.infinity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _LegendDot(color: theme.colorScheme.tertiary, label: 'Opens'),
            const SizedBox(width: AppSpacing.md),
            _LegendDot(color: theme.colorScheme.primary, label: 'Scans'),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              maxY: maxY,
              alignment: BarChartAlignment.spaceAround,
              barGroups: groups,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY / 4,
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: maxY / 4,
                    getTitlesWidget: (v, _) => Text(
                      v.toInt().toString(),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= days.length) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _shortWeekday(days[i]),
                          style: theme.textTheme.bodySmall,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Returns the last 7 dateKeys ending today (oldest first).
  static List<String> _last7Days() {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
    });
  }

  static String _shortWeekday(String dateKey) {
    final parts = dateKey.split('-').map(int.parse).toList();
    final d = DateTime(parts[0], parts[1], parts[2]);
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[d.weekday - 1];
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}