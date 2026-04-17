import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Local notifications (scheduled + immediate). Not remote push.
class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static const String notificationsEnabledPrefKey = 'notifications_enabled';

  /// Call once before any zoned scheduling. Safe to call multiple times.
  static Future<void> configureLocalTimeZone() async {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Australia/Sydney'));
  }

  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _plugin.initialize(settings);
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    final android =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  /// Show an immediate notification.
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'adhd_support_channel',
      'ADHD Support',
      channelDescription: 'ADHD Support Australia notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    await _plugin.show(id, title, body, details);
  }

  /// Schedule a repeating daily notification at [hour]:[minute] local time.
  Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'adhd_support_daily',
      'Daily Reminders',
      channelDescription: 'Daily ADHD Support reminders',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      _nextInstanceOfTime(hour, minute),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Schedules the three default daily reminders (morning, focus, mood).
  Future<void> scheduleAllDailyReminders() async {
    await scheduleDailyNotification(
      id: 1,
      title: 'Good morning! Ready to focus?',
      body: 'Check your tasks for today and pick your most important one.',
      hour: 8,
      minute: 0,
    );
    await scheduleDailyNotification(
      id: 2,
      title: 'How are you feeling today?',
      body: 'Take 10 seconds to check in with yourself.',
      hour: 20,
      minute: 0,
    );
    await scheduleDailyNotification(
      id: 3,
      title: 'Afternoon focus time',
      body: 'Try a 25-minute Pomodoro session to finish your day strong.',
      hour: 14,
      minute: 0,
    );
  }

  /// Schedules daily reminders only if the user has not disabled them in settings.
  Future<void> scheduleDailyRemindersIfEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(notificationsEnabledPrefKey) ?? true) {
      await scheduleAllDailyReminders();
    }
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }
}
