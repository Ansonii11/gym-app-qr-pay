import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/crypto/key_manager.dart';
import '../../core/crypto/signed_qr.dart';
import '../../core/utils/clock.dart';
import '../../core/utils/ids.dart';
import '../../data/repositories/admin_repository.dart';
import '../../domain/models/account_type.dart';
import '../../domain/models/audit_entry.dart';
import '../../domain/models/client.dart';
import '../../domain/models/gym_settings.dart';
import '../../domain/models/membership.dart';
import '../../domain/models/payment.dart';
import '../../domain/models/plan.dart';
import '../../domain/models/shift.dart';
import '../../domain/qr/qr_payloads.dart';
import '../../domain/qr/qr_types.dart';
import '../../domain/services/membership_calculator.dart';
import '../../domain/services/revenue_report.dart';
import '../../domain/services/shift_service.dart';
import 'pay_scan_result.dart';

/// Caso de uso central del administrador: socios, cobros, turnos y panel.
class AdminController extends ChangeNotifier {
  AdminController(this._repo, this._keys, {Clock clock = const SystemClock()}) : _clock = clock;

  final AdminRepository _repo;
  final KeyManager _keys;
  final Clock _clock;
  final ShiftService _shiftService = const ShiftService();

  static const undoWindow = Duration(seconds: 10);

  final Map<String, Client> _clients = {};
  final Map<String, Payment> _payments = {};
  final Map<String, Plan> _plans = {};
  final Map<String, Shift> _shifts = {};
  GymSettings _settings = const GymSettings();
  late String _gymId;

  DateTime get now => _clock.now();
  GymSettings get settings => _settings;
  String get gymId => _gymId;
  String get adminPublicKey => _keys.publicKey;
  MembershipCalculator get _calc =>
      MembershipCalculator(expiringThresholdDays: _settings.expiringThresholdDays);

  // ------------------------------------------------------------------ init
  Future<void> init() async {
    await _keys.ensureKeys();
    var id = _repo.gymId;
    if (id == null) {
      id = Ids.newId();
      await _repo.setGymId(id);
    }
    _gymId = id;
    if (!_repo.seeded) await _seedDefaults();
    _reload();
  }

  Future<void> _seedDefaults() async {
    for (final s in ShiftService.defaults) {
      await _repo.saveShift(s);
    }
    await _repo.savePlan(const Plan(
        id: 'plan_week', name: 'Semanal', durationDays: 7, priceStandardCents: 10000, pricePremiumCents: 15000));
    await _repo.savePlan(const Plan(
        id: 'plan_month', name: 'Mensual', durationDays: 30, priceStandardCents: 35000, pricePremiumCents: 50000));
    await _repo.markSeeded();
  }

  void _reload() {
    _clients
      ..clear()
      ..addEntries(_repo.loadClients().map((c) => MapEntry(c.id, c)));
    _payments
      ..clear()
      ..addEntries(_repo.loadPayments().map((p) => MapEntry(p.id, p)));
    _plans
      ..clear()
      ..addEntries(_repo.loadPlans().map((p) => MapEntry(p.id, p)));
    _shifts
      ..clear()
      ..addEntries(_repo.loadShifts().map((s) => MapEntry(s.id, s)));
    _settings = _repo.loadSettings();
  }

  Future<void> _audit(String action, {String? target, String? detail, String? reason}) => _repo.addAudit(
      AuditEntry(id: Ids.newId(), action: action, at: now, targetId: target, detail: detail, reason: reason));

  // ------------------------------------------------------------ consultas
  List<Client> get clients => _clients.values.toList()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  Client? client(String id) => _clients[id];
  List<Plan> get plans => _plans.values.toList()..sort((a, b) => a.durationDays.compareTo(b.durationDays));
  List<Plan> get activePlans => plans.where((p) => p.active).toList();
  Plan? plan(String id) => _plans[id];
  List<Shift> get shifts => _shiftService.sorted(_shifts.values.toList());
  Shift? shift(String? id) => id == null ? null : _shifts[id];
  Shift? get currentShift => _shiftService.detect(shifts, now);
  List<AuditEntry> get audit => _repo.loadAudit();

