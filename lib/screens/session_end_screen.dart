import 'dart:async';

import 'package:flutter/material.dart';

import '../data/analytics.dart';
import '../data/session_controller.dart';
import '../services/feedback.dart';
import '../services/notifications.dart';
import '../ui/confetti.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class SessionEndScreen extends StatefulWidget {
  const SessionEndScreen({super.key});

  @override
  State<SessionEndScreen> createState() => _SessionEndScreenState();
}

class _SessionEndScreenState extends State<SessionEndScreen> {
  final notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    notesCtrl.text = sessionCtrl.session?.notes ?? '';
  }

  @override
  void dispose() {
    notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = sessionCtrl.session;
    if (s == null) return;
    if (s.rating == null) {
      final ok = await confirmDialog(
          context, 'ما اخترتش تقييم، تحفظ من غير تقييم؟');
      if (!ok) return;
    }
    s.notes = notesCtrl.text;
    final result = await sessionCtrl.save();
    // دفعة 9 — #40: خلّصت تمرين النهارده يدوي، فألغي تذكير النهارده من
    // غير ما يستنى للـ Quick-log. تايه في الخلفية، مش محتاج ننتظره.
    unawaited(NotificationService.instance.rescheduleReminders());
    if (!mounted) return;

    // دفعة 7 — #3 Confetti + #6 هابتك متدرج: كل ما الإنجاز أكبر، الاحتفال أقوى
    final bigWin = result.prs.isNotEmpty ||
        result.newAchievements.isNotEmpty ||
        result.leveledUp;
    if (bigWin) {
      ConfettiOverlay.celebrate(context);
      Fx.graduatedVibe(result.leveledUp ? 4 : (result.prs.isNotEmpty ? 3 : 2));
    } else {
      Fx.graduatedVibe(1);
    }

    // نلمّ كل رسايل الاحتفال في توست واحد (بدل ما كل واحدة تمسح اللي قبلها)
    final lines = <String>[];
    if (result.prs.isNotEmpty) {
      lines.add('🏆 رقم قياسي جديد في: ${result.prs.join('، ')}!');
    }
    for (final a in result.newAchievements) {
      lines.add('${a.emoji} إنجاز جديد: ${a.title}');
    }
    if (result.leveledUp) {
      lines.add('⭐ ترقّيت لمستوى ${result.level.level} — ${result.level.title}!');
    }
    if (lines.isEmpty) {
      Fx.toast('✅ اتحفظ التمرين');
    } else {
      Fx.toast(lines.join('\n'), duration: const Duration(milliseconds: 4600));
    }

    // نستنى شوية عشان الكونفيتي والتوستات تبان قبل ما نرجع للرئيسية
    await Future.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    Navigator.popUntil(context, (r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: sessionCtrl,
      builder: (context, _) {
        final s = sessionCtrl.session;
        if (s == null) {
          return const Scaffold(body: SizedBox.shrink());
        }
        final volume = Analytics.sessionVolume(s);
        final doneSets = s.exercises
            .expand((e) => e.loggedSets)
            .where((x) => x.done)
            .length;
        final calories = Analytics.estimateCalories(s);

        return Scaffold(
          appBar: saqrAppBar(
            eyebrow: s.dayName.toUpperCase(),
            title: 'تقييم التمرين',
            showBack: false,
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              StatGrid([
                StatBox('${s.durationMinutes}', 'دقيقة مدة التمرين'),
                StatBox('$doneSets', 'مجموعة اتكملت'),
                StatBox('$volume', 'حجم التمرين', unit: 'كجم'),
                StatBox('${s.exercises.length}', 'تمارين اليوم'),
                StatBox('$calories', 'سعرة حرارية تقريبًا 🔥', unit: 'kcal'),
              ]),
              const SectionTitle('تقييمك العام للتمرين ده (من 1 لـ 10)'),
              SCard(
                child: RatingScale(
                  value: s.rating,
                  onChanged: (n) {
                    s.rating = n;
                    setState(() {});
                  },
                ),
              ),
              const SectionTitle('تقييم كل تمرين لوحده (اختياري)'),
              ...s.exercises.map((ex) => SCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ex.name,
                            style: const TextStyle(
                                fontSize: 13.5, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 10),
                        RatingScale(
                          value: s.exerciseRatings[ex.exerciseId],
                          onChanged: (n) {
                            s.exerciseRatings[ex.exerciseId] = n;
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  )),
              const SectionTitle('ملاحظات (اختياري)'),
              SCard(
                child: TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 14, color: C.text),
                  decoration: const InputDecoration(
                      hintText: 'أي حاجة حصلت النهاردة تحب تفتكرها...'),
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: SButton('💾  حفظ التمرين',
                  kind: BtnKind.good, onPressed: _save),
            ),
          ),
        );
      },
    );
  }
}
