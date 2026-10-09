import 'account_type.dart';

/// Plan de membresía configurable (semanal, mensual, etc.).
class Plan {
  const Plan({
    required this.id,
    required this.name,
    required this.durationDays,
    required this.priceStandardCents,
    required this.pricePremiumCents,
    this.active = true,
  });

  final String id;
  final String name;
  final int durationDays;
  final int priceStandardCents;
  final int pricePremiumCents;
  final bool active;

  int priceFor(AccountType type) =>
      type == AccountType.premium ? pricePremiumCents : priceStandardCents;

  Plan copyWith({
    String? name,
    int? durationDays,
    int? priceStandardCents,
    int? pricePremiumCents,
    bool? active,
  }) =>
      Plan(
        id: id,
        name: name ?? this.name,
        durationDays: durationDays ?? this.durationDays,
        priceStandardCents: priceStandardCents ?? this.priceStandardCents,
        pricePremiumCents: pricePremiumCents ?? this.pricePremiumCents,
        active: active ?? this.active,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'days': durationDays,
        'pStd': priceStandardCents,
        'pPre': pricePremiumCents,
        'active': active,
      };

  factory Plan.fromJson(Map<String, dynamic> j) => Plan(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Plan',
        durationDays: (j['days'] as num?)?.toInt() ?? 30,
        priceStandardCents: (j['pStd'] as num?)?.toInt() ?? 0,
        pricePremiumCents: (j['pPre'] as num?)?.toInt() ?? 0,
        active: j['active'] as bool? ?? true,
      );
}
