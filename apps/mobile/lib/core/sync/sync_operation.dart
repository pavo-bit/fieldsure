import 'dart:convert';

/// Helper for encoding/decoding sync operation payloads.
class SyncOperation {
  static String encodePayload(Map<String, dynamic> payload) {
    return jsonEncode(payload);
  }

  static Map<String, dynamic> decodePayload(String payloadJson) {
    return jsonDecode(payloadJson) as Map<String, dynamic>;
  }
}
