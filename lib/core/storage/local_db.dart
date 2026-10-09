import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../crypto/b64.dart';
import 'secure_store.dart';

/// Base de datos local cifrada (AES-256) sobre Hive.
/// La clave AES se genera una única vez y se guarda en [SecureStore].
class LocalDb {
  LocalDb._(this._namespace, this._cipher);

  final String _namespace;
  final HiveAesCipher _cipher;
  final Map<String, Box<String>> _boxes = {};

  static bool _hiveReady = false;

  static Future<LocalDb> open(String namespace, SecretStore secure) async {
    if (!_hiveReady) {
      await Hive.initFlutter();
      _hiveReady = true;
    }
    var keyB64 = await secure.read('db_key');
    if (keyB64 == null) {
      keyB64 = B64.encode(Hive.generateSecureKey());
      await secure.write('db_key', keyB64);
    }
    return LocalDb._(namespace, HiveAesCipher(B64.decode(keyB64)));
  }

  Future<JsonBox> box(String name) async {
    final full = '${_namespace}_$name';
    final existing = _boxes[full];
    if (existing != null) return JsonBox(existing);
    final b = await Hive.openBox<String>(full, encryptionCipher: _cipher);
    _boxes[full] = b;
    return JsonBox(b);
  }

  Future<void> wipe() async {
    for (final b in _boxes.values) {
      await b.deleteFromDisk();
    }
    _boxes.clear();
  }
}

/// Envoltura tipada que guarda documentos JSON por clave.
class JsonBox {
  JsonBox(this._box);
  final Box<String> _box;

  Map<String, dynamic>? get(String key) {
    final raw = _box.get(key);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Iterable<Map<String, dynamic>> all() =>
      _box.values.map((raw) => jsonDecode(raw) as Map<String, dynamic>);

  bool contains(String key) => _box.containsKey(key);

  Future<void> put(String key, Map<String, dynamic> value) async {
    await _box.put(key, jsonEncode(value));
    await _box.flush(); // durabilidad ante cierres inesperados
  }

  Future<void> delete(String key) => _box.delete(key);

  Iterable<String> get keys => _box.keys.cast<String>();
}