  List<Payment> paymentsOf(String clientId) =>
      _payments.values.where((p) => p.clientId == clientId).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<Payment> get allPayments => _payments.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Membership membershipOf(Client c) => _calc.compute(c, _payments.values.where((p) => p.clientId == c.id), now);

  int membersInShift(String shiftId) => _clients.values.where((c) => c.shiftId == shiftId && c.active).length;

  RevenueReport report(DateTime from, DateTime to) =>
      RevenueReport.build(payments: _payments.values, clients: _clients, from: from, to: to);

  /// Clientes activos del turno indicado que NO tienen membresía vigente.
  List<Client> unpaidInShift(String shiftId) => _clients.values
      .where((c) => c.active && c.shiftId == shiftId && !membershipOf(c).state.isPaid)
      .toList();

  /// Próximo turno que aún no ha comenzado hoy.
  Shift? get nextShift {
    final m = ShiftService.minuteOfDay(now);
    for (final s in shifts) {
      if (s.startMinute > m) return s;
    }
    return null;
  }

  // -------------------------------------------------------------- clientes
  String? _validateName(String name) {
    final n = name.trim();
    if (n.length < 2) return 'El nombre debe tener al menos 2 caracteres.';
    if (n.length > 60) return 'El nombre es demasiado largo.';
    return null;
  }

  Future<Client> createClient({
    required String name,
    String? phone,
    required AccountType type,
    String? shiftId,
  }) async {
    final err = _validateName(name);
    if (err != null) throw ArgumentError(err);
    final c = Client(
      id: Ids.shortId(),
      name: name.trim(),
      phone: (phone == null || phone.trim().isEmpty) ? null : phone.trim(),
      accountType: type,
      createdAt: now,
      shiftId: shiftId,
      inviteNonce: Ids.shortId(),
    );
    await _repo.saveClient(c);
    _clients[c.id] = c;
    await _audit('client.create', target: c.id, detail: '${c.name} (${type.label})');
    notifyListeners();
    return c;
  }

  Future<void> updateClient(Client updated) async {
    final err = _validateName(updated.name);
    if (err != null) throw ArgumentError(err);
    final prev = _clients[updated.id];
    await _repo.saveClient(updated);
    _clients[updated.id] = updated;
    if (prev != null && prev.accountType != updated.accountType) {
      await _audit('client.type', target: updated.id, detail: '${prev.accountType.label} → ${updated.accountType.label}');
    }
    if (prev != null && prev.shiftId != updated.shiftId) {
      await _audit('client.shift', target: updated.id, detail: shift(updated.shiftId)?.rangeLabel ?? 'Sin turno');
    }
    notifyListeners();
  }

  Future<void> setClientActive(String id, bool active, String reason) async {
    final c = _clients[id];
    if (c == null) return;
    await updateClient(c.copyWith(active: active));
    await _audit(active ? 'client.enable' : 'client.disable', target: id, reason: reason);
  }

  /// Restablece el dispositivo vinculado (requiere verificación presencial).
  Future<void> resetDevice(String id, String reason) async {
    final c = _clients[id];
    if (c == null) return;
    final updated = c.copyWith(clearDevice: true, inviteNonce: Ids.shortId());
    await _repo.saveClient(updated);
    _clients[id] = updated;
    await _audit('device.reset', target: id, reason: reason);
    notifyListeners();
  }

  // ----------------------------------------------------------- vinculación
  /// QR de invitación firmado para que el cliente vincule su teléfono.
  Future<String> inviteQr(String clientId) async {
    var c = _clients[clientId]!;
    if (c.inviteNonce == null) {
      c = c.copyWith(inviteNonce: Ids.shortId());
      await _repo.saveClient(c);
      _clients[c.id] = c;
    }
    final payload = InvitePayload(
      gymId: _gymId,
      gymName: _settings.gymName,
      adminPublicKey: _keys.publicKey,
      clientId: c.id,
      clientName: c.name,
      nonce: c.inviteNonce!,
      issuedAt: now,
    );
    return SignedQr.encode(payload.toJson(), _keys);
  }

