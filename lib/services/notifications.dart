import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/analytics.dart';
import '../data/models.dart';
import '../data/session_controller.dart';
import '../data/store.dart';

const String quickLogSourceValue = 'quick_log';

const _kChannelId = 'saqr_reminder_channel';
const _kChannelName = 'تذكير التمرين';
const _kChannelDesc = 'تذكير يومي بميعاد التمرين + تسجيل سريع من الإشعار';
const _kQuickLogActionId = 'QUICK_LOG_ACTION';
const _kConfirmationId = 9999;

/// أقصى عدد أيام قدّام بنجدول لها تذكير مرة واحدة — بنعيد ملء الجدول ده
/// كل ما التطبيق يفتح أو أي إعداد يتغيّر، فمفيش داعي لعدد أكبر.
const _kReminderDaysAhead = 14;
const _kReminderIdBase = 5000;

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

int _reminderIdForDate(DateTime d) {
  final epoch = DateTime(2024, 1, 1);
  final days = _dateOnly(d).difference(epoch).inDays;
  return _kReminderIdBase + (days % 100000);
}

/// دفعة 9 — #18 Push Notifications: طبقة موحّدة لكل إشعارات النظام
/// الحقيقية (تظهر حتى لو التطبيق مقفول تمامًا)، مبنية فوق
/// flutter_local_notifications. باقي التطبيق مايعرفش تفاصيل المنصة —
/// بس بينادي `NotificationService.instance`.
const String quickLogSource = 'تسجيل سريع من إشعار التذكير 🔔';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await _ensureTimezone();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onForegroundResponse,
      onDidReceiveBackgroundNotificationResponse:
          notificationBackgroundEntryPoint,
    );

    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        _kChannelId,
        _kChannelName,
        description: _kChannelDesc,
        importance: Importance.high,
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    _initialized = true;
  }

  Future<void> _ensureTimezone() async {
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (e) {
      debugPrint('timezone detect error: $e');
      try {
        tz.setLocalLocation(tz.getLocation('Africa/Cairo'));
      } catch (_) {
        // لو حتى ده فشل، هيفضل UTC — التذكير هيتزحزح شوية بس هيفضل شغال
      }
    }
  }

  /// بيطلب صلاحية إظهار الإشعارات (لازمة من أندرويد 13 وما بعده). لازم
  /// يتنادى نتيجة إجراء واضح من المستخدم (تفعيل التذكير من الإعدادات)،
  /// مش تلقائي عند فتح التطبيق.
  Future<bool> requestPermission() async {
    await init();
    if (Platform.isAndroid) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }

  Future<void> cancelAllReminders() async {
    for (var i = 0; i < _kReminderDaysAhead; i++) {
      final date = _dateOnly(DateTime.now()).add(Duration(days: i));
      await _plugin.cancel(_reminderIdForDate(date));
    }
  }

  /// بيعيد بناء جدول التذكير لأقرب 14 يوم حسب إعدادات المستخدم الحالية.
  /// بيتنادى: عند فتح التطبيق، لما المستخدم يغيّر وقت/تفعيل التذكير،
  /// وبعد كل ما جلسة تتسجل أو تتمسح (عشان يلغي تذكير النهارده لو خلص
  /// تمرينه بالفعل، أو يرجّعه لو مسح الجلسة بالغلط).
  Future<void> rescheduleReminders() async {
    await init();
    final settings = store.db.settings;
    for (var i = 0; i < _kReminderDaysAhead; i++) {
      final date = _dateOnly(DateTime.now()).add(Duration(days: i));
      final id = _reminderIdForDate(date);
      await _plugin.cancel(id);
      if (!settings.reminderEnabled) continue;
      if (Analytics.hasSessionOnDate(date)) {
        continue; // اتعمل تمرين اليوم ده أصلًا
      }

      final scheduled = tz.TZDateTime(tz.local, date.year, date.month,
          date.day, settings.reminderHour, settings.reminderMinute);
      if (i == 0 && scheduled.isBefore(tz.TZDateTime.now(tz.local))) {
        continue; // ميعاد النهارده فات أصلًا
      }

      final nextDay = Analytics.suggestedNextDay();
      final body = nextDay == null
          ? 'ميعاد تمرينك النهارده — يلا يا صقر 🔥'
          : 'ميعاد "${nextDay.name}" النهارده — يلا يا صقر 🔥';

      await _plugin.zonedSchedule(
        id,
        'وقت التمرين ⏰',
        body,
        scheduled,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _kChannelId,
            _kChannelName,
            channelDescription: _kChannelDesc,
            importance: Importance.high,
            priority: Priority.high,
            actions: settings.reminderQuickLogEnabled
                ? const [
                    AndroidNotificationAction(
                      _kQuickLogActionId,
                      '✅ سجّلت النهارده',
                      showsUserInterface: false,
                      cancelNotification: true,
                    ),
                  ]
                : null,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'reminder:${date.toIso8601String()}',
      );
    }
  }

  Future<void> _showQuickLogConfirmation(String dayName) async {
    await _plugin.show(
      _kConfirmationId,
      'تم تسجيل التمرين ✅',
      '"$dayName" اتسجل تلقائي بأوزان آخر مرة — افتح التطبيق لو حابب تعدّل حاجة.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _kChannelId,
          _kChannelName,
          channelDescription: _kChannelDesc,
          importance: Importance.defaultImportance,
        ),
      ),
    );
  }

  /// الإشعار اتلمس والتطبيق شغال في الميموري (Foreground) — نستخدم نفس
  /// الـ store الحي بدل ما نفتح اتصال جديد بقاعدة البيانات.
  void _onForegroundResponse(NotificationResponse response) {
    if (response.actionId == _kQuickLogActionId) {
      unawaited(_quickLogUsingLiveStore());
    }
  }

  Future<void> _quickLogUsingLiveStore() async {
    if (!store.ready) await store.init();
    if (sessionCtrl.isActive) return; // فيه تمرين شغال فعلًا، منسجلش فوقه
    if (Analytics.hasSessionOnDate(DateTime.now())) return;
    final day = Analytics.suggestedNextDay();
    if (day == null) return;
    await _quickLogSession(day);
    await _showQuickLogConfirmation(day.name);
    await rescheduleReminders();
  }

  /// #42 Quick-log: بيبني جلسة "سريعة" كاملة بنفس منطق بدء الجلسة العادي
  /// (`SessionController.buildPrefilledExercises` — أوزان آخر مرة +
  /// الزيادة/التخفيف التلقائي)، بس بيعلّم كل المجموعات "تمّت" فورًا
  /// ويقفلها على طول، من غير ما يفتح شاشة التمرين خالص.
  static Future<void> _quickLogSession(WorkoutDay day) async {
    final exercises = SessionController.buildPrefilledExercises(day);
    for (final ex in exercises) {
      for (final set in ex.loggedSets) {
        set.done = true;
        if (!set.hasWeight) set.weight = '0';
        if (set.reps.trim().isEmpty) set.reps = ex.targetReps;
      }
      ex.unlockedSetCount = ex.loggedSets.length;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final session = WorkoutSession(
      id: uid('s'),
      dayId: day.id,
      dayName: day.name,
      date: DateTime.now(),
      startedAt: now - 1000,
      endedAt: now,
      unlockedExerciseCount: exercises.length,
      exercises: exercises,
      notes: quickLogSource,
    );
    // Quick-log is an unverified check-in, not a performed workout.
    // Do not mark PRs from an automatically fabricated session.
    await store.addSession(session);
  }
}

