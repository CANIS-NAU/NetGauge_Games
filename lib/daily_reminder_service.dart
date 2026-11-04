import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

// schedules a single repeating local notification that reminds the user to check into the app once per day
class DailyReminderService {
  static const int _notificationId = 1001;
  static const int _reminderHour = 17; // 5:00 PM, device local time
  static const int _reminderMinute = 0;

  static const String _prefsBoxName = 'notification_prefs';
  static const String _enabledKey = 'dailyReminderEnabled';
  static Box? _prefsBox;

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    try {
      // Hive is already initialized by LoggingService.init(), which runs before this in main()
      _prefsBox = await Hive.openBox(_prefsBoxName);

      tz_data.initializeTimeZones();
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));

      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/launcher_icon'),
          // permission is requested explicitly in schedule()
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      debugPrint("[DAILY_REMINDER] Initialized with timezone ${timezone.identifier}.");
    } catch (e) {
      debugPrint("[DAILY_REMINDER] Error initializing: $e");
    }
  }

  // the reminder is on by default until the user turns it off on the profile page
  static bool get isEnabled => _prefsBox?.get(_enabledKey, defaultValue: true) ?? true;

  // saves the user's preference and schedules or cancels the reminder to match.
  // returns the preference actually in effect (false if the user enabled it but denied the OS permission)
  static Future<bool> setEnabled(bool enabled) async {
    if (enabled) {
      enabled = await schedule();
    } else {
      await cancel();
    }
    await _prefsBox?.put(_enabledKey, enabled);
    return enabled;
  }

  // schedules the reminder only if the user has not turned it off, e.g. on launch/login
  static Future<void> scheduleIfEnabled() async {
    if (isEnabled) await schedule();
  }

  // asks for notification permission, then (re)schedules the daily reminder. returns whether it was scheduled
  static Future<bool> schedule() async {
    try {
      final granted = await _requestPermission();
      if (!granted) {
        debugPrint("[DAILY_REMINDER] Notification permission not granted, not scheduling.");
        return false;
      }

      final now = tz.TZDateTime.now(tz.local);
      var firstReminder = tz.TZDateTime(tz.local, now.year, now.month, now.day, _reminderHour, _reminderMinute);
      if (firstReminder.isBefore(now)) {
        firstReminder = firstReminder.add(const Duration(days: 1));
      }

      // reusing the same id replaces any existing reminder, so calling this on every launch never creates duplicates
      await _plugin.zonedSchedule(
        id: _notificationId,
        title: 'Time to check in!',
        body: 'Open NetGauge to play a game and help map internet quality today.',
        scheduledDate: firstReminder,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_reminder',
            'Daily reminder',
            channelDescription: 'Once-a-day reminder to check into the app',
          ),
          iOS: DarwinNotificationDetails(),
        ),
        // inexact scheduling avoids needing the exact-alarm permission
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time, // repeat daily at the same time
      );
      debugPrint("[DAILY_REMINDER] Scheduled daily reminder starting $firstReminder.");
      return true;
    } catch (e) {
      debugPrint("[DAILY_REMINDER] Error scheduling reminder: $e");
      return false;
    }
  }

  // cancels the reminder, e.g. when the user logs out
  static Future<void> cancel() async {
    try {
      await _plugin.cancel(id: _notificationId);
    } catch (e) {
      debugPrint("[DAILY_REMINDER] Error cancelling reminder: $e");
    }
  }

  static Future<bool> _requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    }
    return false;
  }
}
