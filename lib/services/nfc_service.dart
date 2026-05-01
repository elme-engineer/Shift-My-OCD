import 'package:flutter/foundation.dart';
import 'package:nfc_manager/nfc_manager.dart';

/// Thin wrapper around `nfc_manager` for reading tag identifiers.
///
/// We use the tag's hardware identifier (UID) as the canonical
/// `tagId` and look up TrackedObjects by it. Writing data ONTO
/// NFC tags is intentionally out of scope for the hackathon —
/// pre-program tags' UIDs into the app, or use the QR demo path.
///
/// API target: nfc_manager ^3.x (the current stable on pub).
/// If you upgrade to 4.x the session API moves to pollingOptions.
class NfcService {
  /// Whether the device has NFC and it's switched on.
  Future<bool> isAvailable() async {
    try {
      return await NfcManager.instance.isAvailable();
    } catch (_) {
      return false;
    }
  }

  /// Starts a session, calls [onTagId] with the first tag's UID,
  /// then auto-stops. Always pair this with [stop] in your widget's
  /// dispose to clean up if the user backs out before scanning.
  Future<void> startSession({
    required void Function(String tagId) onTagId,
    void Function(Object error)? onError,
  }) async {
    try {
      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          final id = _extractIdentifier(tag);
          await NfcManager.instance.stopSession();
          if (id != null) onTagId(id);
        },
      );
    } catch (e) {
      if (kDebugMode) print('NFC startSession error: $e');
      if (onError != null) onError(e);
    }
  }

  Future<void> stop() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {
      // session may already be stopped — safe to ignore
    }
  }

  /// Pulls the tag UID out of whichever tech the tag exposes.
  /// nfc_manager surfaces tech-specific keys on `tag.data`.
  String? _extractIdentifier(NfcTag tag) {
    final data = tag.data;
    const techKeys = [
      'nfca',
      'nfcb',
      'nfcf',
      'nfcv',
      'mifareclassic',
      'mifareultralight',
      'isodep',
    ];
    for (final key in techKeys) {
      final tech = data[key];
      if (tech is Map && tech['identifier'] is List) {
        final bytes = (tech['identifier'] as List).cast<int>();
        return bytes
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join();
      }
    }
    return null;
  }
}