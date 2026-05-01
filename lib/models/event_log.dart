import 'package:cloud_firestore/cloud_firestore.dart';

enum EventType { appOpen, tagScan }

extension EventTypeX on EventType {
  String get wire => switch (this) {
        EventType.appOpen => 'app_open',
        EventType.tagScan => 'tag_scan',
      };

  static EventType fromWire(String? raw) => switch (raw) {
        'tag_scan' => EventType.tagScan,
        _ => EventType.appOpen,
      };
}

/// An append-only entry in the user's event log.
///
/// Stored at: `users/{userId}/events/{eventId}`
///
/// `hourOfDay`, `dayOfWeek`, and `dateKey` are denormalised onto every
/// document so client-side aggregation (trust score, daily charts) can
/// run without re-deriving them per record.
class EventLog {
  EventLog({
    required this.id,
    required this.type,
    required this.timestamp,
    this.objectId,
    this.source,
  });

  final String id;
  final EventType type;
  final DateTime timestamp;

  /// Present for `tag_scan`; null for `app_open`.
  final String? objectId;

  /// "nfc" | "qr" | null. Null for `app_open`.
  final String? source;

  int get hourOfDay => timestamp.hour;

  /// 1 = Mon ... 7 = Sun (matches DateTime.weekday).
  int get dayOfWeek => timestamp.weekday;

  /// "YYYY-MM-DD" in local time so daily aggregation lines up
  /// with the user's day, not UTC.
  String get dateKey => dateKeyOf(timestamp);

  static String dateKeyOf(DateTime t) {
    final y = t.year.toString().padLeft(4, '0');
    final m = t.month.toString().padLeft(2, '0');
    final d = t.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  factory EventLog.fromMap(String id, Map<String, dynamic> map) {
    final ts = map['timestamp'];
    final dt = ts is Timestamp ? ts.toDate() : DateTime.now();
    return EventLog(
      id: id,
      type: EventTypeX.fromWire(map['type'] as String?),
      timestamp: dt,
      objectId: map['objectId'] as String?,
      source: map['source'] as String?,
    );
  }

  factory EventLog.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) =>
      EventLog.fromMap(doc.id, doc.data() ?? const {});

  Map<String, dynamic> toMap() {
    return {
      'type': type.wire,
      'objectId': objectId,
      'source': source,
      'timestamp': Timestamp.fromDate(timestamp),
      'hourOfDay': hourOfDay,
      'dayOfWeek': dayOfWeek,
      'dateKey': dateKey,
    };
  }
}