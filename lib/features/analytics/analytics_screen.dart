import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/daily_stats.dart';
import '../../models/event_log.dart';
import '../../services/analytics_service.dart';
import '../export/export_service.dart';
import 'widgets/anxiety_chart.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _analytics = AnalyticsService();
  final _export = ExportService();
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          IconButton(
            tooltip: 'Export PDF',
            icon: _exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _exporting ? null : _onExport,
          ),
        ],
      ),
      body: StreamBuilder<List<EventLog>>(
        stream: _analytics.watchEvents(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final events = snap.data!;
          final score = TrustScore.compute(events);
          final stats = DailyStats.aggregate(events);
          final peaks = _peakHours(events);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ScoreCard(score: score),
                const SizedBox(height: AppSpacing.md),
                _ChartCard(stats: stats),
                const SizedBox(height: AppSpacing.md),
                _PeakHoursCard(peaks: peaks),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _onExport() async {
    setState(() => _exporting = true);
    try {
      final events =
          await _analytics.watchEvents().first; // current snapshot
      await _export.exportPdf(events: events);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Export failed: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// Top 3 hours-of-day with the most app_opens. Used to surface
  /// "your anxiety peaks at 11pm and 7am" in the report.
  static List<MapEntry<int, int>> _peakHours(List<EventLog> events) {
    final byHour = <int, int>{};
    for (final e in events) {
      if (e.type != EventType.appOpen) continue;
      byHour[e.hourOfDay] = (byHour[e.hourOfDay] ?? 0) + 1;
    }
    final sorted = byHour.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(3).toList();
  }
}

// --- score -----------------------------------------------------------

/// Headline metric. Computed in-memory from the raw event log per the
/// hackathon spec:
///
///   trust_score = 50
///     - (passive_opens × 5)        // app opens with no scan within 2m
///     + (time_since_last_tap × 0.1) // hours since last scan, capped at 24
///     - (tap_clustering × 3)        // same object scanned 2+ in 5m
///     + (streak_days × 2)           // consecutive days with ≥1 scan
///   clamp(0, 100)
class TrustScore {
  TrustScore({
    required this.value,
    required this.passiveOpens,
    required this.hoursSinceLastTap,
    required this.tapClustering,
    required this.streakDays,
  });

  final double value;
  final int passiveOpens;
  final double hoursSinceLastTap;
  final int tapClustering;
  final int streakDays;

  String get band => value >= 70
      ? 'Strong'
      : value >= 40
          ? 'Building'
          : 'Wobbly';

  /// [events] is expected newest-first (matches AnalyticsService).
  factory TrustScore.compute(List<EventLog> events) {
    final asc = events.reversed.toList();

    // passive_opens: app_opens with no tag_scan within +2 min
    var passive = 0;
    for (var i = 0; i < asc.length; i++) {
      final e = asc[i];
      if (e.type != EventType.appOpen) continue;
      final cutoff = e.timestamp.add(const Duration(minutes: 2));
      var followed = false;
      for (var j = i + 1; j < asc.length; j++) {
        if (asc[j].timestamp.isAfter(cutoff)) break;
        if (asc[j].type == EventType.tagScan) {
          followed = true;
          break;
        }
      }
      if (!followed) passive++;
    }

    // time_since_last_tap: hours since most recent tag_scan, cap 24
    final lastScan = events.cast<EventLog?>().firstWhere(
          (e) => e!.type == EventType.tagScan,
          orElse: () => null,
        );
    final hoursRaw = lastScan == null
        ? 24.0
        : DateTime.now().difference(lastScan.timestamp).inMinutes / 60.0;
    final hours = hoursRaw.clamp(0.0, 24.0);

    // tap_clustering: same objectId scanned 2+ times in any 5-min window
    var clustering = 0;
    final scans = asc.where((e) => e.type == EventType.tagScan).toList();
    for (var i = 0; i < scans.length; i++) {
      for (var j = i + 1; j < scans.length; j++) {
        final dt = scans[j].timestamp.difference(scans[i].timestamp);
        if (dt.inMinutes > 5) break;
        if (scans[i].objectId == scans[j].objectId) clustering++;
      }
    }

    // streak_days: consecutive days ending today with ≥1 tag_scan
    final scanDays = scans.map((e) => e.dateKey).toSet();
    var streak = 0;
    var day = DateTime.now();
    while (true) {
      final key = EventLog.dateKeyOf(day);
      if (!scanDays.contains(key)) break;
      streak++;
      day = day.subtract(const Duration(days: 1));
    }

    final raw = 50.0 -
        (passive * 5) +
        (hours * 0.1) -
        (clustering * 3) +
        (streak * 2);
    return TrustScore(
      value: raw.clamp(0.0, 100.0),
      passiveOpens: passive,
      hoursSinceLastTap: hours,
      tapClustering: clustering,
      streakDays: streak,
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.score});
  final TrustScore score;

  Color _color(BuildContext ctx) {
    final scheme = Theme.of(ctx).colorScheme;
    if (score.value >= 70) return scheme.primary;
    if (score.value >= 40) return scheme.tertiary;
    return scheme.error;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _color(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trust score', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  score.value.toStringAsFixed(0),
                  style: theme.textTheme.displayMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '/ 100   ${score.band}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: score.value / 100,
                minHeight: 8,
                backgroundColor: color.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.sm,
              children: [
                _Stat(label: 'Passive opens', value: '${score.passiveOpens}'),
                _Stat(label: 'Streak', value: '${score.streakDays} d'),
                _Stat(label: 'Clustering', value: '${score.tapClustering}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: theme.textTheme.titleMedium),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.stats});
  final Map<String, DailyStats> stats;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm),
              child: Text(
                'Last 7 days',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AnxietyChart(statsByDay: stats),
          ],
        ),
      ),
    );
  }
}

class _PeakHoursCard extends StatelessWidget {
  const _PeakHoursCard({required this.peaks});
  final List<MapEntry<int, int>> peaks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Anxiety peak hours', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            if (peaks.isEmpty)
              Text(
                'Not enough data yet.',
                style: theme.textTheme.bodySmall,
              )
            else
              ...peaks.map(
                (e) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time),
                  title: Text(_formatHour(e.key)),
                  trailing: Text('${e.value} opens'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _formatHour(int h) {
    final next = (h + 1) % 24;
    String fmt(int x) => '${x.toString().padLeft(2, '0')}:00';
    return '${fmt(h)} – ${fmt(next)}';
  }
}