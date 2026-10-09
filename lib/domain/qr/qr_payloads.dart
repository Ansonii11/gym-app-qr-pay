import '../models/account_type.dart';

/// Plan resumido que viaja al cliente (solo precio de su tipo de cuenta).
class PlanSummary {
  const PlanSummary({required this.id, required this.name, required this.days, required this.priceCents});
  final String id;
  final String name;
  final int days;
  final int priceCents;

  Map<String, dynamic> toJson() => {'i': id, 'n': name, 'd': days, 'p': priceCents};
  factory PlanSummary.fromJson(Map<String, dynamic> j) => PlanSummary(
        id: j['i'] as String,
        name: j['n'] as String? ?? '',
        days: (j['d'] as num?)?.toInt() ?? 0,
        priceCents: (j['p'] as num?)?.toInt() ?? 0,
      );
}

/// Invitación de vinculación (firmada por el administrador).
class InvitePayload {
  const InvitePayload({
    required this.gymId,
    required this.gymName,
    required this.adminPublicKey,
    required this.clientId,
    required this.clientName,
    required this.nonce,
    required this.issuedAt,
  });

  final String gymId;
  final String gymName;
  final String adminPublicKey;
  final String clientId;
  final String clientName;
  final String nonce;
  final DateTime issuedAt;

  Map<String, dynamic> toJson() => {
        't': 'inv',
        'g': gymId,
        'gn': gymName,
        'apk': adminPublicKey,
        'c': clientId,
        'cn': clientName,
        'n': nonce,
        'ts': issuedAt.millisecondsSinceEpoch,
      };

  static InvitePayload? tryParse(Map<String, dynamic> j) {
    try {
      return InvitePayload(
        gymId: j['g'] as String,
        gymName: j['gn'] as String,
        adminPublicKey: j['apk'] as String,
        clientId: j['c'] as String,
        clientName: j['cn'] as String,
        nonce: j['n'] as String,
        issuedAt: DateTime.fromMillisecondsSinceEpoch((j['ts'] as num).toInt()),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Respuesta del dispositivo cliente con su clave pública (firmada por el cliente).
class LinkPayload {
  const LinkPayload({
    required this.clientId,
    required this.nonce,
    required this.devicePublicKey,
    required this.deviceId,
  });

  final String clientId;
  final String nonce;
  final String devicePublicKey;
  final String deviceId;

  Map<String, dynamic> toJson() => {'t': 'lnk', 'c': clientId, 'n': nonce, 'dpk': devicePublicKey, 'd': deviceId};

  static LinkPayload? tryParse(Map<String, dynamic> j) {
    try {
      return LinkPayload(
        clientId: j['c'] as String,
        nonce: j['n'] as String,
        devicePublicKey: j['dpk'] as String,
        deviceId: j['d'] as String,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Solicitud de pago (firmada por el dispositivo del cliente). No implica pago.
class PayRequestPayload {
  const PayRequestPayload({
    required this.clientId,
    required this.deviceId,
    required this.planId,
    required this.nonce,
    required this.createdAt,
  });

  final String clientId;
  final String deviceId;
  final String planId;
  final String nonce;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        't': 'pay',
        'c': clientId,
        'd': deviceId,
        'p': planId,
        'n': nonce,
        'ts': createdAt.millisecondsSinceEpoch,
      };

  static PayRequestPayload? tryParse(Map<String, dynamic> j) {
    try {
      return PayRequestPayload(
        clientId: j['c'] as String,
        deviceId: j['d'] as String,
        planId: j['p'] as String,
        nonce: j['n'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch((j['ts'] as num).toInt()),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Recibo / estado firmado por el administrador. Es la ÚNICA prueba digital
/// que actualiza el estado local del cliente (regla 8).
class ReceiptPayload {
  const ReceiptPayload({
    required this.gymId,
    required this.gymName,
    required this.clientId,
    required this.clientName,
    required this.accountType,
    required this.active,
    required this.version,
    required this.issuedAt,
    required this.expiresAt,
    required this.plans,
    required this.openWeekdays,
    required this.reminderMinutes,
    required this.currency,
    this.shiftStart,
    this.shiftEnd,
    this.shiftName,
    this.paymentId,
    this.paymentAmountCents,
    this.paymentPlanName,
    this.paymentAt,
  });

  final String gymId;
  final String gymName;
  final String clientId;
  final String clientName;
  final AccountType accountType;
  final bool active;
  final int version;
  final DateTime issuedAt;
  final DateTime? expiresAt;
  final List<PlanSummary> plans;
  final List<int> openWeekdays;
  final int reminderMinutes;
  final String currency;
  final int? shiftStart;
  final int? shiftEnd;
  final String? shiftName;
  final String? paymentId;
  final int? paymentAmountCents;
  final String? paymentPlanName;
  final DateTime? paymentAt;

  Map<String, dynamic> toJson() => {
        't': 'rcp',
        'g': gymId,
        'gn': gymName,
        'c': clientId,
        'cn': clientName,
        'ty': accountType.code,
        'a': active ? 1 : 0,
        'v': version,
        'ts': issuedAt.millisecondsSinceEpoch,
        'x': expiresAt?.millisecondsSinceEpoch,
        'pl': plans.map((e) => e.toJson()).toList(),
        'od': openWeekdays,
        'rm': reminderMinutes,
        'cu': currency,
        if (shiftStart != null) 'ss': shiftStart,
        if (shiftEnd != null) 'se': shiftEnd,
        if (shiftName != null) 'sn': shiftName,
        if (paymentId != null) 'pi': paymentId,
        if (paymentAmountCents != null) 'pa': paymentAmountCents,
        if (paymentPlanName != null) 'pn': paymentPlanName,
        if (paymentAt != null) 'pt': paymentAt!.millisecondsSinceEpoch,
      };

  static DateTime? _date(dynamic v) => v == null ? null : DateTime.fromMillisecondsSinceEpoch((v as num).toInt());

  static ReceiptPayload? tryParse(Map<String, dynamic> j) {
    try {
      return ReceiptPayload(
        gymId: j['g'] as String,
        gymName: j['gn'] as String,
        clientId: j['c'] as String,
        clientName: j['cn'] as String,
        accountType: AccountType.fromCode(j['ty'] as String?),
        active: (j['a'] as num?)?.toInt() == 1,
        version: (j['v'] as num).toInt(),
        issuedAt: _date(j['ts'])!,
        expiresAt: _date(j['x']),
        plans: (j['pl'] as List? ?? const [])
            .map((e) => PlanSummary.fromJson(e as Map<String, dynamic>))
            .toList(),
        openWeekdays: (j['od'] as List? ?? const []).map((e) => (e as num).toInt()).toList(),
        reminderMinutes: (j['rm'] as num?)?.toInt() ?? 60,
        currency: j['cu'] as String? ?? r'$',
        shiftStart: (j['ss'] as num?)?.toInt(),
        shiftEnd: (j['se'] as num?)?.toInt(),
        shiftName: j['sn'] as String?,
        paymentId: j['pi'] as String?,
        paymentAmountCents: (j['pa'] as num?)?.toInt(),
        paymentPlanName: j['pn'] as String?,
        paymentAt: _date(j['pt']),
      );
    } catch (_) {
      return null;
    }
  }
}
