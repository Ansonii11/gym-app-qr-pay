import 'dart:convert';
import 'dart:typed_data';

/// Base64 URL-safe sin padding (compacto para QR).
class B64 {
  B64._();

  static String encode(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

  static Uint8List decode(String s) {
    final padded = s.padRight(s.length + (4 - s.length % 4) % 4, '=');
    return base64Url.decode(padded);
  }
}
