import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/event_log.dart';

/// Calls the Google Gemini API to generate a 2-paragraph plain-English
/// summary of the user's week, intended to sit at the top of the
/// PDF export their therapist reads.
///
/// Why Gemini for the hackathon: free tier (no credit card required —
/// though EU accounts may need a billing account attached to satisfy
/// region rules), gemini-2.5-flash gives 10 RPM / 250 RPD which is
/// plenty for a demo, and the 2-paragraph output is comfortably within
/// the model's strengths.
///
/// Privacy note: the free tier MAY use prompts/responses to improve
/// Google's models. We send aggregated stats (counts, hours, object
/// names) — no raw timestamps and no UID. For a hackathon demo that's
/// fine; in prod you'd want a paid tier with the data-use opt-out
/// or a backend proxy that handles policy.
///
/// Key handling: read at compile time via
/// `--dart-define=GEMINI_API_KEY=...`. If the key isn't set the service
/// returns null and the export proceeds without a summary.
class LlmService {
  static const _apiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const _model = 'gemini-2.5-flash';
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  bool get isConfigured => _apiKey.isNotEmpty;

  /// Generates the summary text. Returns null on any failure
  /// (no key, network error, timeout, malformed response, content
  /// blocked by safety filters). Callers should treat null as
  /// "skip this section".
  Future<String?> generateSummary(LlmReportContext ctx) async {
    if (!isConfigured) return null;

    final body = jsonEncode({
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': _userPrompt(ctx)},
          ],
        },
      ],
      'systemInstruction': {
        'parts': [
          {'text': _systemPrompt},
        ],
      },
      'generationConfig': {
        'maxOutputTokens': 600,
        'temperature': 0.7,
      },
    });

    try {
      final res = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'x-goog-api-key': _apiKey,
              'content-type': 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 20));

      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;

      // Gemini response shape:
      // { "candidates": [ { "content": { "parts": [ {"text": "..."} ] } } ] }
      // Safety blocks come back with no parts and a finishReason of
      // SAFETY/RECITATION/etc — we treat all of those as "no summary".
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return null;
      final content = candidates.first['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List?;
      if (parts == null || parts.isEmpty) return null;
      final text = parts.first['text'] as String?;
      return text?.trim();
    } catch (_) {
      return null;
    }
  }

  // --- prompt --------------------------------------------------------

  static const _systemPrompt = '''
You are writing a brief summary for a therapist to read alongside their patient's self-tracked behavioral data. The patient tracks checking anxiety: they tag household objects (door, stove, iron) and scan them when they physically check. The app also logs every app open — opens without a follow-up scan within 2 minutes suggest reassurance-seeking rather than real checking.

Write exactly 2 short paragraphs in plain conversational English. No headers, no bullet lists, no clinical or diagnostic language, no advice on techniques or interventions. Do not restate numbers the therapist will already see in the chart.

Paragraph 1: the most notable pattern this week — when the gap between opens and scans is widest, what time of day, whether the picture changed across the week.

Paragraph 2: one or two specific things worth a short conversation in the next session, grounded in the data (not in inferred motivation or feelings).

If the week's data is too sparse to support real observations, say so in one sentence and stop. Keep the whole response under 180 words.
''';

  static String _userPrompt(LlmReportContext ctx) {
    return 'Here is the data:\n\n${jsonEncode(ctx.toJson())}';
  }
}

// --- payload --------------------------------------------------------

/// Structured snapshot of the week, sent to the LLM. Stays in this file
/// so the service is self-contained — analytics_screen builds it from
/// the existing TrustScore / DailyStats / events it already has.
class LlmReportContext {
  LlmReportContext({
    required this.dateRange,
    required this.trustScore,
    required this.trustBand,
    required this.passiveOpens,
    required this.hoursSinceLastCheck,
    required this.clusteringEvents,
    required this.streakDays,
    required this.totalAppOpens,
    required this.totalTagScans,
    required this.daily,
    required this.peakHours,
    required this.topObjects,
  });

  final String dateRange;

  final double trustScore;
  final String trustBand;
  final int passiveOpens;
  final double hoursSinceLastCheck;
  final int clusteringEvents;
  final int streakDays;

  final int totalAppOpens;
  final int totalTagScans;

  final List<Map<String, Object>> daily;
  final List<Map<String, int>> peakHours;
  final List<Map<String, Object>> topObjects;

  Map<String, dynamic> toJson() => {
        'date_range': dateRange,
        'trust_score': {
          'value': trustScore.round(),
          'band': trustBand,
          'passive_opens': passiveOpens,
          'hours_since_last_check': double.parse(
            hoursSinceLastCheck.toStringAsFixed(1),
          ),
          'clustering_events': clusteringEvents,
          'streak_days': streakDays,
        },
        'totals': {
          'app_opens': totalAppOpens,
          'tag_scans': totalTagScans,
        },
        'daily': daily,
        'peak_hours': peakHours,
        'top_objects': topObjects,
      };
}

/// Counts tag_scans per objectId from the events list. Returned as a
/// list of {objectId, count} sorted by count descending.
List<MapEntry<String, int>> scansByObject(List<EventLog> events) {
  final counts = <String, int>{};
  for (final e in events) {
    if (e.type != EventType.tagScan) continue;
    final id = e.objectId;
    if (id == null) continue;
    counts[id] = (counts[id] ?? 0) + 1;
  }
  final sorted = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return sorted;
}