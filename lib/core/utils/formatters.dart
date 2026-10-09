import 'package:intl/intl.dart';

/// Formateadores de presentación (moneda, fechas, horas).
class Fmt {
  Fmt._();

  static String money(int cents, {String symbol = r'$'}) {
    final f = NumberFormat.currency(locale: 'es', symbol: symbol, decimalDigits: 2);
    return f.format(cents / 100);
  }

  static String date(DateTime d) => DateFormat('dd/MM/yyyy').format(d);
  static String dateTime(DateTime d) => DateFormat('dd/MM/yyyy HH:mm').format(d);
  static String time(DateTime d) => DateFormat('HH:mm').format(d);
  static String monthYear(DateTime d) {
    final s = DateFormat('MMMM yyyy', 'es').format(d);
    return s[0].toUpperCase() + s.substring(1);
  }

  /// Convierte minutos desde medianoche a etiqueta 12 h (ej. 5:00 am).
  static String minutes(int m) {
    final h = m ~/ 60;
    final min = m % 60;
    final suffix = h < 12 ? 'am' : 'pm';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:${min.toString().padLeft(2, '0')} $suffix';
  }

  /// Convierte texto decimal ("150.50") a centavos. Devuelve null si es inválido.
  static int? parseMoney(String raw) {
    final cleaned = raw.trim().replaceAll(',', '.');
    final v = double.tryParse(cleaned);
    if (v == null || v < 0 || v > 100000000) return null;
    return (v * 100).round();
  }
}
