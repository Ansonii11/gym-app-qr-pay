import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Almacén de secretos respaldado por Android Keystore.
/// Todas las claves se prefijan con el espacio de nombres del rol
/// para que los datos de administrador y cliente nunca se mezclen.
class SecureStore {
  SecureStore(this._namespace);

  final String _namespace;
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );

  String _k(String key) => '${_namespace}_$key';

  Future<String?> read(String key) => _storage.read(key: _k(key));
  Future<void> write(String key, String value) => _storage.write(key: _k(key), value: value);
  Future<void> delete(String key) => _storage.delete(key: _k(key));
}
