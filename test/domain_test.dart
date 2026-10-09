import 'package:flutter_test/flutter_test.dart';
import 'package:gympass_control/domain/models/account_type.dart';
import 'package:gympass_control/domain/models/client.dart';
import 'package:gympass_control/domain/models/membership.dart';
import 'package:gympass_control/domain/models/payment.dart';
import 'package:gympass_control/domain/models/plan.dart';
import 'package:gympass_control/domain/models/shift.dart';
import 'package:gympass_control/domain/services/membership_calculator.dart';
import 'package:gympass_control/domain/services/reminder_planner.dart';
import 'package:gympass_control/domain/services/revenue_report.dart';
import 'package:gympass_control/domain/services/shift_service.dart';

Payment pay(String id, DateTime at, int days, {bool replace = false, PaymentStatus st = PaymentStatus.confirmed, int amount = 100}) =>
    Payment(
      id: id,
      clientId: 'c1',
      planId: 'p',
      planName: days == 7 ? 'Semanal' : 'Mensual',
      durationDays: days,
      amountCents: amount,
      method: PaymentMethod.cash,
      createdAt: at,
      periodStart: at,
      periodEnd: at,
      kind: PaymentKind.renewal,
      replacePeriod: replace,
      status: st,
    );

void main() {
  final client = Client(id: 'c1', name: 'Ana', accountType: AccountType.standard, createdAt: DateTime(2025, 1, 1));
  const calc = MembershipCalculator();
  const plan = Plan(id: 'p', name: 'Semanal', durationDays: 7, priceStandardCents: 100, pricePremiumCents: 200);

  group('Turnos', () {
    const svc = ShiftService();
    test('detecta turno por hora', () {
      expect(svc.detect(ShiftService.defaults, DateTime(2025, 1, 1, 5, 0))?.id, 'sh_0500');
      expect(svc.detect(ShiftService.defaults, DateTime(2025, 1, 1, 6, 59))?.id, 'sh_0500');
      expect(svc.detect(ShiftService.defaults, DateTime(2025, 1, 1, 7, 0))?.id, 'sh_0700');
      expect(svc.detect(ShiftService.defaults, DateTime(2025, 1, 1, 18, 30))?.id, 'sh_1700');
    });
    test('cierres: almuerzo y nocturno', () {
      expect(svc.detect(ShiftService.defaults, DateTime(2025, 1, 1, 12, 0)), isNull);
      expect(svc.detect(ShiftService.defaults, DateTime(2025, 1, 1, 20, 0)), isNull);
      expect(svc.detect(ShiftService.defaults, DateTime(2025, 1, 1, 4, 59)), isNull);
    });
    test('editar turno conserva id y valida solapes', () {
      final edited = ShiftService.defaults.first.copyWith(startMinute: 4 * 60 + 30, endMinute: 6 * 60 + 30);
      expect(edited.id, 'sh_0500');
      expect(svc.validate(edited, ShiftService.defaults), isNull);
    });
    test('solape real', () {
      const s = Shift(id: 'x', startMinute: 6 * 60, endMinute: 8 * 60);
      expect(svc.validate(s, ShiftService.defaults), contains('Se solapa'));
      const ok = Shift(id: 'y', startMinute: 11 * 60, endMinute: 13 * 60);
      expect(svc.validate(ok, ShiftService.defaults), isNull);
    });
  });

  group('Membresía', () {
    test('sin pagos', () {
      expect(calc.compute(client, [], DateTime(2025, 1, 1)).state, MembershipState.never);
    });
    test('pago anticipado extiende sin perder días (regla 4)', () {
      final ps = [pay('a', DateTime(2025, 1, 1, 10), 7), pay('b', DateTime(2025, 1, 3, 10), 7)];
      expect(MembershipCalculator.replayExpiry(ps), DateTime(2025, 1, 15));
    });
    test('recuperación de vencido inicia hoy', () {
      final ps = [pay('a', DateTime(2025, 1, 1), 7), pay('b', DateTime(2025, 1, 20), 7)];
      expect(MembershipCalculator.replayExpiry(ps), DateTime(2025, 1, 27));
    });
    test('reemplazar periodo', () {
      final ps = [pay('a', DateTime(2025, 1, 1), 30), pay('b', DateTime(2025, 1, 5), 7, replace: true)];
      expect(MembershipCalculator.replayExpiry(ps), DateTime(2025, 1, 12));
    });
    test('pagos anulados no cuentan', () {
      final ps = [pay('a', DateTime(2025, 1, 1), 7, st: PaymentStatus.voided)];
      expect(calc.compute(client, ps, DateTime(2025, 1, 2)).state, MembershipState.never);
    });
    test('estados vigente / por vencer / vencido', () {
      final ps = [pay('a', DateTime(2025, 1, 1, 9), 7)];
      expect(calc.compute(client, ps, DateTime(2025, 1, 2)).state, MembershipState.active);
      expect(calc.compute(client, ps, DateTime(2025, 1, 6)).state, MembershipState.expiring);
      expect(calc.compute(client, ps, DateTime(2025, 1, 8)).state, MembershipState.expired);
    });
    test('preview clasifica tipo de pago', () {
      final m0 = calc.compute(client, [], DateTime(2025, 1, 1));
      expect(calc.preview(current: m0, plan: plan, now: DateTime(2025, 1, 1)).kind, PaymentKind.first);
      final m1 = calc.compute(client, [pay('a', DateTime(2025, 1, 1), 30)], DateTime(2025, 1, 2));
      expect(calc.preview(current: m1, plan: plan, now: DateTime(2025, 1, 2)).kind, PaymentKind.advance);
      final m2 = calc.compute(client, [pay('a', DateTime(2025, 1, 1), 7)], DateTime(2025, 1, 20));
      expect(calc.preview(current: m2, plan: plan, now: DateTime(2025, 1, 20)).kind, PaymentKind.recovery);
    });
  });

  group('Recordatorios', () {
    const planner = ReminderPlanner();
    test('solo días sin pagar, 1 h antes', () {
      final now = DateTime(2025, 1, 6, 0, 0); // lunes
      final times = planner.plan(
        now: now,
        shiftStartMinute: 17 * 60,
        openWeekdays: [1, 2, 3, 4, 5, 6],
        minutesBefore: 60,
        expiresAt: DateTime(2025, 1, 8), // pagado lun y mar
        days: 7,
      );
      expect(times.first, DateTime(2025, 1, 8, 16, 0));
      expect(times.every((t) => t.weekday != 7), isTrue);
      expect(times.length, 4); // mié, jue, vie, sáb
    });
    test('pagado todo el horizonte -> sin recordatorios', () {
      final times = planner.plan(
          now: DateTime(2025, 1, 6), shiftStartMinute: 300, openWeekdays: [1, 2, 3, 4, 5, 6, 7], minutesBefore: 60, expiresAt: DateTime(2025, 3, 1));
      expect(times, isEmpty);
    });
  });

  group('Ingresos', () {
    test('suma solo confirmados en el mes', () {
      final ps = [
        pay('a', DateTime(2025, 1, 2), 7, amount: 1000),
        pay('b', DateTime(2025, 1, 15), 30, amount: 3000),
        pay('c', DateTime(2025, 1, 16), 7, amount: 500, st: PaymentStatus.voided),
        pay('d', DateTime(2025, 2, 1), 7, amount: 999),
      ];
      final r = RevenueReport.build(payments: ps, clients: {'c1': client}, from: DateTime(2025, 1), to: DateTime(2025, 2));
      expect(r.totalCents, 4000);
      expect(r.count, 2);
      expect(r.voidedCount, 1);
    });
  });
}
