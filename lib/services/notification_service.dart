import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/task_model.dart';
import '../models/event_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> init() async {
    if (kIsWeb) return;
    if (_isInitialized) return;

    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
            defaultPresentAlert: true,
            defaultPresentBadge: true,
            defaultPresentSound: true,
          );

      await flutterLocalNotificationsPlugin.initialize(
        settings: const InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
          macOS: initializationSettingsDarwin,
        ),
      );

      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'taskflow_task_channel',
        'Task Reminders',
        description: 'Notifications for task start times and reminders',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );
      final androidImplementation = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidImplementation?.createNotificationChannel(channel);

      _isInitialized = true;
      await requestPermissions();
    } catch (e) {
      print('NotificationService plugin init error: $e');
    }

    try {
      tz.initializeTimeZones();
      final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = timeZoneInfo.toString();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      print('NotificationService timezone init error: $e');
    }
  }

  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    bool granted = false;

    try {
      final status = await Permission.notification.request();
      granted = status.isGranted;

      final androidImplementation = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidImplementation != null) {
        final notifGranted = await androidImplementation
            .requestNotificationsPermission();
        await androidImplementation.requestExactAlarmsPermission();
        granted = notifGranted ?? granted;
      }

      final iosImplementation = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (iosImplementation != null) {
        final iosGranted = await iosImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        granted = iosGranted ?? granted;
      }

      final macosImplementation = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      if (macosImplementation != null) {
        final macGranted = await macosImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        granted = macGranted ?? granted;
      }
    } catch (e) {
      print('NotificationService requestPermissions error: $e');
    }

    return granted;
  }

  Future<void> showTestNotification() async {
    if (kIsWeb) return;
    if (!_isInitialized) {
      await init();
    }
    await requestPermissions();

    const androidDetails = AndroidNotificationDetails(
      'taskflow_task_channel',
      'Task Reminders',
      channelDescription: 'Notifications for task start times and reminders',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      id: 99999,
      title: 'Kronom Notification Working 🎉',
      body: 'You will receive reminders for your scheduled tasks!',
      notificationDetails: details,
    );
  }

  Future<void> scheduleTaskNotification(Task task) async {
    if (kIsWeb) return;
    // If completed or reminder disabled (-1 or null), cancel any scheduled notification
    if (task.isCompleted ||
        task.notificationMinutesBefore == null ||
        task.notificationMinutesBefore == -1) {
      await cancelNotification(task.id.hashCode);
      return;
    }

    // Determine target time: use startTime if set, otherwise dueDate
    final DateTime? targetTime = task.startTime ?? task.dueDate;
    if (targetTime == null) return;

    final int minutesBefore = task.notificationMinutesBefore ?? 0;
    DateTime scheduledDateTime = targetTime.subtract(
      Duration(minutes: minutesBefore),
    );

    // If scheduled time already passed slightly but task has not started yet,
    // notify in 5 seconds so the user still receives the reminder.
    if (scheduledDateTime.isBefore(DateTime.now())) {
      if (targetTime.isAfter(DateTime.now())) {
        scheduledDateTime = DateTime.now().add(const Duration(seconds: 5));
      } else {
        return;
      }
    }

    if (!_isInitialized) {
      await init();
    }
    await requestPermissions();

    final androidDetails = const AndroidNotificationDetails(
      'taskflow_task_channel',
      'Task Reminders',
      channelDescription: 'Notifications for task start times and reminders',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    final darwinDetails = const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    // Cancel any existing notification for this task to avoid duplicates
    await cancelNotification(task.id.hashCode);

    String title;
    String body;
    if (minutesBefore > 0) {
      String timeLabel;
      if (minutesBefore < 60) {
        timeLabel = '$minutesBefore minutes';
      } else if (minutesBefore == 60) {
        timeLabel = '1 hour';
      } else if (minutesBefore == 1440) {
        timeLabel = '1 day';
      } else {
        timeLabel = '$minutesBefore minutes';
      }
      title = 'Upcoming Task Reminder ⏰';
      body = 'Your task "${task.title}" starts in $timeLabel.';
    } else {
      title = 'Time to Focus! 🚀';
      body = 'Your task "${task.title}" is scheduled to start now.';
    }

    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id: task.id.hashCode,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(scheduledDateTime, tz.local),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      print('NotificationService schedule error: $e');
    }
  }

  Future<void> scheduleEventNotification(Event event) async {
    if (kIsWeb) return;
    if (event.notificationMinutesBefore == null ||
        event.notificationMinutesBefore == -1) {
      await cancelNotification(event.id.hashCode);
      return;
    }

    final DateTime targetTime = event.startTime;
    final int minutesBefore = event.notificationMinutesBefore ?? 0;
    DateTime scheduledDateTime = targetTime.subtract(
      Duration(minutes: minutesBefore),
    );

    if (scheduledDateTime.isBefore(DateTime.now())) {
      if (targetTime.isAfter(DateTime.now())) {
        scheduledDateTime = DateTime.now().add(const Duration(seconds: 5));
      } else {
        return;
      }
    }

    if (!_isInitialized) {
      await init();
    }
    await requestPermissions();

    final androidDetails = const AndroidNotificationDetails(
      'taskflow_task_channel',
      'Task Reminders',
      channelDescription: 'Notifications for task start times and reminders',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    final darwinDetails = const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await cancelNotification(event.id.hashCode);

    String title;
    String body;
    if (minutesBefore > 0) {
      String timeLabel;
      if (minutesBefore < 60) {
        timeLabel = '$minutesBefore minutes';
      } else if (minutesBefore == 60) {
        timeLabel = '1 hour';
      } else if (minutesBefore == 1440) {
        timeLabel = '1 day';
      } else {
        timeLabel = '$minutesBefore minutes';
      }
      title = 'Upcoming Event Reminder 🗓️';
      body = 'Your event "${event.title}" starts in $timeLabel.';
    } else {
      title = 'Event Starting Now! 🗓️';
      body = 'Your event "${event.title}" is starting now.';
    }

    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id: event.id.hashCode,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(scheduledDateTime, tz.local),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      print('NotificationService scheduleEventNotification error: $e');
    }
  }

  Future<void> cancelNotification(int id) async {
    if (kIsWeb) return;
    await flutterLocalNotificationsPlugin.cancel(id: id);
  }

  Future<void> clearDeliveredNotifications() async {
    if (kIsWeb) return;
    try {
      final activeNotifications = await flutterLocalNotificationsPlugin
          .getActiveNotifications();
      for (final active in activeNotifications) {
        if (active.id != null) {
          await flutterLocalNotificationsPlugin.cancel(id: active.id!);
        }
      }
    } catch (e) {
      print('clearDeliveredNotifications error: $e');
    }
  }
}
