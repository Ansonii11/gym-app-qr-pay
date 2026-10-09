/// Tipos de QR del protocolo. Cada caso de uso usa un QR distinto (PRD §10.1).
class QrType {
  QrType._();

  /// Invitación de vinculación (admin → cliente).
  static const invite = 'inv';

  /// Confirmación de vinculación con clave del dispositivo (cliente → admin).
  static const link = 'lnk';

  /// Solicitud de pago (cliente → admin). Validez 5 min.
  static const payRequest = 'pay';

  /// Recibo / actualización de estado firmada (admin → cliente).
  static const receipt = 'rcp';
}

/// Tiempos del protocolo.
class QrTiming {
  QrTiming._();
  static const payRequestValidity = Duration(minutes: 5);
  static const clockTolerance = Duration(seconds: 90);
  static const inviteValidity = Duration(hours: 24);
}
