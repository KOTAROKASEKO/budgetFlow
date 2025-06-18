import 'dart:io'; // Required for Platform.isIOS/isAndroid

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:moneymanager/aisupport/TaskModels/task_hive_model.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Kuala_Lumpur'));
    } catch (e) {
      print('Could not set local timezone: $e');
    }

    await _notificationsPlugin.initialize(initializationSettings);
  }

   Future<bool> requestPermissions() async {
    if (Platform.isIOS) {
      return await _notificationsPlugin
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    } else if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      // ↓ この行がAndroidの許可ポップアップを表示します
      return await androidImplementation?.requestNotificationsPermission() ?? false;
    }
    return false;
  }

  Future<void> scheduleTaskReminder({
    required TaskHiveModel task,
  }) async {
    if (task.notificationTime == null) {
      print('Notification time is not set; skipping schedule.');
      return;
    }

    final tz.TZDateTime scheduledNotificationDateTime =
        tz.TZDateTime.from(task.notificationTime!, tz.local);

    if (scheduledNotificationDateTime.isBefore(tz.TZDateTime.now(tz.local))) {
      print('Scheduled time is in the past; skipping schedule.');
      return;
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'task_reminder_channel',
      'Task Reminders',
      channelDescription: 'Channel for task reminder notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.zonedSchedule(
      task.id.hashCode,
      'Task Reminder: ${task.title}',
      'Your task "${task.purpose ?? ''}" is due today.',
      scheduledNotificationDateTime,
      platformDetails,
      // --- FIX for the PlatformException ---
      // Changed from .exact to .inexactAllowWhileIdle to avoid requiring the
      // special "Alarms & Reminders" permission on Android 12+
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
    print('Notification scheduled for: ${task.title} at $scheduledNotificationDateTime');
  }

  Future<void> cancelTaskReminder(String taskId) async {
    final notificationId = taskId.hashCode;
    await _notificationsPlugin.cancel(notificationId);
    print('Notification cancelled for: Task ID Hash $notificationId');
  }

  
}