/// Estado de un pago. Los pagos son inmutables: solo cambia su estado
/// mediante "deshacer" (ventana de 10 s) o "anular" (con motivo y auditoría).
enum PaymentStatus {
  confirmed('ok', 'Confirmado'),
  undone('undo', 'Deshecho'),
  voided('void', 'Anulado');

  const PaymentStatus(this.code, this.label);
  final String code;
  final String label;

  static PaymentStatus fromCode(String? c) =>
      PaymentStatus.values.firstWhere((e) => e.code == c, orElse: () => PaymentStatus.confirmed);
}

enum PaymentMethod {
  cash('cash', 'Efectivo'),
  transfer('transfer', 'Transferencia'),
  other('other', 'Otro');

  const PaymentMethod(this.code, this.label);
  final String code;
  final String label;

  static PaymentMethod fromCode(String? c) =>
      PaymentMethod.values.firstWhere((e) => e.code == c, orElse: () => PaymentMethod.cash);
}

/// Clasificación del pago respecto al estado previo de la membresía.
enum PaymentKind {
  first('first', 'Primer pago'),
  renewal('renew', 'Renovación'),
  advance('adv', 'Pago anticipado'),
  recovery('recov', 'Recuperación de vencimiento');

  const PaymentKind(this.code, this.label);
  final String code;
  final String label;

  static PaymentKind fromCode(String? c) =>
      PaymentKind.values.firstWhere((e) => e.code == c, orElse: () => PaymentKind.renewal);
}

class Payment {
  const Payment({
    required this.id,
    required this.clientId,
    required this.planId,
    required this.planName,
    required this.durationDays,
    required this.amountCents,
    required this.method,
    required this.createdAt,
    required this.periodStart,
    required this.periodEnd,
    required this.kind,
    required this.replacePeriod,
    this.shiftId,
    this.status = PaymentStatus.confirmed,
    this.statusReason,
    this.statusAt,
    this.viaQr = true,
    this.requestNonce,
  });

  final String id;
  final String clientId;
  final String planId;
  final String planName;
  final int durationDays;
  final int amountCents;
  final PaymentMethod method;

  /// Hora administrativa del cobro (fuente de verdad).
  final DateTime createdAt;
  final DateTime periodStart;
  final DateTime periodEnd;
  final PaymentKind kind;
  final bool replacePeriod;
  final String? shiftId;
  final PaymentStatus status;
  final String? statusReason;
  final DateTime? statusAt;
  final bool viaQr;
  final String? requestNonce;

  bool get counts => status == PaymentStatus.confirmed;

  Payment withStatus(PaymentStatus s, {String? reason, required DateTime at}) => Payment(
        id: id,
        clientId: clientId,
        planId: planId,
        planName: planName,
        durationDays: durationDays,
        amountCents: amountCents,
        method: method,
        createdAt: createdAt,
        periodStart: periodStart,
        periodEnd: periodEnd,
        kind: kind,
        replacePeriod: replacePeriod,
        shiftId: shiftId,
        status: s,
        statusReason: reason,
        statusAt: at,
        viaQr: viaQr,
        requestNonce: requestNonce,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'cid': clientId,
        'planId': planId,
        'planName': planName,
        'days': durationDays,
        'amount': amountCents,
        'method': method.code,
        'at': createdAt.toIso8601String(),
        'from': periodStart.toIso8601String(),
        'to': periodEnd.toIso8601String(),
        'kind': kind.code,
        'replace': replacePeriod,
        'shiftId': shiftId,
        'status': status.code,
        'reason': statusReason,
        'statusAt': statusAt?.toIso8601String(),
        'qr': viaQr,
        'nonce': requestNonce,
      };

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
        id: j['id'] as String,
        clientId: j['cid'] as String,
        planId: j['planId'] as String? ?? '',
        planName: j['planName'] as String? ?? '',
        durationDays: (j['days'] as num?)?.toInt() ?? 0,
        amountCents: (j['amount'] as num?)?.toInt() ?? 0,
        method: PaymentMethod.fromCode(j['method'] as String?),
        createdAt: DateTime.parse(j['at'] as String),
        periodStart: DateTime.parse(j['from'] as String),
        periodEnd: DateTime.parse(j['to'] as String),
        kind: PaymentKind.fromCode(j['kind'] as String?),
        replacePeriod: j['replace'] as bool? ?? false,
        shiftId: j['shiftId'] as String?,
        status: PaymentStatus.fromCode(j['status'] as String?),
        statusReason: j['reason'] as String?,
        statusAt: DateTime.tryParse(j['statusAt'] as String? ?? ''),
        viaQr: j['qr'] as bool? ?? true,
        requestNonce: j['nonce'] as String?,
      );
}
