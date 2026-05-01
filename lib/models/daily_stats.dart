import 'package:cloud_firestore/cloud_firestore.dart';

import 'event_log.dart';

/// Per-day rollup of the user's activity.
///
/// Stored at: `users/{userId}/dailyStats/{YYYY-MM-DD}`
///
/// For the hackathon we aggregate client-side and (optionally) cache
/// here. Rendering the analytics screen does NOT require these docs
/// to exist — they can be regenerated from the event log at any time.
class DailyStats {
  DailyStats({
    required this.dateKey,
    required this.appOpens,
    required this.tagScans,
    required this.peakHour,
    required this.hourly,
  });

  /// "YYYY-MM-DD" — also the document id.
  final String dateKey;
  final int appOpens;
  final int tagScans;

  /// Hour-of-day (0..23) with the most opens. -1 if no opens that day.
  final int peakHour;

  /// hour ("00".."23") -> { opens, scans }
  final Map<String, HourBucket> hourly;

  /// Aggregates a list of [events] (any range) into a map of
  /// dateKey -> DailyStats.
  static Map<String, DailyStats> aggregate(Iterable<EventLog> events) {
    final byDay = <String, _Accum>{};
    for (final e in events) {
      final acc = byDay.putIfAbsent(e.dateKey, _Accum.new);
      final hr = e.hourOfDay.toString().padLeft(2, '0');
      final bucket = acc.hourly.putIfAbsent(hr, HourBucket.empty);
      if (e.type == EventType.appOpen) {
        acc.opens++;
        acc.hourly[hr] = bucket.copyWith(opens: bucket.opens + 1);
      } else {
        acc.scans++;
        acc.hourly[hr] = bucket.copyWith(scans: bucket.scans + 1);
      }
    }
    return byDay.map((day, acc) {
      // Pick the hour with the most opens; ties go to the earliest.
      var peak = -1;
      var peakOpens = 0;
      for (final entry in acc.hourly.entries) {
        if (entry.value.opens > peakOpens) {
          peak = int.parse(entry.key);
          peakOpens = entry.value.opens;
        }
      }
      return MapEntry(
        day,
        DailyStats(
          dateKey: day,
          appOpens: acc.opens,
          tagScans: acc.scans,
          peakHour: peak,
          hourly: Map.unmodifiable(acc.hourly),
        ),
      );
    });
  }

  factory DailyStats.fromMap(String id, Map<String, dynamic> map) {
    final raw = (map['hourly'] as Map?) ?? const {};
    final hourly = <String, HourBucket>{};
    raw.forEach((k, v) {
      if (v is Map) {
        hourly[k as String] = HourBucket(
          opens: (v['opens'] as num?)?.toInt() ?? 0,
          scans: (v['scans'] as num?)?.toInt() ?? 0,
        );
      }
    });
    return DailyStats(
      dateKey: id,
      appOpens: (map['appOpens'] as num?)?.toInt() ?? 0,
      tagScans: (map['tagScans'] as num?)?.toInt() ?? 0,
      peakHour: (map['peakHour'] as num?)?.toInt() ?? -1,
      hourly: hourly,
    );
  }

  factory DailyStats.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) =>
      DailyStats.fromMap(doc.id, doc.data() ?? const {});

  Map<String, dynamic> toMap() {
    return {
      'appOpens': appOpens,
      'tagScans': tagScans,
      'peakHour': peakHour,
      'hourly': {
        for (final e in hourly.entries)
          e.key: {'opens': e.value.opens, 'scans': e.value.scans},
      },
    };
  }
}

class HourBucket {
  const HourBucket({required this.opens, required this.scans});
  factory HourBucket.empty() => const HourBucket(opens: 0, scans: 0);

  final int opens;
  final int scans;

  HourBucket copyWith({int? opens, int? scans}) =>
      HourBucket(opens: opens ?? this.opens, scans: scans ?? this.scans);
}

class _Accum {
  int opens = 0;
  int scans = 0;
  final Map<String, HourBucket> hourly = {};
}