import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Programación de notificaciones locales (sin internet).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Rango de ids reservado para recordatorios de pago.
  static const _reminderBaseId = 1000;
  static const _maxReminders = 40;

  bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> init() async {
    if (_ready || !supported) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    );
    _ready = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  Future<bool> requestPermission() async {
    if (!supported) return false;
    await init();
    final granted = await _android?.requestNotificationsPermission() ?? false;
    return granted;
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'payment_reminders',
      'Recordatorios de pago',
      channelDescription: 'Aviso antes de tu turno cuando tu membresía no está pagada',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  /// Reemplaza todos los recordatorios programados por [times].
  Future<int> replaceReminders(List<DateTime> times, {required String title, required String body}) async {
    if (!supported) return 0;
    await init();
    for (var i = 0; i < _maxReminders; i++) {
      await _plugin.cancel(id: _reminderBaseId + i);
    }
    final exact = await _android?.canScheduleExactNotifications() ?? false;
    final mode = exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;
    var n = 0;
    for (final t in times.take(_maxReminders)) {
      await _plugin.zonedSchedule(
        id: _reminderBaseId + n,
        scheduledDate: tz.TZDateTime.from(t, tz.local),
        notificationDetails: _details,
        androidScheduleMode: mode,
        title: title,
        body: body,
      );
      n++;
    }
    return n;
  }

  Future<void> showNow({required String title, required String body}) async {
    if (!supported) return;
    await init();
    await _plugin.show(id: 999, title: title, body: body, notificationDetails: _details);
  }
}
