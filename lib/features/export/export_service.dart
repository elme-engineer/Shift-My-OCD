import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/daily_stats.dart';
import '../../models/event_log.dart';
import '../analytics/analytics_screen.dart' show TrustScore;

/// Builds a single-page PDF report from the user's event log and
/// hands it to the system share sheet. Designed for the user to
/// email/airdrop to their therapist after a session.
///
/// We render the bar chart natively in pdf widgets (not by capturing
/// the on-screen fl_chart) so the report can be generated even from
/// background isolates if we ever need to.
class ExportService {
  Future<void> exportPdf({required List<EventLog> events}) async {
    final doc = pw.Document();
    final score = TrustScore.compute(events);
    final stats = DailyStats.aggregate(events);
    final peaks = _peakHours(events);

    final today = DateTime.now();
    final cutoff = today.subtract(const Duration(days: 6));
    final dateRange =
        '${DateFormat.yMMMd().format(cutoff)} – ${DateFormat.yMMMd().format(today)}';

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _header(dateRange),
            pw.SizedBox(height: 18),
            _scoreBlock(score),
            pw.SizedBox(height: 18),
            _chartBlock(stats),
            pw.SizedBox(height: 18),
            _peaksBlock(peaks),
            pw.Spacer(),
            _footer(),
          ],
        ),
      ),
    );

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'shift-my-ocd-${EventLog.dateKeyOf(today)}.pdf',
    );
  }

  // --- header ---

  static pw.Widget _header(String dateRange) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Shift My OCD — checking report',
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          dateRange,
          style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
        ),
        pw.Divider(),
      ],
    );
  }

  // --- trust score block ---

  static pw.Widget _scoreBlock(TrustScore score) {
    PdfColor color;
    if (score.value >= 70) {
      color = PdfColors.green600;
    } else if (score.value >= 40) {
      color = PdfColors.amber700;
    } else {
      color = PdfColors.red600;
    }
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Trust score',
                  style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
              pw.SizedBox(height: 2),
              pw.Text(
                '${score.value.toStringAsFixed(0)} / 100',
                style: pw.TextStyle(
                  fontSize: 32,
                  fontWeight: pw.FontWeight.bold,
                  color: color,
                ),
              ),
              pw.Text(score.band,
                  style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
            ],
          ),
          pw.SizedBox(width: 32),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _statRow('Passive opens', '${score.passiveOpens}'),
                _statRow('Hours since last check',
                    score.hoursSinceLastTap.toStringAsFixed(1)),
                _statRow('Tap clustering events', '${score.tapClustering}'),
                _statRow('Streak (days)', '${score.streakDays}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _statRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 11)),
          pw.Text(value,
              style:
                  pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  // --- chart block ---

  static pw.Widget _chartBlock(Map<String, DailyStats> stats) {
    final days = _last7Days();
    var maxVal = 1;
    for (final k in days) {
      final s = stats[k];
      if (s == null) continue;
      if (s.appOpens > maxVal) maxVal = s.appOpens;
      if (s.tagScans > maxVal) maxVal = s.tagScans;
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Last 7 days — opens vs scans',
            style:
                pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Container(
          height: 140,
          padding: const pw.EdgeInsets.symmetric(horizontal: 4),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              for (final key in days)
                _dayColumn(stats[key], maxVal, key),
            ],
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Row(
          children: [
            _legendDot(PdfColors.orange400, 'Opens'),
            pw.SizedBox(width: 12),
            _legendDot(PdfColors.blue600, 'Scans'),
          ],
        ),
      ],
    );
  }

  static pw.Widget _dayColumn(DailyStats? s, int maxVal, String dateKey) {
    final opens = s?.appOpens ?? 0;
    final scans = s?.tagScans ?? 0;
    final scale = 100.0 / maxVal;
    return pw.Column(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Container(
              width: 10,
              height: opens * scale,
              color: PdfColors.orange400,
            ),
            pw.SizedBox(width: 2),
            pw.Container(
              width: 10,
              height: scans * scale,
              color: PdfColors.blue600,
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Text(_shortWeekday(dateKey),
            style: const pw.TextStyle(fontSize: 9)),
      ],
    );
  }

  static pw.Widget _legendDot(PdfColor color, String label) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(width: 8, height: 8, color: color),
        pw.SizedBox(width: 4),
        pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  // --- peak hours ---

  static pw.Widget _peaksBlock(List<MapEntry<int, int>> peaks) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Anxiety peak hours',
            style:
                pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        if (peaks.isEmpty)
          pw.Text('Not enough data yet.',
              style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700))
        else
          pw.Column(
            children: peaks.map((e) {
              final next = (e.key + 1) % 24;
              return pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      '${e.key.toString().padLeft(2, '0')}:00 – '
                      '${next.toString().padLeft(2, '0')}:00',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                    pw.Text('${e.value} opens',
                        style: pw.TextStyle(
                            fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  // --- footer ---

  static pw.Widget _footer() {
    return pw.Text(
      'Generated by Shift My OCD on '
      '${DateFormat.yMMMd().add_jm().format(DateTime.now())}',
      style: pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
    );
  }

  // --- helpers ---

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

  static List<String> _last7Days() {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return EventLog.dateKeyOf(d);
    });
  }

  static String _shortWeekday(String dateKey) {
    final parts = dateKey.split('-').map(int.parse).toList();
    final d = DateTime(parts[0], parts[1], parts[2]);
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[d.weekday - 1];
  }
}