import 'dart:math';

import 'package:cryptography/cryptography.dart';

import 'b64.dart';

/// Derivación PBKDF2-HMAC-SHA256 con sal aleatoria para el PIN de administrador.
class PinHasher {
  PinHasher._();
  static const _iterations = 60000;

  static List<int> newSalt() {
    final r = Random.secure();
    return List<int>.generate(16, (_) => r.nextInt(256));
  }

  static Future<String> hash(String pin, List<int> salt) async {
    final pbkdf2 = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: _iterations, bits: 256);
    final key = await pbkdf2.deriveKeyFromPassword(password: pin, nonce: salt);
    return B64.encode(await key.extractBytes());
  }

  /// Comparación en tiempo constante.
  static bool safeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
