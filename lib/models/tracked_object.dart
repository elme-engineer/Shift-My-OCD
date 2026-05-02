import 'package:cloud_firestore/cloud_firestore.dart';

/// A real-world object the user has tagged for checking
/// (e.g. front door, stove knob, iron).
///
/// Stored at: `users/{userId}/objects/{objectId}`
class TrackedObject {
  TrackedObject({
    required this.id,
    required this.name,
    required this.description,
    required this.iconKey,
    required this.tagId,
    required this.tagType,
    required this.createdAt,
    this.lastCheckedAt,
  });

  /// Firestore document id. We keep this == [tagId] for QR objects so
  /// scanner -> Firestore lookup is a single read.
  final String id;
  final String name;

  /// Free-form notes — e.g. "main lock + deadbolt", reminders to
  /// the user about what to actually look for. May be empty;
  /// the UI hides the row when blank rather than rendering placeholder.
  final String description;

  /// Key into the icon catalog. Stored as a string (not an IconData
  /// codePoint) so Flutter's icon tree-shaker stays happy in release.
  final String iconKey;

  /// Identifier embedded in the QR code or read from the NFC tag.
  /// QR: a uuid generated at creation. NFC: the tag's serial.
  final String tagId;

  /// "qr" | "nfc". Defaults to "qr" — QR is the demo path.
  final String tagType;

  final DateTime createdAt;

  /// Updated by AnalyticsService.logTagScan so the objects list can
  /// render "checked 5m ago" off the existing object stream.
  final DateTime? lastCheckedAt;

  factory TrackedObject.fromMap(String id, Map<String, dynamic> map) {
    return TrackedObject(
      id: id,
      name: (map['name'] as String?) ?? 'Untitled',
      // Empty default — the UI decides whether to render placeholder copy.
      description: (map['description'] as String?) ?? '',
      iconKey: (map['icon'] as String?) ?? 'home',
      tagId: (map['tagId'] as String?) ?? id,
      tagType: (map['tagType'] as String?) ?? 'qr',
      createdAt: _toDate(map['createdAt']) ?? DateTime.now(),
      lastCheckedAt: _toDate(map['lastCheckedAt']),
    );
  }

  factory TrackedObject.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) =>
      TrackedObject.fromMap(doc.id, doc.data() ?? const {});

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'icon': iconKey,
      'tagId': tagId,
      'tagType': tagType,
      'createdAt': Timestamp.fromDate(createdAt),
      if (lastCheckedAt != null)
        'lastCheckedAt': Timestamp.fromDate(lastCheckedAt!),
    };
  }

  TrackedObject copyWith({
    String? name,
    String? description,
    String? iconKey,
    String? tagId,
    String? tagType,
    DateTime? lastCheckedAt,
  }) {
    return TrackedObject(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconKey: iconKey ?? this.iconKey,
      tagId: tagId ?? this.tagId,
      tagType: tagType ?? this.tagType,
      createdAt: createdAt,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
    );
  }

  static DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }
}