/// Tipo de cuenta del socio. Determina el precio aplicado en cada plan.
enum AccountType {
  standard('std', 'Cliente'),
  premium('pre', 'Premium');

  const AccountType(this.code, this.label);
  final String code;
  final String label;

  static AccountType fromCode(String? code) =>
      AccountType.values.firstWhere((e) => e.code == code, orElse: () => AccountType.standard);
}
