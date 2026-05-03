import 'package:firebase_auth/firebase_auth.dart';

/// Thin wrapper around FirebaseAuth that ensures we have an
/// anonymous user as soon as the app starts. Everything else
/// in the app reads `currentUid` and assumes a user exists.
class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  String? get currentUid => _auth.currentUser?.uid;

  /// Stream of UID changes — useful for gating navigation
  /// or rebuilding the root widget once auth lands.
  Stream<String?> get uidChanges => _auth.userChanges().map((u) => u?.uid);

  /// Signs in anonymously if there's no user. Idempotent —
  /// safe to call on every cold start. Returns the UID.
  Future<String> ensureSignedIn() async {
    final existing = _auth.currentUser;
    if (existing != null) return existing.uid;
    final cred = await _auth.signInAnonymously();
    return cred.user!.uid;
  }
}