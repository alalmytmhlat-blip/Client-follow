import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class Notifs {
  static final _p = FlutterLocalNotificationsPlugin();

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'followups',
      'مواعيد المتابعة',
      channelDescription: 'تذكيرات مواعيد التواصل مع العملاء',
      importance: Importance.max,
      priority: Priority.high,
    ),
  );

  static Future<void> init() async {
    await _p.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@drawable/ic_stat_notify'),
    ));
    final a = _p.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await a?.requestNotificationsPermission();
  }

  static Future<void> schedule(
      int id, String title, String body, DateTime when) async {
    if (!when.isAfter(DateTime.now())) return;
    final t = tz.TZDateTime.fromMillisecondsSinceEpoch(tz.UTC, when.millisecondsSinceEpoch);
    try {
      await _p.zonedSchedule(
        id, title, body, t, _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      await _p.zonedSchedule(
        id, title, body, t, _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  static Future<void> cancel(int id) => _p.cancel(id);
  static Future<void> cancelAll() => _p.cancelAll();

  static Future<void> showNow(String title, String body) =>
      _p.show(2147483000, title, body, _details);
}
