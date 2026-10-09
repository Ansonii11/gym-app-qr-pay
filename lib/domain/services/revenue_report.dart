import '../models/account_type.dart';
import '../models/client.dart';
import '../models/payment.dart';

/// Agregados de ingresos para un rango [from, to).
class RevenueReport {
  RevenueReport._({
    required this.totalCents,
    required this.count,
    required this.byPlan,
    required this.byMethod,
    required this.byAccountType,
    required this.byDay,
    required this.payments,
    required this.voidedCount,
    required this.voidedCents,
  });

  final int totalCents;
  final int count;
  final Map<String, int> byPlan;
  final Map<PaymentMethod, int> byMethod;
  final Map<AccountType, int> byAccountType;

  /// Ingresos por día del rango (clave = día del mes).
  final Map<int, int> byDay;
  final List<Payment> payments;
  final int voidedCount;
  final int voidedCents;

  int get averageCents => count == 0 ? 0 : totalCents ~/ count;

  static DateTime monthStart(DateTime d) => DateTime(d.year, d.month);
  static DateTime nextMonth(DateTime d) => DateTime(d.year, d.month + 1);

  factory RevenueReport.build({
    required Iterable<Payment> payments,
    required Map<String, Client> clients,
    required DateTime from,
    required DateTime to,
  }) {
    final inRange = payments
        .where((p) => !p.createdAt.isBefore(from) && p.createdAt.isBefore(to))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final ok = inRange.where((p) => p.counts);
    final voided = inRange.where((p) => p.status == PaymentStatus.voided);

    final byPlan = <String, int>{};
    final byMethod = <PaymentMethod, int>{};
    final byType = <AccountType, int>{};
    final byDay = <int, int>{};
    var total = 0;
    var count = 0;
    for (final p in ok) {
      total += p.amountCents;
      count++;
      byPlan[p.planName] = (byPlan[p.planName] ?? 0) + p.amountCents;
      byMethod[p.method] = (byMethod[p.method] ?? 0) + p.amountCents;
      final type = clients[p.clientId]?.accountType ?? AccountType.standard;
      byType[type] = (byType[type] ?? 0) + p.amountCents;
      byDay[p.createdAt.day] = (byDay[p.createdAt.day] ?? 0) + p.amountCents;
    }
    return RevenueReport._(
      totalCents: total,
      count: count,
      byPlan: byPlan,
      byMethod: byMethod,
      byAccountType: byType,
      byDay: byDay,
      payments: inRange,
      voidedCount: voided.length,
      voidedCents: voided.fold(0, (a, p) => a + p.amountCents),
    );
  }
}
