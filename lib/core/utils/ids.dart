import 'package:uuid/uuid.dart';

/// Generador central de identificadores únicos.
class Ids {
  Ids._();
  static const _uuid = Uuid();

  static String newId() => _uuid.v4();

  /// Identificador corto (12 hex) para reducir el tamaño de los QR.
  static String shortId() => _uuid.v4().replaceAll('-', '').substring(0, 12);
}
