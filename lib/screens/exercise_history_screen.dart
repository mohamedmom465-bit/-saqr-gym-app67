import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/analytics.dart';
import '../data/providers.dart';
import '../data/store.dart';
import '../services/feedback.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class ExerciseHistoryScreen extends ConsumerWidget {
  final String exerciseId;
  final String exerciseName;
  const ExerciseHistoryScreen({
    super.key,
    required this.exerciseId,
    required this.exerciseName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(gymStoreProvider);
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final hist = Analytics.exerciseHistory(exerciseId, exerciseName);

        if (hist.isEmpty) {
          return Scaffold(
            appBar: saqrAppBar(eyebrow: 'PROGRESS', title: exerciseName),
            body: const Padding(
              padding: EdgeInsets.all(16),
              child: EmptyBox(
                  'لسه معملتش التمرين ده وسجلت وزن.\nسجّله في أول جلسة عشان يبدأ يظهر هنا.'),
            ),
          );
        }

        final lastEntry = hist.last;
        final oneRM = Analytics.estimate1RM(lastEntry.value, lastEntry.reps);
        final best = hist.map((h) => h.value).reduce((a, b) => a > b ? a : b);
        final first = hist.first.value;
        final gain = lastEntry.value - first;
        // #33 Volume Tracker: حجم (وزن × عدات) التمرين ده بالذات عبر
        // كل الجلسات، منفصل عن حجم التمرين اليومي الكلي في التقارير.
        final volHist =
            Analytics.exerciseVolumeHistory(exerciseId, exerciseName);

        return Scaffold(
          appBar: saqrAppBar(eyebrow: 'PROGRESS', title: exerciseName),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              StatGrid([
                StatBox(numStr(lastEntry.value), 'آخر وزن', unit: 'كجم'),
                StatBox(numStr(best), 'أعلى وزن اتسجل', unit: 'كجم'),
                StatBox('$oneRM', 'تقدير 1RM (Epley)', unit: 'كجم'),
                StatBox('${hist.length}', 'مرات اتسجلت'),
              ]),
              if (hist.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    gain >= 0
                        ? '▲ زودت ${numStr(gain)}كجم من أول مرة سجلت فيها التمرين ده'
                        : '▼ نزلت ${numStr(gain.abs())}كجم عن أول مرة سجلت فيها التمرين ده',
                    style: TextStyle(
                        fontSize: 12.5,
                        color: gain >= 0 ? C.good : C.danger),
                  ),
                ),
              const SectionTitle('تطور الوزن عبر الوقت'),
              SCard(child: LineChartView(hist, suffix: 'كجم')),
              if (volHist.length > 1) ...[
                const SectionTitle('📊 حجم التمرين ده عبر الوقت (وزن × عدات)'),
                SCard(child: LineChartView(volHist, suffix: 'كجم')),
              ],
              const SectionTitle('السجل بالتفصيل'),
              SCard(
                child: Column(
                  children: [
                    for (var i = hist.length - 1; i >= 0; i--)
                      ListRow(
                        divider: i != 0,
                        start: Text(fmtDateShort(hist[i].date),
                            style: const TextStyle(
                                fontSize: 13, color: C.muted)),
                        end: Row(
                          children: [
                            Text(
                              '${numStr(hist[i].value)}كجم × ${hist[i].reps}',
                              style: const TextStyle(
                                  fontSize: 13.5, fontWeight: FontWeight.w600),
                            ),
                            if (hist[i].isPR) ...[
                              const SizedBox(width: 6),
                              const Pill('🏆 PR', color: C.good),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
