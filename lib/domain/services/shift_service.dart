import '../models/shift.dart';

/// Reglas de turnos: detección automática y validación de solapes.
class ShiftService {
  const ShiftService();

  static const List<Shift> defaults = [
    Shift(id: 'sh_0500', startMinute: 5 * 60, endMinute: 7 * 60),
    Shift(id: 'sh_0700', startMinute: 7 * 60, endMinute: 9 * 60),
    Shift(id: 'sh_0900', startMinute: 9 * 60, endMinute: 11 * 60),
    Shift(id: 'sh_1300', startMinute: 13 * 60, endMinute: 15 * 60),
    Shift(id: 'sh_1500', startMinute: 15 * 60, endMinute: 17 * 60),
    Shift(id: 'sh_1700', startMinute: 17 * 60, endMinute: 19 * 60),
  ];

  static int minuteOfDay(DateTime t) => t.hour * 60 + t.minute;

  /// Turno que contiene la hora indicada, o null si el gimnasio está cerrado
  /// (almuerzo, cierre nocturno o fuera de horario).
  Shift? detect(List<Shift> shifts, DateTime at) {
    final m = minuteOfDay(at);
    for (final s in sorted(shifts)) {
      if (s.containsMinute(m)) return s;
    }
    return null;
  }

  List<Shift> sorted(List<Shift> shifts) =>
      [...shifts]..sort((a, b) => a.startMinute.compareTo(b.startMinute));

  /// Devuelve un mensaje de error o null si el turno es válido.
  String? validate(Shift candidate, List<Shift> existing) {
    if (candidate.startMinute < 0 || candidate.endMinute > 24 * 60) {
      return 'El horario debe estar entre 00:00 y 24:00.';
    }
    if (candidate.endMinute <= candidate.startMinute) {
      return 'La hora de fin debe ser posterior a la de inicio.';
    }
    if (candidate.endMinute - candidate.startMinute < 15) {
      return 'Un turno debe durar al menos 15 minutos.';
    }
    for (final s in existing) {
      if (s.id == candidate.id) continue;
      final overlaps = candidate.startMinute < s.endMinute && s.startMinute < candidate.endMinute;
      if (overlaps) return 'Se solapa con el turno ${s.rangeLabel}.';
    }
    return null;
  }
}
