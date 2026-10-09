import 'package:flutter/foundation.dart';

import '../../core/crypto/key_manager.dart';
import '../../core/crypto/signed_qr.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/storage/secure_store.dart';
import '../../core/utils/clock.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ids.dart';
import '../../data/repositories/client_repository.dart';
import '../../domain/models/membership.dart';
import '../../domain/qr/qr_payloads.dart';
import '../../domain/qr/qr_types.dart';
import '../../domain/services/reminder_planner.dart';

/// Estado y casos de uso del teléfono del socio.
class ClientController extends ChangeNotifier {
  ClientController(this._repo, this._keys, this._secure, {Clock clock = const SystemClock()}) : _clock = clock;

  final ClientRepository _repo;
  final KeyManager _keys;
  final SecureStore _secure;
  final Clock _clock;
  final ReminderPlanner _planner = const ReminderPlanner();

  late String _deviceId;
  ClientLink? _link;
  ReceiptPayload? _receipt;
  int _scheduledReminders = 0;

  DateTime get now => _clock.now();
  ClientLink? get link => _link;
  ReceiptPayload? get receipt => _receipt;
  DateTime? get lastSync => _repo.lastSync;
  List<Map<String, dynamic>> get history => _repo.loadHistory();
  int get scheduledReminders => _scheduledReminders;

  /// Vinculado de forma completa = invitación aceptada + primer recibo recibido.
  bool get isLinked => _link != null && _receipt != null;
  bool get isPendingLink => _link != null && _receipt == null;

  Future<void> init() async {
    await _keys.ensureKeys();
    var dev = await _secure.read('device_id');
    if (dev == null) {
      dev = Ids.shortId();
      await _secure.write('device_id', dev);
    }
    _deviceId = dev;
    _link = _repo.loadLink();
    _receipt = _repo.loadReceipt();
    await rescheduleReminders();
  }

  // ------------------------------------------------------------- vinculación
  /// Paso 1: el cliente escanea la invitación firmada del administrador.
  Future<ClientLink> acceptInvite(String raw) async {
    final parsed = SignedQr.parse(raw);
    if (parsed == null || parsed.type != QrType.invite) {
      throw const FormatException('Este QR no es una invitación del gimnasio.');
    }
    final inv = InvitePayload.tryParse(parsed.payload);
    if (inv == null) throw const FormatException('Invitación dañada.');
    if (!await parsed.verifyWith(inv.adminPublicKey)) {
      throw const FormatException('Firma de la invitación inválida.');
    }
    if (_link != null && _receipt != null && _link!.gymId != inv.gymId) {
      throw const FormatException('Este teléfono ya está vinculado a otro gimnasio.');
    }
    final l = ClientLink(
      gymId: inv.gymId,
      gymName: inv.gymName,
      adminPublicKey: inv.adminPublicKey,
      clientId: inv.clientId,
      clientName: inv.clientName,
      deviceId: _deviceId,
      nonce: inv.nonce,
    );
    await _repo.saveLink(l);
    _link = l;
    notifyListeners();
    return l;
  }

  /// Paso 2: QR con la clave pública del dispositivo para el administrador.
  Future<String> linkQr() async {
    final l = _link;
    if (l == null) throw StateError('Primero escanea la invitación.');
    final payload = LinkPayload(
      clientId: l.clientId,
      nonce: l.nonce,
      devicePublicKey: _keys.publicKey,
      deviceId: _deviceId,
    );
    return SignedQr.encode(payload.toJson(), _keys);
  }

  // ------------------------------------------------------------------- pago
  List<PlanSummary> get plans => _receipt?.plans ?? const [];

  /// QR de solicitud de pago (validez 5 min). Mostrarlo NO equivale a pagar.
  Future<PayRequest> payRequestQr(String planId) async {
    final l = _link;
    if (l == null || _receipt == null) throw StateError('El teléfono no está vinculado.');
    final createdAt = now;
    final payload = PayRequestPayload(
      clientId: l.clientId,
      deviceId: _deviceId,
      planId: planId,
      nonce: Ids.shortId(),
      createdAt: createdAt,
    );
    final qr = await SignedQr.encode(payload.toJson(), _keys);
    return PayRequest(qr, createdAt.add(QrTiming.payRequestValidity));
  }

