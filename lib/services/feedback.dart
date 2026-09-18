import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../data/store.dart';
import '../ui/theme.dart';

/// مفتاح عام عشان نقدر نطلع Toast من أي مكان من غير ما نمرر context
final GlobalKey<ScaffoldMessengerState> messengerKey =
    GlobalKey<ScaffoldMessengerState>();

class Fx {
  /// صوت قصير عند خلاص الراحة
  static void beep() {
    if (!store.db.settings.soundEnabled) return;
    SystemSound.play(SystemSoundType.alert);
  }

  static void tapVibe() {
    if (!store.db.settings.vibrationEnabled) return;
    HapticFeedback.selectionClick();
  }

  static void setDoneVibe() {
    if (!store.db.settings.vibrationEnabled) return;
    HapticFeedback.mediumImpact();
  }

  static void celebrateVibe() {
    if (!store.db.settings.vibrationEnabled) return;
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 140), HapticFeedback.heavyImpact);
    Future.delayed(const Duration(milliseconds: 300), HapticFeedback.heavyImpact);
  }

  static void restEndVibe() {
    if (!store.db.settings.vibrationEnabled) return;
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 180), HapticFeedback.heavyImpact);
  }

  /// نبضة خفيفة + تك صوتي قبل خلاص الراحة بـ 3 ثواني — استعد للمجموعة الجاية
  static void restWarnVibe() {
    if (store.db.settings.vibrationEnabled) HapticFeedback.lightImpact();
    if (store.db.settings.soundEnabled) SystemSound.play(SystemSoundType.click);
  }

  /// دفعة 7 — #6 Haptic Feedback متدرج: بدل ما كل حدث يهزّ بنفس القوة،
  /// شدة الاهتزاز بتتدرج مع حجم الإنجاز الفعلي — مجموعة عادية تحس مختلفة
  /// عن رقم قياسي، ورقم قياسي يحس مختلف عن Level Up. [tier] من 1 (أخف) لـ 4 (أقوى).
  static void graduatedVibe(int tier) {
    if (!store.db.settings.vibrationEnabled) return;
    switch (tier.clamp(1, 4)) {
      case 1:
        HapticFeedback.selectionClick();
        break;
      case 2:
        HapticFeedback.mediumImpact();
        break;
      case 3:
        HapticFeedback.heavyImpact();
        Future.delayed(const Duration(milliseconds: 120), HapticFeedback.mediumImpact);
        break;
      case 4:
        HapticFeedback.heavyImpact();
        Future.delayed(const Duration(milliseconds: 110), HapticFeedback.heavyImpact);
        Future.delayed(const Duration(milliseconds: 240), HapticFeedback.heavyImpact);
        Future.delayed(const Duration(milliseconds: 400), HapticFeedback.mediumImpact);
        break;
    }
  }

  /// تنبيه يظهر جوه التطبيق (زي toast في نسخة الويب)
  static void toast(String msg,
      {Duration duration = const Duration(milliseconds: 2400),
      Color? color}) {
    final m = messengerKey.currentState;
    if (m == null) return;
    m.clearSnackBars();
    m.showSnackBar(SnackBar(
      duration: duration,
      backgroundColor: color ?? C.panel2,
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: C.border),
      ),
      content: Text(msg,
          style: const TextStyle(color: C.text, fontSize: 13.5, height: 1.5)),
    ));
  }

  /// تنبيه مع زر "تراجع"
  static void toastUndo(String msg, VoidCallback onUndo) {
    final m = messengerKey.currentState;
    if (m == null) return;
    m.clearSnackBars();
    m.showSnackBar(SnackBar(
      duration: const Duration(seconds: 5),
      backgroundColor: C.panel2,
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: C.border),
      ),
      content: Text(msg, style: const TextStyle(color: C.text, fontSize: 13.5)),
      action: SnackBarAction(
        label: 'تراجع ↩',
        textColor: C.accent,
        onPressed: onUndo,
      ),
    ));
  }

  /// تنبيه مهم (إشعار داخلي) — زي notifyUser في نسخة الويب
  static void notify(String title, String body) {
    if (!store.db.settings.alertsEnabled) {
      toast(body);
      return;
    }
    toast('$title\n$body', duration: const Duration(milliseconds: 3400));
  }

  static Future<void> keepScreenOn(bool on) async {
    try {
      if (on && !store.db.settings.keepScreenOn) return;
      await WakelockPlus.toggle(enable: on);
    } catch (_) {
      // مش مدعوم على المنصة دي — مش مشكلة
    }
  }
}

String fmtTime(num totalSeconds) {
  final t = totalSeconds < 0 ? 0 : totalSeconds.round();
  final m = (t ~/ 60).toString().padLeft(2, '0');
  final s = (t % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

const _arMonths = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
];

String fmtDate(DateTime d) => '${d.day} ${_arMonths[d.month - 1]} ${d.year}';

String fmtDateShort(DateTime d) =>
    '${d.day}/${d.month}/${d.year}';

String fmtDateTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final ampm = d.hour < 12 ? 'ص' : 'م';
  return '${fmtDateShort(d)} · $h:${d.minute.toString().padLeft(2, '0')} $ampm';
}

String numStr(double v) =>
    v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
