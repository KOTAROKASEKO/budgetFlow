import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:moneymanager/aisupport/TaskModels/task_hive_model.dart';
import 'package:timezone/data/latest_all.dart' as tz_data; 
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    tz_data.initializeTimeZones();

    await _notificationsPlugin.initialize(initializationSettings);
  }

  Future<void> scheduleTaskReminder({
    required TaskHiveModel task,
    required DateTime scheduledDate,
  }) async {
    final tz.TZDateTime scheduledNotificationDateTime = tz.TZDateTime(
      tz.local,
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
      9, // 朝9時
    );

    if (scheduledNotificationDateTime.isBefore(tz.TZDateTime.now(tz.local))) {
      print('スケジュール日時が過去です。通知は設定されません。');
      return;
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'task_reminder_channel',
      'Task Reminders',
      channelDescription: 'タスクリマインダーの通知チャンネル',
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
      'タスクリマインダー: ${task.title}',
      '今日がタスク「${task.purpose ?? ''}」の期日です。',
      scheduledNotificationDateTime,
      platformDetails,
      androidScheduleMode: AndroidScheduleMode.exact,
    );
    print('通知をスケジュールしました: ${task.title} at $scheduledNotificationDateTime');
  }

  Future<void> cancelTaskReminder(String taskId) async {
    final notificationId = taskId.hashCode;
    await _notificationsPlugin.cancel(notificationId);
    print('通知をキャンセルしました: Task ID Hash $notificationId');
  }
}