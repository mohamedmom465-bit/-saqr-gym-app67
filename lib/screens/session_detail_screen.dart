import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/analytics.dart';
import '../data/providers.dart';
import '../data/store.dart';
import '../services/feedback.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// تفاصيل جلسة متحفوظة — تقدر تراجع كل مجموعة سجلتها، والملاحظات، والتقييمات
class SessionDetailScreen extends ConsumerWidget {
  final String sessionId;
  const SessionDetailScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(gymStoreProvider);
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final idx = store.db.sessions.indexWhere((s) => s.id == sessionId);
        if (idx == -1) return const Scaffold(body: SizedBox.shrink());
        final s = store.db.sessions[idx];

        return Scaffold(
          appBar: saqrAppBar(
            eyebrow: s.dayName.toUpperCase(),
            title: fmtDate(s.date),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: C.danger),
                onPressed: () async {
                  final ok = await confirmDialog(
                      context, 'تأكيد حذف الجلسة دي من السجل؟',
                      danger: true);
                  if (!ok) return;
                  final removed = await store.deleteSession(s.id);
                  if (context.mounted) Navigator.pop(context);
                  if (removed != null) {
                    Fx.toastUndo('🗑 اتحذفت جلسة "${removed.dayName}"',
                        () => store.restoreSession(idx, removed));
                  }
                },
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              StatGrid([
                StatBox('${s.durationMinutes}', 'دقيقة'),
                StatBox('${Analytics.sessionVolume(s)}', 'حجم التمرين',
                    unit: 'كجم'),
                StatBox(s.rating != null ? '${s.rating}/10' : '-', 'التقييم'),
                StatBox(
                    '${s.exercises.expand((e) => e.loggedSets).where((x) => x.done).length}',
                    'مجموعة اتكملت'),
                StatBox('${Analytics.estimateCalories(s)}', 'سعرة تقريبًا 🔥',
                    unit: 'kcal'),
              ]),
              if (s.notes.trim().isNotEmpty) ...[
                const SectionTitle('ملاحظات'),
                SCard(
                  child: Text(s.notes,
                      style: const TextStyle(fontSize: 13.5, height: 1.8)),
                ),
              ],
              const SectionTitle('التمارين'),
              ...s.exercises.map((ex) {
                final done = ex.loggedSets.where((x) => x.done).toList();
                return SCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(ex.name,
                                style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700)),
                          ),
                          if (ex.isPR) const Pill('🏆 PR', color: C.good),
                          if (s.exerciseRatings[ex.exerciseId] != null) ...[
                            const SizedBox(width: 6),
                            Pill('${s.exerciseRatings[ex.exerciseId]}/10'),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (done.isEmpty)
                        const Text('ما اتسجلش أي مجموعة في التمرين ده',
                            style: TextStyle(fontSize: 12, color: C.muted))
                      else
                        for (var i = 0; i < ex.loggedSets.length; i++)
                          if (ex.loggedSets[i].done)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Text(
                                      ex.loggedSets[i].isDrop
                                          ? '🔽'
                                          : '${i + 1}.',
                                      style: const TextStyle(
                                          fontSize: 12, color: C.muted)),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${ex.loggedSets[i].weight.isEmpty ? '-' : ex.loggedSets[i].weight}كجم × ${ex.loggedSets[i].reps.isEmpty ? '-' : ex.loggedSets[i].reps}',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  if (ex.loggedSets[i].note.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '📝 ${ex.loggedSets[i].note}',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 11.5, color: C.muted),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
