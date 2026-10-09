import '../../core/utils/formatters.dart';

/// Turno horario del gimnasio. Los socios referencian el turno por [id],
/// de modo que al editar sus horas los socios se mueven con él.
class Shift {
  const Shift({
    required this.id,
    required this.startMinute,
    required this.endMinute,
    this.name,
  });

  final String id;

  /// Minutos desde medianoche (0..1439).
  final int startMinute;

  /// Minutos desde medianoche, exclusivo (1..1440).
  final int endMinute;
  final String? name;

  bool containsMinute(int minuteOfDay) => minuteOfDay >= startMinute && minuteOfDay < endMinute;

  String get rangeLabel => '${Fmt.minutes(startMinute)} – ${Fmt.minutes(endMinute)}';
  String get label => (name == null || name!.trim().isEmpty) ? rangeLabel : '$name · $rangeLabel';

  Shift copyWith({int? startMinute, int? endMinute, String? name}) => Shift(
        id: id,
        startMinute: startMinute ?? this.startMinute,
        endMinute: endMinute ?? this.endMinute,
        name: name ?? this.name,
      );

  Map<String, dynamic> toJson() => {'id': id, 's': startMinute, 'e': endMinute, if (name != null) 'n': name};

  factory Shift.fromJson(Map<String, dynamic> j) => Shift(
        id: j['id'] as String,
        startMinute: (j['s'] as num).toInt(),
        endMinute: (j['e'] as num).toInt(),
        name: j['n'] as String?,
      );
}