  /// Procesa el QR de vinculación del cliente. Devuelve el cliente vinculado.
  Future<Client> linkDevice(String raw) async {
    final parsed = SignedQr.parse(raw);
    if (parsed == null || parsed.type != QrType.link) {
      throw const FormatException('No es un código de vinculación válido.');
    }
    final link = LinkPayload.tryParse(parsed.payload);
    if (link == null) throw const FormatException('Código de vinculación dañado.');
    final c = _clients[link.clientId];
    if (c == null) throw const FormatException('El cliente no existe en este gimnasio.');
    if (c.inviteNonce == null || c.inviteNonce != link.nonce) {
      throw const FormatException('Invitación caducada o ya utilizada. Genera una nueva.');
    }
    if (!await parsed.verifyWith(link.devicePublicKey)) {
      throw const FormatException('Firma del dispositivo inválida.');
    }
    final updated = c.copyWith(
      devicePublicKey: link.devicePublicKey,
      deviceId: link.deviceId,
      clearInvite: true,
    );
    await _repo.saveClient(updated);
    _clients[c.id] = updated;
    await _audit('device.link', target: c.id, detail: link.deviceId);
    notifyListeners();
    return updated;
  }

  // ----------------------------------------------------------------- cobro
  /// Valida un QR de solicitud de pago. No registra nada (regla 1).
  Future<PayScanResult> scanPayRequest(String raw) async {
    final parsed = SignedQr.parse(raw);
    if (parsed == null) return PayScanResult.invalid('Código no reconocido.');
    if (parsed.type != QrType.payRequest) {
      return PayScanResult.invalid('Este QR no es una solicitud de pago.');
    }
    final req = PayRequestPayload.tryParse(parsed.payload);
    if (req == null) return PayScanResult.invalid('Solicitud de pago dañada.');
    final c = _clients[req.clientId];
    if (c == null) return PayScanResult.invalid('Cliente desconocido para este gimnasio.');
    if (c.devicePublicKey == null || c.deviceId != req.deviceId) {
      return PayScanResult.invalid('El dispositivo no está vinculado a ${c.name}.');
    }
    if (!await parsed.verifyWith(c.devicePublicKey!)) {
      return PayScanResult.invalid('Firma inválida: posible código falsificado.');
    }
    final plan = _plans[req.planId];
    if (plan == null || !plan.active) {
      return PayScanResult.invalid('El plan solicitado ya no está disponible. Pide al cliente actualizar su app.');
    }

    final membership = membershipOf(c);
    final existing = _repo.paymentForNonce(req.nonce);
    if (existing != null) {
      return PayScanResult(
        verdict: ScanVerdict.invalid,
        message: 'Esta solicitud ya fue cobrada.',
        client: c,
        plan: plan,
        membership: membership,
        alreadyPaidPaymentId: existing,
      );
    }

    final warnings = <String>[];
    var verdict = ScanVerdict.ok;
    final age = now.difference(req.createdAt);
    if (age.isNegative && -age > QrTiming.clockTolerance) {
      verdict = ScanVerdict.warning;
      warnings.add('El reloj del cliente va adelantado ${(-age).inMinutes} min. Verifica la identidad.');
    } else if (age > QrTiming.payRequestValidity + QrTiming.clockTolerance) {
      verdict = ScanVerdict.warning;
      warnings.add('Solicitud generada hace ${age.inMinutes} min (caduca a los 5). Verifica la identidad.');
    }
    if (!c.active) {
      verdict = ScanVerdict.warning;
      warnings.add('La cuenta está desactivada. Al cobrar se reactivará.');
    }
    final detected = currentShift;
    if (detected == null) {
      warnings.add('Fuera de horario: se mantiene el turno actual del socio.');
    }

    return PayScanResult(
      verdict: verdict,
      message: verdict == ScanVerdict.ok ? 'Solicitud válida' : 'Requiere revisión manual',
      client: c,
      plan: plan,
      membership: membership,
      preview: _calc.preview(current: membership, plan: plan, now: now),
      detectedShift: detected,
      request: req,
      warnings: warnings,
    );
  }

