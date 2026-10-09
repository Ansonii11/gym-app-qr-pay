import 'dart:convert';

import 'b64.dart';
import 'key_manager.dart';

/// Formato de QR firmado: `GPC1.<payload base64url>.<firma base64url>`.
/// La firma Ed25519 cubre el texto exacto del payload codificado.
class SignedQr {
  SignedQr._();

  static const prefix = 'GPC1';

  static Future<String> encode(Map<String, dynamic> payload, KeyManager keys) async {
    final body = B64.encode(utf8.encode(jsonEncode(payload)));
    final sig = await keys.sign(utf8.encode(body));
    return '$prefix.$body.${B64.encode(sig)}';
  }

  /// Decodifica sin verificar. Devuelve null si el formato es inválido.
  static ParsedQr? parse(String raw) {
    final parts = raw.trim().split('.');
    if (parts.length != 3 || parts[0] != prefix) return null;
    try {
      final json = jsonDecode(utf8.decode(B64.decode(parts[1])));
      if (json is! Map<String, dynamic>) return null;
      return ParsedQr(parts[1], B64.decode(parts[2]), json);
    } catch (_) {
      return null;
    }
  }
}

class ParsedQr {
  ParsedQr(this._body, this._signature, this.payload);

  final String _body;
  final List<int> _signature;
  final Map<String, dynamic> payload;

  String? get type => payload['t'] as String?;

  Future<bool> verifyWith(String publicKeyB64) =>
      KeyManager.verify(utf8.encode(_body), _signature, publicKeyB64);
}
