import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/analytics.dart';
import '../data/gamification.dart';
import '../data/models.dart';
import '../data/providers.dart';
import '../data/session_controller.dart';
import '../data/store.dart';
import '../services/backup.dart';
import '../services/feedback.dart';
import '../ui/theme.dart';
import '../ui/transitions.dart';
import '../ui/widgets.dart';
import 'achievements_screen.dart';
import 'day_detail_screen.dart';
import 'session_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final streak = Analytics.computeStreak();
    if (streak >= 3) return '🔥 $streak أيام على التوالي، ماشي زي الوحش يا صقر';
    if (Analytics.realSessions.isEmpty) return 'يلا نبدأ أول تمرين — النظام جاهز';
    final h = DateTime.now().hour;
    if (h < 12) return 'صباح الجد، اختار يومك وابدأ';
    if (h < 18) return 'وقت التمرين — اختار يومك';
    return 'مسا الجد، جهز نفسك وابدأ';
  }

  IconData _dayIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('push')) return Icons.local_fire_department_rounded;
    if (n.contains('pull')) return Icons.radio_button_checked;
    if (n.contains('leg')) return Icons.bolt_rounded;
    return Icons.fitness_center_rounded;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(gymStoreProvider);
    return AnimatedBuilder(
      animation: sessionCtrl,
      builder: (context, _) {
        final streak = Analytics.computeStreak();
        final int? daysSinceLast = Analytics.realSessions.isEmpty
            ? null
            : DateTime.now()
                .difference(Analytics.realSessions
                    .map((s) => s.date)
                    .reduce((a, b) => b.isAfter(a) ? b : a))
                .inDays;
        return Scaffold(
          appBar: saqrAppBar(
            eyebrow: '',
            title: 'SAQR TRAINING SYSTEM',
            showBack: false,
            leading: Padding(
              padding: const EdgeInsets.all(10),
              child: ClipOval(
                child: Image.asset('assets/brand/profile.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                          color: C.accent,
                          alignment: Alignment.center,
                          child: const Text('ص',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        )),
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
            children: [
              Text(_greeting(),
                  style: const TextStyle(fontSize: 13, color: C.muted)),
              const SizedBox(height: 14),
              _levelBadge(context),
              const SizedBox(height: 12),
              if (streak > 0)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      C.accent.withOpacity(0.18),
                      C.panel,
                    ]),
                    borderRadius: BorderRadius.circular(kRadius),
                    border: Border.all(color: C.accentDim),
                  ),
                  child: Column(
                    children: [
                      Text('🔥 $streak',
                          style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: C.accent)),
                      const SizedBox(height: 4),
                      const Text('يوم متتالي — كمل كده!',
                          style: TextStyle(fontSize: 12, color: C.muted)),
                    ],
                  ),
                ),
              if (sessionCtrl.isActive)
                SCard(
                  borderColor: C.accent,
                  onTap: () => pushFade(
                    context,
                    SessionScreen(dayId: sessionCtrl.session!.dayId),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('▶ تمرين "${sessionCtrl.session!.dayName}" لسه شغال',
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            const Text('دوس هنا عشان تكمل من حيث ما وقفت',
                                style: TextStyle(fontSize: 12, color: C.muted)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_left_rounded,
                          color: C.accent, size: 26),
                    ],
                  ),
                ),
              if (store.needsBackupReminder)
                SCard(
                  borderColor: C.accentDim,
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                            '🛟 من زمان ما خدتش نسخة احتياطية من بياناتك',
                            style: TextStyle(fontSize: 13, height: 1.6)),
                      ),
                      const SizedBox(width: 10),
                      SButton('مشاركة الآن',
                          small: true,
                          expand: false,
                          onPressed: () => BackupService.share(context)),
                    ],
                  ),
                ),
              if (daysSinceLast != null && daysSinceLast! >= 2 && !sessionCtrl.isActive)
                SCard(
                  borderColor: C.accentDim,
                  child: Text(
                    '⏰ من $daysSinceLast أيام ما سجلتش تمرين — نسيت تسجل ولا لسه مبدأتش؟',
                    style: const TextStyle(fontSize: 13, height: 1.6),
                  ),
                ),
              ...store.db.days.map((day) => _dayCard(context, day)),
              const SizedBox(height: 10),
              if (Analytics.realSessions.isNotEmpty)
                Text(
                  'إجمالي الجلسات المسجلة: ${Analytics.realSessions.length}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11.5, color: C.muted),
                ),
            ],
          ),
        );
      },
    );
  }

  /// دفعة 7 — #19 Levels/Badges: كارت صغير في الرئيسية بيوري المستوى
  /// الحالي وتقدّمه، ودوس عليه يودّيك لشاشة الإنجازات كاملة.
  Widget _levelBadge(BuildContext context) {
    final level = Gamification.currentLevel();
    return SCard(
      onTap: () => pushFade(context, const AchievementsScreen()),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: C.accent.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Text('⭐${level.level}',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800, color: C.accent)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('مستوى ${level.level} — ${level.title}',
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: level.progress,
                    minHeight: 6,
                    backgroundColor: C.panel2,
                    valueColor: const AlwaysStoppedAnimation(C.accent),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_left_rounded, color: C.muted, size: 22),
        ],
      ),
    );
  }

  Widget _dayCard(BuildContext context, WorkoutDay day) {
    WorkoutSession? last;
    for (final s in Analytics.realSessions.reversed) {
      if (s.dayId == day.id) {
        last = s;
        break;
      }
    }
    final lastStr = last == null ? 'لسه ما اتعملش' : fmtDateShort(last.date);
    return SCard(
      onTap: () => pushFade(context, DayDetailScreen(dayId: day.id)),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [C.accent, Color(0xFFB5330F)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_dayIcon(day.name), color: Colors.white, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(day.name.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 17.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8)),
                const SizedBox(height: 4),
                Text('${day.exercises.length} تمارين · آخر مرة: $lastStr',
                    style: const TextStyle(fontSize: 12, color: C.muted)),
              ],
            ),
          ),
          const Icon(Icons.chevron_left_rounded, color: C.accent, size: 26),
        ],
      ),
    );
  }
}
