import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/analytics.dart';
import '../data/models.dart';
import '../data/providers.dart';
import '../data/session_controller.dart';
import '../data/store.dart';
import '../services/feedback.dart';
import '../ui/theme.dart';
import '../ui/transitions.dart';
import '../ui/widgets.dart';
import 'exercise_history_screen.dart';
import 'session_screen.dart';

class DayDetailScreen extends ConsumerWidget {
  final String dayId;
  const DayDetailScreen({super.key, required this.dayId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(gymStoreProvider);
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final dayIdx = store.db.days.indexWhere((d) => d.id == dayId);
        if (dayIdx == -1) return const Scaffold(body: SizedBox.shrink());
        final day = store.db.days[dayIdx];
        final est = Analytics.estimateDuration(day);

        var inCore = false, inCardio = false;
        final items = <Widget>[];
        for (final ex in day.exercises) {
          if (ex.core && !inCore) {
            items.add(const SectionTitle('🔥 سيشن البطن (Core)'));
            inCore = true;
          }
          if (ex.cardio && !inCardio) {
            items.add(const SectionTitle('🚴 سيشن الكارديو (Cardio)'));
            inCardio = true;
          }
          items.add(_exerciseCard(context, ex));
        }

        return Scaffold(
          appBar: saqrAppBar(
            eyebrow: day.name.toUpperCase(),
            title: 'تفاصيل اليوم',
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              SCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Pill('⏱ الوقت المتوقع: ${fmtTime(est)}', accent: true),
                    Pill('${day.exercises.length} تمارين'),
                  ],
                ),
              ),
              ...items,
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: SButton(
                '▶  بدء التمرين',
                onPressed: () async {
                  // لو فيه تمرين تاني لسه شغال، نسأل الأول قبل ما نلغيه
                  if (sessionCtrl.isActive &&
                      sessionCtrl.session!.dayId != day.id) {
                    final ok = await confirmDialog(
                      context,
                      'عندك تمرين "${sessionCtrl.session!.dayName}" لسه شغال. تبدأ تمرين جديد وتلغي اللي شغال؟',
                      danger: true,
                    );
                    if (!ok) return;
                    sessionCtrl.abandon();
                  }
                  if (!context.mounted) return;
                  pushReplaceFade(context, SessionScreen(dayId: day.id));
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _exerciseCard(BuildContext context, ExerciseDef ex) {
    final last = Analytics.lastPerformance(ex.id, ex.name);
    final hist = Analytics.exerciseHistory(ex.id, ex.name);
    final isPR = hist.isNotEmpty && hist.last.isPR;

    return SCard(
      onTap: () => pushFade(
        context,
        ExerciseHistoryScreen(exerciseId: ex.id, exerciseName: ex.name),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(ex.name,
                    style: const TextStyle(
                        fontSize: 15.5, fontWeight: FontWeight.w700)),
              ),
              if (ex.isMain) const Pill('أساسي', accent: true),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${ex.sets} مجموعات × ${ex.reps} عدة  ·  راحة ${ex.rest} ثانية'
            '${ex.plates ? ' · 🏋️ محتاج تركيب أوزان' : ''}'
            '${ex.noRestAfter ? ' · ⚡ سوبرست' : ''}',
            style: const TextStyle(fontSize: 12, color: C.muted, height: 1.6),
          ),
          ExerciseShapeToggle(image: ex.image),
          if (last != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Flexible(
                  child: Pill(
                      '📈 آخر مرة: ${last.weight}كجم × ${last.reps} (${fmtDateShort(last.date)})'),
                ),
                if (isPR) ...[
                  const SizedBox(width: 6),
                  const Pill('🏆 PR', color: C.good),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