  PaymentPreview previewFor(Client c, Plan plan, {bool replacePeriod = false}) =>
      _calc.preview(current: membershipOf(c), plan: plan, now: now, replacePeriod: replacePeriod);

  /// Registra el pago tras la confirmación explícita del administrador.
  /// El turno se asigna automáticamente según la hora del cobro.
  Future<Payment> confirmPayment({
    required Client client,
    required Plan plan,
    required PaymentMethod method,
    bool replacePeriod = false,
    String? requestNonce,
    String? manualShiftId,
  }) async {
    if (requestNonce != null && _repo.nonceUsed(requestNonce)) {
      throw StateError('Esta solicitud ya fue cobrada.');
    }
    final c = _clients[client.id]!;
    final preview = previewFor(c, plan, replacePeriod: replacePeriod);
    final detected = currentShift;
    final shiftId = detected?.id ?? manualShiftId ?? c.shiftId;

    final p = Payment(
      id: Ids.newId(),
      clientId: c.id,
      planId: plan.id,
      planName: plan.name,
      durationDays: plan.durationDays,
      amountCents: plan.priceFor(c.accountType),
      method: method,
      createdAt: now,
      periodStart: preview.periodStart,
      periodEnd: preview.periodEnd,
      kind: preview.kind,
      replacePeriod: replacePeriod,
      shiftId: shiftId,
      viaQr: requestNonce != null,
      requestNonce: requestNonce,
    );
    // Orden de escritura: primero el nonce (idempotencia), luego el pago.
    if (requestNonce != null) await _repo.markNonce(requestNonce, p.id, now);
    await _repo.savePayment(p);
    _payments[p.id] = p;

    var updated = c;
    if (shiftId != c.shiftId) updated = updated.copyWith(shiftId: shiftId);
    if (!c.active) updated = updated.copyWith(active: true);
    if (!identical(updated, c)) {
      await _repo.saveClient(updated);
      _clients[c.id] = updated;
    }
    await _audit('payment.confirm',
        target: p.id, detail: '${c.name} · ${plan.name} · ${p.amountCents} · ${shift(shiftId)?.rangeLabel ?? '-'}');
    notifyListeners();
    return p;
  }

  bool canUndo(Payment p) =>
      p.status == PaymentStatus.confirmed && now.difference(p.createdAt) <= undoWindow;

  Future<bool> undoPayment(String paymentId) async {
    final p = _payments[paymentId];
    if (p == null || !canUndo(p)) return false;
    final u = p.withStatus(PaymentStatus.undone, reason: 'Deshecho por el administrador', at: now);
    await _repo.savePayment(u);
    _payments[p.id] = u;
    if (p.requestNonce != null) await _repo.releaseNonce(p.requestNonce!);
    await _audit('payment.undo', target: p.id);
    notifyListeners();
    return true;
  }

  /// Anulación auditable (regla 5). El pago original no se edita.
  Future<void> voidPayment(String paymentId, String reason) async {
    final r = reason.trim();
    if (r.length < 3) throw ArgumentError('Indica un motivo de anulación.');
    final p = _payments[paymentId];
    if (p == null || p.status != PaymentStatus.confirmed) return;
    final v = p.withStatus(PaymentStatus.voided, reason: r, at: now);
    await _repo.savePayment(v);
    _payments[p.id] = v;
    await _audit('payment.void', target: p.id, reason: r);
    notifyListeners();
  }

