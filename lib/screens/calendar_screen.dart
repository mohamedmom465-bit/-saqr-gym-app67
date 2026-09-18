import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/analytics.dart';
import '../data/models.dart';
import '../data/providers.dart';
import '../data/store.dart';
import '../services/feedback.dart';
import '../ui/theme.dart';
import '../ui/transitions.dart';
import '../ui/widgets.dart';
import 'session_detail_screen.dart';

const _arMonthsFull = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
];
const _arWeekdays = ['أحد', 'اتنين', 'تلات', 'أربع', 'خميس', 'جمعة', 'سبت'];

/// #16 Monthly Workout Calendar — شهر كامل، كل يوم فيه تمرين متعلّم
/// بنقطة، وضغطة على اليوم تفتح الجلسة (أو تختار واحدة لو فيه أكتر من
/// جلسة في نفس اليوم).
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  void _shift(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(gymStoreProvider);
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final sessions = store.db.sessions;
        final byDay = <DateTime, List<WorkoutSession>>{};
        for (final s in sessions) {
          final key = DateTime(s.date.year, s.date.month, s.date.day);
          byDay.putIfAbsent(key, () => []).add(s);
        }

        final firstOfMonth = DateTime(_month.year, _month.month, 1);
        final daysInMonth =
            DateTime(_month.year, _month.month + 1, 0).day;
        final leading = firstOfMonth.weekday % 7; // الأحد = أول عمود
        final today = DateTime.now();
        final isThisMonth =
            _month.year == today.year && _month.month == today.month;

        final monthSessions = sessions
            .where((s) =>
                s.date.year == _month.year && s.date.month == _month.month)
            .toList();
        final monthVolume =
            monthSessions.fold<int>(0, (a, s) => a + Analytics.sessionVolume(s));

        return Scaffold(
          appBar: saqrAppBar(eyebrow: 'CALENDAR', title: 'التقويم الشهري'),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
            children: [
              SCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded,
                          color: C.text),
                      onPressed: () => _shift(1),
                    ),
                    Text(
                      '${_arMonthsFull[_month.month - 1]} ${_month.year}',
                      style: const TextStyle(
                          fontSize: 15.5, fontWeight: FontWeight.w700),
                    ),
                    IconButton(
                      icon:
                          const Icon(Icons.chevron_left_rounded, color: C.text),
                      onPressed: () => _shift(-1),
                    ),
                  ],
                ),
              ),
              StatGrid([
                StatBox('${monthSessions.length}', 'أيام تمرين الشهر ده'),
                StatBox(numStr(monthVolume.toDouble()), 'حجم الشهر (كجم)',
                    unit: ''),
              ]),
              SCard(
                child: Column(
                  children: [
                    GridView.count(
                      crossAxisCount: 7,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                      children: [
                        for (final w in _arWeekdays)
                          Center(
                            child: Text(w,
                                style: const TextStyle(
                                    fontSize: 10.5,
                                    color: C.muted,
                                    fontWeight: FontWeight.w600)),
                          ),
                        for (var i = 0; i < leading; i++) const SizedBox.shrink(),
                        for (var d = 1; d <= daysInMonth; d++)
                          _dayCell(
                            context,
                            date: DateTime(_month.year, _month.month, d),
                            sessionsToday:
                                byDay[DateTime(_month.year, _month.month, d)],
                            isToday: isThisMonth && d == today.day,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _legendDot(C.good),
                        const SizedBox(width: 6),
                        const Text('فيه تمرين',
                            style: TextStyle(fontSize: 11, color: C.muted)),
                        const SizedBox(width: 14),
                        _legendDot(C.accent),
                        const SizedBox(width: 6),
                        const Text('فيه رقم قياسي 🏆',
                            style: TextStyle(fontSize: 11, color: C.muted)),
                      ],
                    ),
                  ],
                ),
              ),
              if (monthSessions.isEmpty)
                const EmptyBox('مفيش أي تمرين متسجل في الشهر ده.'),
            ],
          ),
        );
      },
    );
  }

  Widget _legendDot(Color c) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      );

  Widget _dayCell(
    BuildContext context, {
    required DateTime date,
    List<WorkoutSession>? sessionsToday,
    required bool isToday,
  }) {
    final has = sessionsToday != null && sessionsToday.isNotEmpty;
    final hasPR =
        has && sessionsToday.any((s) => s.exercises.any((e) => e.isPR));
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: has ? () => _openDay(context, sessionsToday) : null,
      child: Container(
        decoration: BoxDecoration(
          color: has ? (hasPR ? C.accent.withOpacity(0.14) : C.panel2) : null,
          borderRadius: BorderRadius.circular(8),
          border: isToday ? Border.all(color: C.accent, width: 1.4) : null,
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${date.day}',
                style: TextStyle(
                    fontSize: 12.5,
                    color: has ? C.text : C.muted,
                    fontWeight: isToday ? FontWeight.w800 : FontWeight.w500)),
            const SizedBox(height: 2),
            if (has)
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: hasPR ? C.accent : C.good,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openDay(BuildContext context, List<WorkoutSession> daySessions) {
    if (daySessions.length == 1) {
      pushFade(context, SessionDetailScreen(sessionId: daySessions.first.id));
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: C.panel,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text('جلسات اليوم ده',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ),
            for (final s in daySessions)
              ListTile(
                title: Text(s.dayName,
                    style: const TextStyle(fontSize: 13.5, color: C.text)),
                subtitle: Text(
                    '${s.durationMinutes} دقيقة · ${Analytics.sessionVolume(s)}كجم حجم',
                    style: const TextStyle(fontSize: 11.5, color: C.muted)),
                trailing: const Icon(Icons.chevron_left_rounded, color: C.muted),
                onTap: () {
                  Navigator.pop(ctx);
                  pushFade(context, SessionDetailScreen(sessionId: s.id));
                },
              ),
          ],
        ),
      ),
    );
  }
}
