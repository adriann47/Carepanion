import 'dart:io' show Platform;
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'notification_prefs.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'reminder_service.dart';

class NotificationService {
  NotificationService._();
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings();
    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );
    // Initialize timezones for zoned scheduling
    try {
      tz.initializeTimeZones();
      // tz.local will usually reflect device timezone; initialize tz database
      // (explicit native timezone plugin removed for compatibility)
    } catch (_) {}

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) async {
        final payload = resp.payload;
        if (payload != null && payload.isNotEmpty) {
          try {
            final data = jsonDecode(payload) as Map<String, dynamic>;
            final id = data['task_id']?.toString();
            if (id != null) {
              await ReminderService.showPopupForTaskId(id);
            }
          } catch (_) {}
        }
      },
      // Background tap handler (best-effort; may require additional setup on iOS)
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Ensure Android notification channel exists with high importance so
    // notifications show in the status bar / drawer (not silently).
    if (Platform.isAndroid) {
      try {
        final androidImpl = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

        // Create/overwrite a channel with the proper importance and vibration
        final vib = Int64List.fromList([0, 300, 200, 300]);
        final channel = AndroidNotificationChannel(
          'carepanion_reminders', // id
          'Task Reminders', // name
          description: 'Reminder notifications for due tasks',
          importance: Importance.max,
          playSound: true,
          showBadge: true,
          enableVibration: true,
          vibrationPattern: vib,
        );
        await androidImpl?.createNotificationChannel(channel);
      } catch (_) {}
    }
    if (Platform.isAndroid) {
      final androidImpl = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidImpl?.requestNotificationsPermission();

      // On Android 12+ users may need to grant "Alarms & reminders"
      // special access for exact alarms.
      try {
        await _native.invokeMethod('requestExactAlarmPermissionIfNeeded');
      } catch (_) {}
    }
    // Request iOS permissions explicitly
    final iosImpl = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await iosImpl?.requestPermissions(alert: true, badge: true, sound: true);
    _initialized = true;
  }

  // MethodChannel to call native alarm scheduling APIs
  static const MethodChannel _native = MethodChannel('carepanion.reminder');

  /// If the app was launched by tapping a notification, return its payload.
  /// Call this after the Flutter UI has been initialized (after runApp).
  static Future<String?> getInitialPayload() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details != null && details.didNotificationLaunchApp) {
        return details.notificationResponse?.payload;
      }
    } catch (_) {}
    return null;
  }

  static NotificationDetails _details() {
    final vibrate = NotificationPreferences.vibrationEnabled.value;
    final AndroidNotificationDetails android = AndroidNotificationDetails(
      'carepanion_reminders',
      'Task Reminders',
      channelDescription: 'Reminder notifications for due tasks',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      enableVibration: vibrate,
      vibrationPattern: vibrate ? Int64List.fromList([0, 300, 200, 300]) : null,
      playSound: true,
    );
    const DarwinNotificationDetails ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    return NotificationDetails(android: android, iOS: ios);
  }

  static Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!NotificationPreferences.pushEnabled.value) return;
    await _plugin.show(id, title, body, _details(), payload: payload);
  }

  static Future<void> cancel(int id) async {
    await _plugin.cancel(id);
    try {
      await _native.invokeMethod('cancelAlarm', {'id': id});
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('NotificationService: native cancelAlarm failed: $e');
      }
    }
  }

  static Future<void> scheduleAt({
    required int id,
    required DateTime whenLocal,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!NotificationPreferences.pushEnabled.value) return;
    final tzTime = tz.TZDateTime.from(whenLocal, tz.local);
    // Schedule a visual local notification as fallback
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzTime,
      _details(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );

    // Also schedule a native exact alarm that starts the full-screen Activity
    try {
      final epoch = whenLocal.toUtc().millisecondsSinceEpoch;
      await _native.invokeMethod('scheduleAlarm', {
        'when': epoch,
        'id': id,
        'payload': payload ?? '',
      });
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('NotificationService: native scheduleAlarm failed: $e');
      }
    }
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  final payload = response.payload;
  if (payload == null || payload.isEmpty) return;
  try {
    final data = jsonDecode(payload) as Map<String, dynamic>;
    final id = data['task_id']?.toString();
    if (id != null) {
      await ReminderService.showPopupForTaskId(id);
    }
  } catch (_) {}
}