  /// QR de recibo/estado firmado para actualizar el teléfono del cliente.
  Future<String> receiptQr(String clientId, {Payment? payment}) async {
    var c = _clients[clientId]!;
    c = c.copyWith(syncVersion: c.syncVersion + 1);
    await _repo.saveClient(c);
    _clients[c.id] = c;
    final m = membershipOf(c);
    final s = shift(c.shiftId);
    final payload = ReceiptPayload(
      gymId: _gymId,
      gymName: _settings.gymName,
      clientId: c.id,
      clientName: c.name,
      accountType: c.accountType,
      active: c.active,
      version: c.syncVersion,
      issuedAt: now,
      expiresAt: m.expiresAt,
      plans: activePlans
          .map((p) => PlanSummary(id: p.id, name: p.name, days: p.durationDays, priceCents: p.priceFor(c.accountType)))
          .toList(),
      openWeekdays: _settings.openWeekdays,
      reminderMinutes: _settings.reminderMinutesBefore,
      currency: _settings.currencySymbol,
      shiftStart: s?.startMinute,
      shiftEnd: s?.endMinute,
      shiftName: s?.name,
      paymentId: payment?.id,
      paymentAmountCents: payment?.amountCents,
      paymentPlanName: payment?.planName,
      paymentAt: payment?.createdAt,
    );
    return SignedQr.encode(payload.toJson(), _keys);
  }

  // ---------------------------------------------------------------- planes
  String? validatePlan(String name, int days, int? std, int? pre) {
    if (name.trim().length < 2) return 'Nombre de plan inválido.';
    if (days < 1 || days > 366) return 'La duración debe estar entre 1 y 366 días.';
    if (std == null || pre == null) return 'Precio inválido.';
    return null;
  }

  Future<void> savePlan(Plan p) async {
    final err = validatePlan(p.name, p.durationDays, p.priceStandardCents, p.pricePremiumCents);
    if (err != null) throw ArgumentError(err);
    final isNew = !_plans.containsKey(p.id);
    await _repo.savePlan(p);
    _plans[p.id] = p;
    await _audit(isNew ? 'plan.create' : 'plan.update',
        target: p.id, detail: '${p.name} ${p.durationDays}d ${p.priceStandardCents}/${p.pricePremiumCents}');
    notifyListeners();
  }

  // ---------------------------------------------------------------- turnos
  String? validateShift(Shift s) => _shiftService.validate(s, shifts);

  /// Crea o edita un turno. Al editar se conserva el id, por lo que todos
  /// los socios asignados se mueven automáticamente al nuevo horario.
  Future<void> saveShift(Shift s) async {
    final err = validateShift(s);
    if (err != null) throw ArgumentError(err);
    final prev = _shifts[s.id];
    await _repo.saveShift(s);
    _shifts[s.id] = s;
    await _audit(prev == null ? 'shift.create' : 'shift.update',
        target: s.id, detail: '${prev?.rangeLabel ?? ''} → ${s.rangeLabel} (${membersInShift(s.id)} socios)');
    notifyListeners();
  }

  Shift newShiftDraft() => Shift(id: 'sh_${Ids.shortId()}', startMinute: 19 * 60, endMinute: 21 * 60);

  /// Elimina un turno moviendo a sus socios a [moveToShiftId] (o sin turno).
  Future<void> deleteShift(String id, {String? moveToShiftId}) async {
    final affected = _clients.values.where((c) => c.shiftId == id).toList();
    for (final c in affected) {
      final u = moveToShiftId == null ? c.copyWith(clearShift: true) : c.copyWith(shiftId: moveToShiftId);
      await _repo.saveClient(u);
      _clients[c.id] = u;
    }
    final removed = _shifts.remove(id);
    await _repo.deleteShift(id);
    await _audit('shift.delete',
        target: id, detail: '${removed?.rangeLabel} · ${affected.length} socios → ${shift(moveToShiftId)?.rangeLabel ?? 'sin turno'}');
    notifyListeners();
  }

  // --------------------------------------------------------------- ajustes
  Future<void> saveSettings(GymSettings s) async {
    if (s.gymName.trim().length < 2) throw ArgumentError('Nombre del gimnasio inválido.');
    if (s.openWeekdays.isEmpty) throw ArgumentError('Selecciona al menos un día de apertura.');
    await _repo.saveSettings(s);
    _settings = s;
    await _audit('settings.update');
    notifyListeners();
  }

  /// Fuerza el refresco de estados dependientes del tiempo (vencimientos).
  void tick() => notifyListeners();

  @visibleForTesting
  Future<void> reloadForTest() async => _reload();
}