/// دفعة 9 — الـ Quick-log لازم يشتغل حتى لو التطبيق مقفول تمامًا (مش
/// بس في الخلفية)، فبيتنفّذ جوه isolate منفصلة بيفتحها أندرويد بنفسه.
/// لازم يفضل top-level function (مش method جوه كلاس) ومعلّم بـ
/// @pragma('vm:entry-point') عشان أندرويد يقدر يوصله من غير ما يشغّل
/// التطبيق بواجهته كاملة.
@pragma('vm:entry-point')
void notificationBackgroundEntryPoint(NotificationResponse response) {
  if (response.actionId != _kQuickLogActionId) return;
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(() async {
    try {
      // الـ isolate دي جديدة تمامًا؛ لازم نهيّئ plugin قبل أي show/schedule.
      await NotificationService.instance.init();

      // نسخة مستقلة كاملة من التخزين (SharedPreferences + SQLite) — نفس
      // اللي بيحصل عادي أول ما التطبيق يفتح، بس من غير أي واجهة.
      await store.init();
      if (Analytics.hasSessionOnDate(DateTime.now())) return;
      final day = Analytics.suggestedNextDay();
      if (day == null) return;
      await NotificationService._quickLogSession(day);
      await NotificationService.instance._showQuickLogConfirmation(day.name);
      await NotificationService.instance.rescheduleReminders();
    } catch (e) {
      debugPrint('background quick-log error: $e');
    }
  }());
}
