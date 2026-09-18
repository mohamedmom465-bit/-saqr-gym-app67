import 'package:flutter/material.dart';

import '../data/gamification.dart';
import '../data/store.dart';
import '../ui/bouncy.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// دفعة 7 — #19 Levels/Badges + #20 Achievements
class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final level = Gamification.currentLevel();
    final unlocked = Gamification.unlocked();
    final locked = Gamification.locked();

    return Scaffold(
      appBar: saqrAppBar(eyebrow: 'التقدّم', title: 'المستوى والإنجازات'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
        children: [
          _levelCard(level),
          SectionTitle('الإنجازات المفتوحة (${unlocked.length}/${Gamification.all.length})'),
          if (unlocked.isEmpty)
            const SCard(
              child: Text('لسه مفيش إنجازات — كمل تمرن وهتفتح واحد قريب 💪',
                  style: TextStyle(fontSize: 13, color: C.muted)),
            )
          else
            ...unlocked.map((a) => _badgeCard(a, true)),
          const SectionTitle('لسه مقفولة'),
          ...locked.map((a) => _badgeCard(a, false)),
        ],
      ),
    );
  }

  Widget _levelCard(LevelInfo level) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [C.accent.withOpacity(0.20), C.panel],
        ),
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: C.accentDim),
      ),
      child: Column(
        children: [
          Text('⭐ مستوى ${level.level}',
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w800, color: C.accent)),
          const SizedBox(height: 4),
          Text(level.title,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: C.text)),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: level.progress,
              minHeight: 10,
              backgroundColor: C.panel2,
              valueColor: const AlwaysStoppedAnimation(C.accent),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${level.xpIntoLevel} / ${level.xpForNextLevel} XP للمستوى الجاي',
            style: const TextStyle(fontSize: 11.5, color: C.muted),
          ),
        ],
      ),
    );
  }

  Widget _badgeCard(Achievement a, bool isUnlocked) {
    final progress = !isUnlocked ? a.progressText?.call(store.db) : null;
    return BouncyTap(
      intensity: 0.3,
      onTap: () {},
      child: SCard(
        borderColor: isUnlocked ? C.accentDim : C.border,
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isUnlocked ? C.accent.withOpacity(0.15) : C.panel2,
                shape: BoxShape.circle,
              ),
              child: Opacity(
                opacity: isUnlocked ? 1 : 0.35,
                child: Text(a.emoji, style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isUnlocked ? C.text : C.muted,
                      )),
                  const SizedBox(height: 3),
                  Text(a.description,
                      style: const TextStyle(fontSize: 12, color: C.muted)),
                  if (progress != null) ...[
                    const SizedBox(height: 3),
                    Text(progress,
                        style: const TextStyle(
                            fontSize: 11.5,
                            color: C.accent,
                            fontWeight: FontWeight.w600)),
                  ],
                ],
              ),
            ),
            if (isUnlocked)
              const Icon(Icons.check_circle_rounded, color: C.good, size: 22)
            else
              const Icon(Icons.lock_outline_rounded, color: C.muted, size: 20),
          ],
        ),
      ),
    );
  }
}
