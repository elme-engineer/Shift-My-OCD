import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../models/event_log.dart';
import '../models/tracked_object.dart';

/// Reads/writes the user's event log AND owns the tracked-objects
/// collection (kept here so the lifecycle observer + scan screens
/// depend on a single service rather than two).
///
/// All client-side aggregation (trust score, daily charts, peak
/// hours) happens in the analytics screen against [watchEvents].
class AnalyticsService {
  AnalyticsService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    Uuid? uuid,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _uuid = uuid ?? const Uuid();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Uuid _uuid;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? get _eventsRef {
    final uid = _uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('events');
  }

  CollectionReference<Map<String, dynamic>>? get _objectsRef {
    final uid = _uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('objects');
  }

  // --- events --------------------------------------------------------

  Future<void> logAppOpen() async {
    final ref = _eventsRef;
    if (ref == null) return;
    final event = EventLog(
      id: '',
      type: EventType.appOpen,
      timestamp: DateTime.now(),
    );
    await ref.add(event.toMap());
  }

  Future<void> logTagScan({
    required String objectId,
    required String source, // "qr" | "nfc"
  }) async {
    final eventsRef = _eventsRef;
    final objectRef = _objectsRef?.doc(objectId);
    if (eventsRef == null || objectRef == null) return;

    final now = DateTime.now();
    final event = EventLog(
      id: '',
      type: EventType.tagScan,
      timestamp: now,
      objectId: objectId,
      source: source,
    );

    await Future.wait([
      eventsRef.add(event.toMap()),
      objectRef.set(
        {'lastCheckedAt': Timestamp.fromDate(now)},
        SetOptions(merge: true),
      ),
    ]);
  }

  Stream<List<EventLog>> watchEvents({int limit = 1000}) {
    final ref = _eventsRef;
    if (ref == null) return const Stream.empty();
    return ref
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(EventLog.fromSnapshot).toList());
  }

  // --- objects -------------------------------------------------------

  Stream<List<TrackedObject>> watchObjects() {
    final ref = _objectsRef;
    if (ref == null) return const Stream.empty();
    return ref
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(TrackedObject.fromSnapshot).toList());
  }

  Future<TrackedObject?> findByTagId(String tagId) async {
    final ref = _objectsRef;
    if (ref == null) return null;
    final direct = await ref.doc(tagId).get();
    if (direct.exists) return TrackedObject.fromSnapshot(direct);
    final q = await ref.where('tagId', isEqualTo: tagId).limit(1).get();
    if (q.docs.isEmpty) return null;
    return TrackedObject.fromSnapshot(q.docs.first);
  }

  /// Creates a new tracked object. [description] is optional — pass
  /// an empty string when the user leaves the field blank.
  Future<TrackedObject> createObject({
    required String name,
    required String iconKey,
    String description = '',
    String tagType = 'qr',
    String? predefinedTagId,
  }) async {
    final ref = _objectsRef;
    if (ref == null) throw StateError('Not signed in');
    final id = predefinedTagId ??
        'obj_${_uuid.v4().replaceAll('-', '').substring(0, 12)}';
    final obj = TrackedObject(
      id: id,
      name: name.trim(),
      description: description.trim(),
      iconKey: iconKey,
      tagId: id,
      tagType: tagType,
      createdAt: DateTime.now(),
    );
    await ref.doc(id).set(obj.toMap());
    return obj;
  }

  /// Updates the editable fields of an existing object.
  Future<void> updateObject({
    required String objectId,
    String? name,
    String? description,
    String? iconKey,
  }) async {
    final ref = _objectsRef?.doc(objectId);
    if (ref == null) return;
    await ref.set({
      if (name != null) 'name': name.trim(),
      if (description != null) 'description': description.trim(),
      if (iconKey != null) 'icon': iconKey,
    }, SetOptions(merge: true));
  }

  Future<void> attachNfcTag({
    required String objectId,
    required String nfcTagId,
  }) async {
    await _objectsRef?.doc(objectId).set(
      {'tagId': nfcTagId, 'tagType': 'nfc'},
      SetOptions(merge: true),
    );
  }

  Future<void> deleteObject(String objectId) async {
    await _objectsRef?.doc(objectId).delete();
  }
}