  // ----------------------------------------------------------------- recibo
  /// Paso 3 / tras cada pago: escanear el recibo firmado del administrador.
  Future<ReceiptPayload> scanReceipt(String raw) async {
    final l = _link;
    if (l == null) throw const FormatException('Primero vincula tu teléfono con el gimnasio.');
    final parsed = SignedQr.parse(raw);
    if (parsed == null || parsed.type != QrType.receipt) {
      throw const FormatException('Este QR no es un recibo del gimnasio.');
    }
    if (!await parsed.verifyWith(l.adminPublicKey)) {
      throw const FormatException('Recibo no firmado por tu gimnasio.');
    }
    final r = ReceiptPayload.tryParse(parsed.payload);
    if (r == null) throw const FormatException('Recibo dañado.');
    if (r.gymId != l.gymId || r.clientId != l.clientId) {
      throw const FormatException('Este recibo pertenece a otra persona.');
    }
    final current = _receipt;
    if (current != null && r.version <= current.version) {
      throw const FormatException('Este recibo es antiguo; ya tienes datos más recientes.');
    }
    await _repo.saveReceipt(r, now);
    if (r.paymentId != null) {
      await _repo.addHistory({
        'pi': r.paymentId,
        'pn': r.paymentPlanName,
        'pa': r.paymentAmountCents,
        'pt': r.paymentAt?.toIso8601String(),
        'x': r.expiresAt?.toIso8601String(),
      });
    }
    _receipt = r;
    await rescheduleReminders();
    notifyListeners();
    return r;
  }

  // ----------------------------------------------------------------- estado
  /// Estado local derivado del último recibo (no definitivo si es antiguo).
  MembershipState get state {
    final r = _receipt;
    if (r == null) return MembershipState.never;
    if (!r.active) return MembershipState.disabled;
    final x = r.expiresAt;
    if (x == null) return MembershipState.never;
    if (!now.isBefore(x)) return MembershipState.expired;
    if (x.difference(now).inHours <= 72) return MembershipState.expiring;
    return MembershipState.active;
  }

  bool get isPaid => state.isPaid;

  /// Próximo inicio de turno (hoy o días siguientes de apertura).
  DateTime? get nextShiftStart {
    final r = _receipt;
    if (r == null || r.shiftStart == null) return null;
    final today = DateTime(now.year, now.month, now.day);
    for (var i = 0; i < 8; i++) {
      final d = DateTime(today.year, today.month, today.day + i);
      if (!r.openWeekdays.contains(d.weekday)) continue;
      final start = d.add(Duration(minutes: r.shiftStart!));
      if (start.isAfter(now)) return start;
    }
    return null;
  }

  /// ¿El próximo turno ocurrirá sin membresía pagada?
  bool get nextShiftUnpaid {
    final s = nextShiftStart;
    final x = _receipt?.expiresAt;
    if (s == null) return false;
    return x == null || !s.isBefore(x);
  }

  String get shiftLabel {
    final r = _receipt;
    if (r?.shiftStart == null || r?.shiftEnd == null) return 'Sin turno asignado';
    return '${Fmt.minutes(r!.shiftStart!)} – ${Fmt.minutes(r.shiftEnd!)}';
  }

  /// Programa notificaciones 1 h (configurable) antes de cada turno
  /// en los días en que la membresía no estará pagada.
  Future<void> rescheduleReminders() async {
    final r = _receipt;
    if (r == null || r.shiftStart == null) {
      _scheduledReminders = await NotificationService.instance
          .replaceReminders(const [], title: '', body: '');
      return;
    }
    final times = _planner.plan(
      now: now,
      shiftStartMinute: r.shiftStart!,
      openWeekdays: r.openWeekdays,
      minutesBefore: r.reminderMinutes,
      expiresAt: r.expiresAt,
      accountActive: r.active,
    );
    _scheduledReminders = await NotificationService.instance.replaceReminders(
      times,
      title: 'Tu turno empieza en ${_humanMinutes(r.reminderMinutes)}',
      body: 'No tienes la membresía pagada. Abre la app y muestra tu QR de pago en ${r.gymName}.',
    );
  }

  static String _humanMinutes(int m) => m % 60 == 0 ? '${m ~/ 60} h' : '$m min';

  void tick() => notifyListeners();
}

class PayRequest {
  const PayRequest(this.qr, this.expiresAt);
  final String qr;
  final DateTime expiresAt;
}
