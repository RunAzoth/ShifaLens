import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../core/models/models.dart';
import '../../core/services/reminder_service.dart';

class RealReminderService implements ReminderService {
  static const String _kChannelId = 'shifalens_dose_reminders';
  static const String _kChannelName = 'ShifaLens Dose Reminders';
  static const String _kSavedPlanPrefsKey = 'shifalens_scheduled_plan';
  static const String _kSavedMealTimesPrefsKey = 'shifalens_scheduled_mealtimes';

  FlutterLocalNotificationsPlugin? _pluginInstance;
  bool _initialized = false;
  bool _tzInitialized = false;

  RealReminderService({FlutterLocalNotificationsPlugin? plugin})
      : _pluginInstance = plugin;

  FlutterLocalNotificationsPlugin get _plugin =>
      _pluginInstance ??= FlutterLocalNotificationsPlugin();

  void _ensureTimezones() {
    if (_tzInitialized) return;
    _tzInitialized = true;
    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Karachi'));
    } catch (_) {}
  }

  Future<void> _ensureInitialized() async {
    _ensureTimezones();
    if (_initialized) return;
    try {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const initSettings = InitializationSettings(android: androidSettings);
      await _plugin.initialize(settings: initSettings);
      _initialized = true;
    } catch (_) {
      // Safe in headless/test environments without Android platform channel
    }
  }

  @override
  Future<bool> requestPermissions() async {
    await _ensureInitialized();
    try {
      final androidImpl = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidImpl == null) return true;

      final notifGranted =
          await androidImpl.requestNotificationsPermission() ?? false;
      final exactAlarmGranted =
          await androidImpl.requestExactAlarmsPermission() ?? true;

      if (Firebase.apps.isNotEmpty) {
        try {
          await FirebaseMessaging.instance.requestPermission();
        } catch (_) {}
      }

      return notifGranted && exactAlarmGranted;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> scheduleForPlan(DailyPlan p, MealTimes t) async {
    await _ensureInitialized();
    await _persistScheduleForBootReschedule(p, t);

    try {
      await _plugin.cancelAll();
    } catch (_) {}

    final medById = {for (final m in p.scheduled) m.id: m};
    var notificationId = 1000;

    for (final dose in p.doses) {
      if (dose.slot == MealSlot.whenNeeded) continue;
      final med = medById[dose.medicineId];
      if (med == null) continue;

      final hhmm =
          t.hhmm[dose.slot] ?? MealTimes.defaults().hhmm[dose.slot] ?? '08:30';
      final scheduledTime = computeNextInstanceOfTime(
        hhmm,
        relation: dose.relation,
      );
      final texts = formatBilingualNotification(med, dose);

      try {
        await _plugin.zonedSchedule(
          id: notificationId++,
          title: texts.title,
          body: texts.body,
          scheduledDate: scheduledTime,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              _kChannelId,
              _kChannelName,
              channelDescription:
                  'Bilingual Urdu/English medication dose reminders',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: '${med.id}|${dose.slot.name}',
        );
      } catch (_) {
        // Fallback to inexact schedule mode if exact alarm permission is denied
        try {
          await _plugin.zonedSchedule(
            id: notificationId++,
            title: texts.title,
            body: texts.body,
            scheduledDate: scheduledTime,
            notificationDetails: const NotificationDetails(
              android: AndroidNotificationDetails(
                _kChannelId,
                _kChannelName,
                importance: Importance.high,
                priority: Priority.high,
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.time,
            payload: '${med.id}|${dose.slot.name}',
          );
        } catch (_) {}
      }
    }
  }

  /// Restores and reschedules persisted dose reminders on app start / after device boot.
  Future<void> rescheduleSavedPlanIfPresent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final planRaw = prefs.getString(_kSavedPlanPrefsKey);
      final timesRaw = prefs.getString(_kSavedMealTimesPrefsKey);
      if (planRaw == null || timesRaw == null) return;

      final plan = DailyPlan.fromJson(
        jsonDecode(planRaw) as Map<String, dynamic>,
      );
      final times = MealTimes.fromJson(
        jsonDecode(timesRaw) as Map<String, dynamic>,
      );
      await scheduleForPlan(plan, times);
    } catch (_) {}
  }

  Future<void> _persistScheduleForBootReschedule(
    DailyPlan p,
    MealTimes t,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kSavedPlanPrefsKey, jsonEncode(p.toJson()));
      await prefs.setString(_kSavedMealTimesPrefsKey, jsonEncode(t.toJson()));
    } catch (_) {}
  }

  @override
  Future<void> cancelAll() async {
    await _ensureInitialized();
    try {
      await _plugin.cancelAll();
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kSavedPlanPrefsKey);
    } catch (_) {}
  }

  @override
  Future<String?> registerFcmToken() async {
    if (Firebase.apps.isEmpty) return null;
    try {
      final token = await FirebaseMessaging.instance
          .getToken()
          .timeout(const Duration(seconds: 5));
      if (token == null || token.isEmpty) return null;

      final auth = FirebaseAuth.instance;
      final user =
          auth.currentUser ?? (await auth.signInAnonymously()).user;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('devices')
            .doc('fcm')
            .set({
              'token': token,
              'platform': 'android',
              'updatedAtIso': DateTime.now().toUtc().toIso8601String(),
            })
            .timeout(const Duration(seconds: 4));
      }
      return token;
    } catch (_) {
      return null;
    }
  }

  /// Exposed for unit testing bilingual notification text formatting.
  static ({String title, String body}) formatBilingualNotification(
    MedicineLine med,
    DoseEvent dose,
  ) {
    final name = med.brandName ?? med.genericName ?? med.rawText;
    final strength = med.strength != null ? ' (${med.strength})' : '';
    final slotEn = _slotEn(dose.slot);
    final slotUr = _slotUr(dose.slot);
    final relEn = _relationEn(dose.relation);
    final relUr = _relationUr(dose.relation);

    return (
      title: 'شفا لینز یاد دہانی / ShifaLens: $name$strength',
      body: '$name — $slotUr ($relUr) | $relEn $slotEn',
    );
  }

  /// Computes the next TZDateTime occurrence for an "HH:mm" string, applying
  /// a -30 minute offset when MealRelation is `before` or `emptyStomach`.
  tz.TZDateTime computeNextInstanceOfTime(
    String hhmm, {
    MealRelation relation = MealRelation.after,
  }) {
    _ensureTimezones();
    final parts = hhmm.split(':');
    final hour = parts.isNotEmpty ? (int.tryParse(parts[0]) ?? 8) : 8;
    final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 30) : 30;

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour.clamp(0, 23),
      minute.clamp(0, 59),
    );

    if (relation == MealRelation.before ||
        relation == MealRelation.emptyStomach) {
      scheduled = scheduled.subtract(const Duration(minutes: 30));
    }

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static String _slotEn(MealSlot slot) {
    switch (slot) {
      case MealSlot.wakeUp:
        return 'wake-up';
      case MealSlot.suhoor:
        return 'Suhoor';
      case MealSlot.breakfast:
        return 'breakfast';
      case MealSlot.midMorning:
        return 'mid-morning';
      case MealSlot.lunch:
        return 'lunch';
      case MealSlot.afternoon:
        return 'afternoon';
      case MealSlot.iftar:
        return 'Iftar';
      case MealSlot.dinner:
        return 'dinner';
      case MealSlot.bedtime:
        return 'bedtime';
      case MealSlot.whenNeeded:
        return 'when needed';
    }
  }

  static String _slotUr(MealSlot slot) {
    switch (slot) {
      case MealSlot.wakeUp:
        return 'صبح اٹھتے ہی';
      case MealSlot.suhoor:
        return 'سحری';
      case MealSlot.breakfast:
        return 'ناشتے';
      case MealSlot.midMorning:
        return 'دوپہر سے پہلے';
      case MealSlot.lunch:
        return 'دوپہر کے کھانے';
      case MealSlot.afternoon:
        return 'سہ پہر';
      case MealSlot.iftar:
        return 'افطار';
      case MealSlot.dinner:
        return 'رات کے کھانے';
      case MealSlot.bedtime:
        return 'رات سونے کے وقت';
      case MealSlot.whenNeeded:
        return 'ضرورت کے وقت';
    }
  }

  static String _relationEn(MealRelation relation) {
    switch (relation) {
      case MealRelation.before:
        return 'before';
      case MealRelation.withMeal:
        return 'with';
      case MealRelation.after:
        return 'after';
      case MealRelation.emptyStomach:
        return 'on empty stomach before';
      case MealRelation.anytime:
        return 'at';
    }
  }

  static String _relationUr(MealRelation relation) {
    switch (relation) {
      case MealRelation.before:
        return 'کھانے سے پہلے';
      case MealRelation.withMeal:
        return 'کھانے کے ساتھ';
      case MealRelation.after:
        return 'کھانے کے بعد';
      case MealRelation.emptyStomach:
        return 'خالی پیٹ';
      case MealRelation.anytime:
        return 'مقررہ وقت پر';
    }
  }
}
