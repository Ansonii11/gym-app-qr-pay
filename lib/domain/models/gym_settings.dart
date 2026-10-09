/// Configuración general del gimnasio (solo editable por el administrador).
class GymSettings {
  const GymSettings({
    this.gymName = 'Mi Gimnasio',
    this.currencySymbol = r'$',
    this.openWeekdays = const [1, 2, 3, 4, 5, 6],
    this.expiringThresholdDays = 3,
    this.reminderMinutesBefore = 60,
  });

  final String gymName;
  final String currencySymbol;

  /// Días de apertura (DateTime.weekday: 1 = lunes … 7 = domingo).
  final List<int> openWeekdays;
  final int expiringThresholdDays;
  final int reminderMinutesBefore;

  GymSettings copyWith({
    String? gymName,
    String? currencySymbol,
    List<int>? openWeekdays,
    int? expiringThresholdDays,
    int? reminderMinutesBefore,
  }) =>
      GymSettings(
        gymName: gymName ?? this.gymName,
        currencySymbol: currencySymbol ?? this.currencySymbol,
        openWeekdays: openWeekdays ?? this.openWeekdays,
        expiringThresholdDays: expiringThresholdDays ?? this.expiringThresholdDays,
        reminderMinutesBefore: reminderMinutesBefore ?? this.reminderMinutesBefore,
      );

  Map<String, dynamic> toJson() => {
        'gym': gymName,
        'cur': currencySymbol,
        'days': openWeekdays,
        'expDays': expiringThresholdDays,
        'remind': reminderMinutesBefore,
      };

  factory GymSettings.fromJson(Map<String, dynamic> j) => GymSettings(
        gymName: j['gym'] as String? ?? 'Mi Gimnasio',
        currencySymbol: j['cur'] as String? ?? r'$',
        openWeekdays: (j['days'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [1, 2, 3, 4, 5, 6],
        expiringThresholdDays: (j['expDays'] as num?)?.toInt() ?? 3,
        reminderMinutesBefore: (j['remind'] as num?)?.toInt() ?? 60,
      );
}
