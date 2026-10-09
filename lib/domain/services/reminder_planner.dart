/// Calcula los instantes de recordatorio "X minutos antes del turno"
/// únicamente para los días en que la membresía NO estará pagada.
class ReminderPlanner {
  const ReminderPlanner();

  static const horizonDays = 14;

  List<DateTime> plan({
    required DateTime now,
    required int shiftStartMinute,
    required List<int> openWeekdays,
    required int minutesBefore,
    required DateTime? expiresAt,
    bool accountActive = true,
    int days = horizonDays,
  }) {
    if (!accountActive) return const [];
    final out = <DateTime>[];
    final today = DateTime(now.year, now.month, now.day);
    for (var i = 0; i < days; i++) {
      final day = DateTime(today.year, today.month, today.day + i);
      if (!openWeekdays.contains(day.weekday)) continue;
      final shiftStart = day.add(Duration(minutes: shiftStartMinute));
      final unpaid = expiresAt == null || !shiftStart.isBefore(expiresAt);
      if (!unpaid) continue;
      final remindAt = shiftStart.subtract(Duration(minutes: minutesBefore));
      if (remindAt.isAfter(now)) out.add(remindAt);
    }
    return out;
  }
}
