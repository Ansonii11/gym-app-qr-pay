import '../../domain/models/client.dart';
import '../../domain/models/membership.dart';
import '../../domain/models/plan.dart';
import '../../domain/models/shift.dart';
import '../../domain/qr/qr_payloads.dart';
import '../../domain/services/membership_calculator.dart';

/// Semáforo del resultado de un escaneo (PRD §7.3).
enum ScanVerdict { ok, warning, invalid }

/// Resultado de validar un QR de solicitud de pago.
class PayScanResult {
  const PayScanResult({
    required this.verdict,
    required this.message,
    this.client,
    this.plan,
    this.membership,
    this.preview,
    this.detectedShift,
    this.request,
    this.warnings = const [],
    this.alreadyPaidPaymentId,
  });

  factory PayScanResult.invalid(String message) =>
      PayScanResult(verdict: ScanVerdict.invalid, message: message);

  final ScanVerdict verdict;
  final String message;
  final Client? client;
  final Plan? plan;
  final Membership? membership;
  final PaymentPreview? preview;

  /// Turno detectado automáticamente según la hora administrativa.
  final Shift? detectedShift;
  final PayRequestPayload? request;
  final List<String> warnings;

  /// Si la solicitud ya fue cobrada (idempotencia): id del pago existente.
  final String? alreadyPaidPaymentId;

  bool get canConfirm => verdict != ScanVerdict.invalid && client != null && plan != null;
}
