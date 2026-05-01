import 'dart:convert';

/// Encodes/decodes the QR payload for a tagged object.
///
/// Wire format:
///   {"app":"shiftmyocd","objectId":"obj_abc123","v":1}
///
/// The `app` field lets the scanner reject unrelated QR codes
/// (Wi-Fi configs, contact cards, random URLs).
class QrService {
  static const _appTag = 'shiftmyocd';
  static const _version = 1;

  /// Builds the JSON string to embed in a QR code via qr_flutter.
  String encode(String objectId) {
    return jsonEncode({
      'app': _appTag,
      'objectId': objectId,
      'v': _version,
    });
  }

  /// Tries to extract an objectId from a scanned QR payload.
  /// Returns null if the payload isn't ours, malformed, or empty.
  String? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      if (decoded['app'] != _appTag) return null;
      final id = decoded['objectId'];
      return (id is String && id.isNotEmpty) ? id : null;
    } catch (_) {
      return null;
    }
  }
}