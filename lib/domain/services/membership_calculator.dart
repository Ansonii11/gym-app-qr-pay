import '../models/client.dart';
import '../models/membership.dart';
import '../models/payment.dart';
import '../models/plan.dart';

/// Reglas de negocio puras sobre vigencia de membresías (PRD §8).
class MembershipCalculator {
  const MembershipCalculator({this.expiringThresholdDays = 3});

  final int expiringThresholdDays;

  static DateTime dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Fin de un periodo: días naturales completos; el vencimiento es exclusivo
  /// a las 00:00 del día siguiente al último día pagado.
  static DateTime addDays(DateTime start, int days) =>
      DateTime(start.year, start.month, start.day + days);

  /// Reconstruye el vencimiento aplicando cada pago confirmado en orden.
  /// Regla 3/4: el periodo inicia en max(hoy, vencimiento vigente) salvo
  /// que el pago indique "reemplazar periodo".
  static DateTime? replayExpiry(Iterable<Payment> payments) {
    final confirmed = payments.where((p) => p.counts).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    DateTime? expiry;
    for (final p in confirmed) {
      final paidDay = dayStart(p.createdAt);
      final start = (p.replacePeriod || expiry == null || expiry.isBefore(paidDay)) ? paidDay : expiry;
      expiry = addDays(start, p.durationDays);
    }
    return expiry;
  }

  Membership compute(Client client, Iterable<Payment> clientPayments, DateTime now) {
    final list = clientPayments.where((p) => p.clientId == client.id).toList();
    final confirmed = list.where((p) => p.counts).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final expiry = replayExpiry(confirmed);
    final last = confirmed.isEmpty ? null : confirmed.last;

    MembershipState state;
    if (!client.active) {
      state = MembershipState.disabled;
    } else if (expiry == null) {
      state = MembershipState.never;
    } else if (!now.isBefore(expiry)) {
      state = MembershipState.expired;
    } else if (expiry.difference(now).inHours <= expiringThresholdDays * 24) {
      state = MembershipState.expiring;
    } else {
      state = MembershipState.active;
    }
    return Membership(
      state: state,
      expiresAt: expiry,
      lastPaymentAt: last?.createdAt,
      currentPlanName: last?.planName,
    );
  }

  /// Vista previa del periodo que cubriría un nuevo pago.
  PaymentPreview preview({
    required Membership current,
    required Plan plan,
    required DateTime now,
    bool replacePeriod = false,
  }) {
    final today = dayStart(now);
    final expiry = current.expiresAt;
    final PaymentKind kind;
    if (expiry == null) {
      kind = PaymentKind.first;
    } else if (expiry.isBefore(today)) {
      kind = PaymentKind.recovery;
    } else if (expiry.difference(today).inDays > expiringThresholdDays) {
      kind = PaymentKind.advance;
    } else {
      kind = PaymentKind.renewal;
    }
    final start =
        (replacePeriod || expiry == null || expiry.isBefore(today)) ? today : expiry;
    return PaymentPreview(kind: kind, periodStart: start, periodEnd: addDays(start, plan.durationDays));
  }
}

class PaymentPreview {
  const PaymentPreview({required this.kind, required this.periodStart, required this.periodEnd});
  final PaymentKind kind;
  final DateTime periodStart;

  /// Exclusivo.
  final DateTime periodEnd;

  /// Último día cubierto (inclusivo) para mostrar al usuario.
  DateTime get lastDay => periodEnd.subtract(const Duration(days: 1));
}
