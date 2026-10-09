/// Abstracción del reloj para poder testear reglas dependientes del tiempo.
abstract class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}
