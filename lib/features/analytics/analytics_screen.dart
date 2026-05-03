import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/daily_stats.dart';
import '../../models/event_log.dart';
import '../../models/tracked_object.dart';
import '../../services/analytics_service.dart';
import '../../services/llm_service.dart';
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
  final _llm = LlmService();

  // Two-step status so the user knows what's slow and what isn't.
  // null = idle, "summary" = waiting on LLM, "pdf" = building PDF.
  String? _exportStage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: _exportStage == null
                ? 'Export PDF'
                : _exportStage == 'summary'
                    ? 'Writing summary…'
                    : 'Building PDF…',
            icon: _exportStage != null
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _exportStage != null ? null : _onExport,
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
          final peaks = _peakHoursFromEvents(events);

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

  /// Two-stage export:
  ///   1. Build the LLM context from current data and ask the model
  ///      for a 2-paragraph summary. Shows a "writing summary" toast.
  ///   2. Render and share the PDF (with or without the summary).
  ///
  /// If the LLM call fails (no key, network, etc.) we still export —
  /// the summary section just gets omitted from the PDF.
  Future<void> _onExport() async {
    setState(() => _exportStage = 'summary');

    try {
      // Snapshot current events (we re-read so we're not racing the stream).
      final events = await _analytics.watchEvents().first;
      final objects = await _analytics.watchObjects().first;

      String? summary;
      if (_llm.isConfigured) {
        final ctx = _buildLlmContext(events: events, objects: objects);
        summary = await _llm.generateSummary(ctx);
        if (summary == null && mounted) {
          // Surface the failure but keep going — therapist still gets the data.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Couldn\'t generate AI summary — exporting raw data only.',
              ),
            ),
          );
        }
      }

      if (mounted) setState(() => _exportStage = 'pdf');
      await _export.exportPdf(events: events, aiSummary: summary);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Export failed: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _exportStage = null);
    }
  }

  /// Builds the structured payload the LLM sees. Indexes objects by id
  LlmReportContext _buildLlmContext({
    required List<EventLog> events,
    required List<TrackedObject> objects,
  }) {
    final score = TrustScore.compute(events);
    final stats = DailyStats.aggregate(events);

    // Last 7 days, oldest first — so the model sees the trend.
    final today = DateTime.now();
    final daysOldestFirst = List.generate(7, (i) {
      final d = today.subtract(Duration(days: 6 - i));
      return EventLog.dateKeyOf(d);
    });
    final daily = <Map<String, Object>>[];
    var totalOpens = 0;
    var totalScans = 0;
    for (final key in daysOldestFirst) {
      final s = stats[key];
      final opens = s?.appOpens ?? 0;
      final scans = s?.tagScans ?? 0;
      totalOpens += opens;
      totalScans += scans;
      daily.add({
        'day': _shortWeekday(key),
        'opens': opens,
        'scans': scans,
      });
    }

    // Peak hours
    final peaks = _peakHoursFromEvents(events).take(3).map((e) {
      return {'hour': e.key, 'opens': e.value};
    }).toList();

    // Top objects by scan count (with name lookup, deleted ones omitted)
    final byId = {for (final o in objects) o.id: o};
    final topObjects = scansByObject(events).take(5).where((e) {
      return byId.containsKey(e.key);
    }).map((e) {
      return <String, Object>{
        'name': byId[e.key]!.name,
        'scans': e.value,
      };
    }).toList();

    final cutoff = today.subtract(const Duration(days: 6));
    return LlmReportContext(
      dateRange:
          '${EventLog.dateKeyOf(cutoff)} to ${EventLog.dateKeyOf(today)}',
      trustScore: score.value,
      trustBand: score.band,
      passiveOpens: score.passiveOpens,
      hoursSinceLastCheck: score.hoursSinceLastTap,
      clusteringEvents: score.tapClustering,
      streakDays: score.streakDays,
      totalAppOpens: totalOpens,
      totalTagScans: totalScans,
      daily: daily,
      peakHours: peaks,
      topObjects: topObjects,
    );
  }

  static List<MapEntry<int, int>> _peakHoursFromEvents(List<EventLog> events) {
    final byHour = <int, int>{};
    for (final e in events) {
      if (e.type != EventType.appOpen) continue;
      byHour[e.hourOfDay] = (byHour[e.hourOfDay] ?? 0) + 1;
    }
    final sorted = byHour.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted;
  }

  static String _shortWeekday(String dateKey) {
    final parts = dateKey.split('-').map(int.parse).toList();
    final d = DateTime(parts[0], parts[1], parts[2]);
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[d.weekday - 1];
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

    final lastScan = events.cast<EventLog?>().firstWhere(
          (e) => e!.type == EventType.tagScan,
          orElse: () => null,
        );
    final hoursRaw = lastScan == null
        ? 24.0
        : DateTime.now().difference(lastScan.timestamp).inMinutes / 60.0;
    final hours = hoursRaw.clamp(0.0, 24.0);

    var clustering = 0;
    final scans = asc.where((e) => e.type == EventType.tagScan).toList();
    for (var i = 0; i < scans.length; i++) {
      for (var j = i + 1; j < scans.length; j++) {
        final dt = scans[j].timestamp.difference(scans[i].timestamp);
        if (dt.inMinutes > 5) break;
        if (scans[i].objectId == scans[j].objectId) clustering++;
      }
    }

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
    final top = peaks.take(3).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Anxiety peak hours', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            if (top.isEmpty)
              Text(
                'Not enough data yet.',
                style: theme.textTheme.bodySmall,
              )
            else
              ...top.map(
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