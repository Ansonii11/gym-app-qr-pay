import 'package:cryptography/cryptography.dart';

import '../storage/secure_store.dart';
import 'b64.dart';

/// Gestiona el par de claves Ed25519 del dispositivo.
/// La semilla privada vive solo en el almacén seguro; nunca sale del equipo.
class KeyManager {
  KeyManager(this._secure);

  final SecureStore _secure;
  final Ed25519 _algo = Ed25519();
  SimpleKeyPair? _keyPair;
  String? _publicKeyB64;

  Future<void> ensureKeys() async {
    if (_keyPair != null) return;
    var seedB64 = await _secure.read('ed25519_seed');
    SimpleKeyPair kp;
    if (seedB64 == null) {
      kp = await _algo.newKeyPair();
      seedB64 = B64.encode(await kp.extractPrivateKeyBytes());
      await _secure.write('ed25519_seed', seedB64);
    } else {
      kp = await _algo.newKeyPairFromSeed(B64.decode(seedB64));
    }
    _keyPair = kp;
    _publicKeyB64 = B64.encode((await kp.extractPublicKey()).bytes);
  }

  String get publicKey {
    final k = _publicKeyB64;
    if (k == null) throw StateError('Claves no inicializadas');
    return k;
  }

  Future<List<int>> sign(List<int> message) async {
    await ensureKeys();
    final sig = await _algo.sign(message, keyPair: _keyPair!);
    return sig.bytes;
  }

  static Future<bool> verify(List<int> message, List<int> signature, String publicKeyB64) async {
    try {
      final pk = SimplePublicKey(B64.decode(publicKeyB64), type: KeyPairType.ed25519);
      return await Ed25519().verify(message, signature: Signature(signature, publicKey: pk));
    } catch (_) {
      return false;
    }
  }

  /// Huella corta legible para verificación visual de claves.
  static Future<String> fingerprint(String publicKeyB64) async {
    final hash = await Sha256().hash(B64.decode(publicKeyB64));
    final hex = hash.bytes.take(6).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return hex.toUpperCase().replaceAllMapped(RegExp(r'.{4}'), (m) => '${m[0]} ').trim();
  }
}
