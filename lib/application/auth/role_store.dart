import '../../core/crypto/b64.dart';
import '../../core/crypto/pin_hasher.dart';
import '../../core/storage/secure_store.dart';

enum AppRole { admin, client }

/// Persiste el rol del dispositivo y el PIN del administrador (hash PBKDF2).
class RoleStore {
  RoleStore() : _secure = SecureStore('app');
  final SecureStore _secure;

  static const maxAttempts = 5;

  Future<AppRole?> loadRole() async {
    final r = await _secure.read('role');
    return switch (r) { 'admin' => AppRole.admin, 'client' => AppRole.client, _ => null };
  }

  Future<void> setRole(AppRole role) => _secure.write('role', role.name);

  Future<void> clearRole() async {
    await _secure.delete('role');
    await _secure.delete('pin_hash');
    await _secure.delete('pin_salt');
    await _secure.delete('pin_fail');
    await _secure.delete('pin_lock');
  }

  Future<void> setPin(String pin) async {
    final salt = PinHasher.newSalt();
    await _secure.write('pin_salt', B64.encode(salt));
    await _secure.write('pin_hash', await PinHasher.hash(pin, salt));
    await _secure.write('pin_fail', '0');
  }

  Future<bool> hasPin() async => (await _secure.read('pin_hash')) != null;

  /// Tiempo restante de bloqueo tras demasiados intentos fallidos.
  Future<Duration> lockRemaining(DateTime now) async {
    final until = DateTime.tryParse(await _secure.read('pin_lock') ?? '');
    if (until == null || !until.isAfter(now)) return Duration.zero;
    return until.difference(now);
  }

  Future<PinResult> verifyPin(String pin, DateTime now) async {
    if ((await lockRemaining(now)) > Duration.zero) return PinResult.locked;
    final saltB64 = await _secure.read('pin_salt');
    final stored = await _secure.read('pin_hash');
    if (saltB64 == null || stored == null) return PinResult.wrong;
    final hash = await PinHasher.hash(pin, B64.decode(saltB64));
    if (PinHasher.safeEquals(hash, stored)) {
      await _secure.write('pin_fail', '0');
      return PinResult.ok;
    }
    final fails = (int.tryParse(await _secure.read('pin_fail') ?? '0') ?? 0) + 1;
    await _secure.write('pin_fail', '$fails');
    if (fails >= maxAttempts) {
      // Bloqueo exponencial: 30 s, 60 s, 120 s ...
      final secs = 30 * (1 << (fails - maxAttempts).clamp(0, 6));
      await _secure.write('pin_lock', now.add(Duration(seconds: secs)).toIso8601String());
      return PinResult.locked;
    }
    return PinResult.wrong;
  }
}

enum PinResult { ok, wrong, locked }
