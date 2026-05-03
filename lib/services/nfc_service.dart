import 'package:flutter/foundation.dart';
import 'package:nfc_manager/nfc_manager.dart';

class NfcService {
  /// Whether the device has NFC and it's switched on.
  Future<bool> isAvailable() async {
    try {
      return await NfcManager.instance.isAvailable();
    } catch (_) {
      return false;
    }
  }

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