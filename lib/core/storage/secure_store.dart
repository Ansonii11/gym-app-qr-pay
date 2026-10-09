import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Contrato de almacén de secretos (permite inyectar dobles en tests).
abstract class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Almacén de secretos respaldado por Android Keystore.
/// Las claves se prefijan con el espacio de nombres del rol
/// para que los datos de administrador y cliente nunca se mezclen.
class SecureStore implements SecretStore {
  SecureStore(this._namespace);

  final String _namespace;
  static const _storage = FlutterSecureStorage(aOptions: AndroidOptions());

  String _k(String key) => '${_namespace}_$key';

  @override
  Future<String?> read(String key) => _storage.read(key: _k(key));
  @override
  Future<void> write(String key, String value) => _storage.write(key: _k(key), value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: _k(key));
}

/// Implementación en memoria (solo tests).
class MemorySecretStore implements SecretStore {
  final Map<String, String> _m = {};
  @override
  Future<String?> read(String key) async => _m[key];
  @override
  Future<void> write(String key, String value) async => _m[key] = value;
  @override
  Future<void> delete(String key) async => _m.remove(key);
}
