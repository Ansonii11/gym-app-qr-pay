/// Estado derivado de la membresía de un socio.
enum MembershipState {
  active('Al día'),
  expiring('Por vencer'),
  expired('Vencido'),
  never('Sin pagos'),
  disabled('Desactivado');

  const MembershipState(this.label);
  final String label;

  bool get isPaid => this == active || this == expiring;
}

class Membership {
  const Membership({required this.state, this.expiresAt, this.lastPaymentAt, this.currentPlanName});

  final MembershipState state;

  /// Instante exclusivo en que deja de estar vigente.
  final DateTime? expiresAt;
  final DateTime? lastPaymentAt;
  final String? currentPlanName;

  int daysLeft(DateTime now) {
    final e = expiresAt;
    if (e == null) return 0;
    final diff = e.difference(now);
    if (diff.isNegative) return 0;
    return (diff.inHours / 24).ceil();
  }
}
