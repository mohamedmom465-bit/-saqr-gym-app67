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
import 'calendar_screen.dart';
import 'session_detail_screen.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(gymStoreProvider);
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final sessions = Analytics.realSessions;
        if (sessions.isEmpty) {
          return Scaffold(
            appBar: saqrAppBar(
                eyebrow: 'PROGRESS', title: 'التقارير', showBack: false),
            body: const Padding(
              padding: EdgeInsets.all(16),
              child: EmptyBox(
                  'لسه معملتش أي تمرين مسجل.\nابدأ تمرين من الرئيسية وهيبدأ التقرير يظهر هنا.'),
            ),
          );
        }

        final now = DateTime.now();
        final last7 = sessions
            .where((s) => now.difference(s.date).inDays <= 7)
            .toList();
        final last30 = sessions
            .where((s) => now.difference(s.date).inDays <= 30)
            .toList();

        final weeklyVol = Analytics.weeklyVolume(weeksBack: 8);
        final thisWeek = weeklyVol.last.value;
        final lastWeek = weeklyVol[weeklyVol.length - 2].value;
        String trendText = '';
        Color trendColor = C.muted;
        if (lastWeek > 0) {
          final pct = (((thisWeek - lastWeek) / lastWeek) * 100).round();
          trendText = pct >= 0
              ? '▲ $pct% عن الأسبوع اللي فات'
              : '▼ ${pct.abs()}% عن الأسبوع اللي فات';
          trendColor = pct >= 0 ? C.good : C.danger;
        }

        final durations = Analytics.sessionDurations(limit: 10);
        final avgDuration = durations.isEmpty
            ? 0
            : (durations.fold<double>(0, (a, d) => a + d.value) /
                    durations.length)
                .round();

        final weightTrend = Analytics.inbodyWeightTrend();

        final mainExercises = <ExerciseDef>[];
        for (final d in store.db.days) {
          for (final ex in d.exercises) {
            if (ex.isMain) mainExercises.add(ex);
          }
        }

        final byDay = <String, int>{};
        for (final s in last30) {
          byDay[s.dayName] = (byDay[s.dayName] ?? 0) + 1;
        }

        final skipEntries = Analytics.skippedExercises(last30).entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        final recos = Analytics.smartRecommendations();

        return Scaffold(
          appBar: saqrAppBar(
            eyebrow: 'PROGRESS',
            title: 'التقارير',
            showBack: false,
            actions: [
              IconButton(
                tooltip: 'التقويم الشهري',
                icon: const Icon(Icons.calendar_month_rounded, color: C.text),
                onPressed: () => pushFade(context, const CalendarScreen()),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
            children: [
              StatGrid([
                StatBox('${Analytics.computeStreak()}', '🔥 يوم متتالي'),
                StatBox('${last30.length}', 'أيام تمرين (شهر)'),
                StatBox(Analytics.avgRating(last7), 'متوسط التقييم (أسبوع)'),
                StatBox(Analytics.avgRating(last30), 'متوسط التقييم (شهر)'),
              ]),

              if (recos.isNotEmpty) ...[
                const SectionTitle('🧠 توصيات ذكية'),
                SCard(
                  child: Column(
                    children: [
                      for (var i = 0; i < recos.length; i++)
                        Padding(
                          padding: EdgeInsets.only(
                              bottom: i == recos.length - 1 ? 0 : 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(recos[i].icon,
                                  style: const TextStyle(fontSize: 16)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  recos[i].text,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    height: 1.6,
                                    color: recos[i].level == RecoLevel.warn
                                        ? C.danger
                                        : recos[i].level == RecoLevel.good
                                            ? C.good
                                            : C.text,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],

              const SectionTitle('📈 حجم التمرين أسبوعيًا (وزن × عدات × مجموعات)'),
              SCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('هالأسبوع: ${numStr(thisWeek)}كجم',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        if (trendText.isNotEmpty)
                          Text(trendText,
                              style:
                                  TextStyle(fontSize: 12, color: trendColor)),
                      ],
                    ),
                    LineChartView(weeklyVol,
                        suffix: 'كجم',
                        emptyMsg:
                            'كمّل تمرين أسبوعين متتاليين على الأقل عشان الرسم يبان.'),
                  ],
                ),
              ),

              const SectionTitle('🗓 انتظامك (آخر 8 أسابيع)'),
              const SCard(child: HeatmapView()),

              SectionTitle('⏱ مدة التمرين (آخر ${durations.length} جلسات)'),
              SCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('المتوسط: $avgDuration دقيقة',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    LineChartView(durations,
                        suffix: 'د',
                        height: 110,
                        emptyMsg: 'محتاج جلستين على الأقل عشان الرسم يبان.'),
                  ],
                ),
              ),

              SectionTitle(
                  '🔥 سعرات مقدّرة أسبوعيًا (وزنك الحالي: ${numStr(Analytics.bodyWeightForCalories)}كجم)'),
              SCard(
                child: LineChartView(Analytics.weeklyCalories(weeksBack: 8),
                    suffix: 'kcal', height: 110),
              ),

              const SectionTitle('🧬 وزن الجسم (InBody) بمرور الوقت'),
              SCard(
                child: weightTrend.length < 2
                    ? const Text(
                        'سجّل قياسين InBody على الأقل من صفحة "InBody" عشان الرسم يبان هنا جنب حجم التمرين.',
                        style: TextStyle(
                            fontSize: 12.5, color: C.muted, height: 1.7))
                    : LineChartView(weightTrend, suffix: 'كجم'),
              ),

              const SectionTitle('🏆 تقدير الـ 1RM للتمارين الأساسية'),
              SCard(
                child: mainExercises.isEmpty
                    ? const Text(
                        'مفيش تمارين متعلّمة "أساسي" لسه. تقدر تعلّم أي تمرين من صفحة التعديل عشان يظهر رقمه الأقصى هنا.',
                        style: TextStyle(
                            fontSize: 12.5, color: C.muted, height: 1.7))
                    : Column(
                        children: [
                          for (var i = 0; i < mainExercises.length; i++)
                            _oneRmRow(mainExercises[i],
                                divider: i != mainExercises.length - 1),
                        ],
                      ),
              ),

              const SectionTitle('عدد مرات كل يوم تدريب (آخر 30 يوم)'),
              SCard(
                child: Column(
                  children: [
                    for (var i = 0; i < store.db.days.length; i++)
                      ListRow(
                        divider: i != store.db.days.length - 1,
                        start: Text(store.db.days[i].name,
                            style: const TextStyle(fontSize: 13.5)),
                        end: Pill('${byDay[store.db.days[i].name] ?? 0} مرة'),
                      ),
                  ],
                ),
              ),

              const SectionTitle('تمارين ناقصة أو متجاهلة (آخر 30 يوم)'),
              SCard(
                child: skipEntries.isEmpty
                    ? const Text('مفيش تمارين ناقصة، تمام كده!',
                        style: TextStyle(fontSize: 12.5, color: C.muted))
                    : Column(
                        children: [
                          for (var i = 0;
                              i < skipEntries.length && i < 6;
                              i++)
                            ListRow(
                              divider: i != skipEntries.length - 1 && i != 5,
                              start: Text(skipEntries[i].key,
                                  style: const TextStyle(fontSize: 13)),
                              end: Pill('${skipEntries[i].value} مرة ناقص',
                                  color: C.danger),
                            ),
                        ],
                      ),
              ),

              _SessionHistorySection(sessions: sessions),
            ],
          ),
        );
      },
    );
  }

  Widget _oneRmRow(ExerciseDef ex, {required bool divider}) {
    final hist = Analytics.exerciseHistory(ex.id, ex.name);
    final rms =
        hist.map((h) => Analytics.estimate1RM(h.value, h.reps)).toList();
    final current = rms.isEmpty ? null : rms.last;
    final prev = rms.length > 1 ? rms[rms.length - 2] : null;
    String arrow = '';
    Color arrowColor = C.muted;
    if (current != null && prev != null) {
      if (current > prev) {
        arrow = ' ▲';
        arrowColor = C.good;
      } else if (current < prev) {
        arrow = ' ▼';
        arrowColor = C.danger;
      }
    }
    return ListRow(
      divider: divider,
      start: Text(ex.name, style: const TextStyle(fontSize: 13)),
      end: Row(
        children: [
          Pill(current != null ? '${current}كجم' : 'لسه مفيش بيانات',
              accent: current != null),
          if (arrow.isNotEmpty)
            Text(arrow, style: TextStyle(color: arrowColor, fontSize: 13)),
        ],
      ),
    );
  }
}

/// آخر التمارين مع فلتر حسب اليوم و/أو الجلسات اللي فيها رقم قياسي (PR)
class _SessionHistorySection extends StatefulWidget {
  final List<WorkoutSession> sessions;
  const _SessionHistorySection({required this.sessions});

  @override
  State<_SessionHistorySection> createState() =>
      _SessionHistorySectionState();
}

class _SessionHistorySectionState extends State<_SessionHistorySection> {
  static const _all = 'الكل';
  String _dayFilter = _all;
  bool _prOnly = false;

  @override
  Widget build(BuildContext context) {
    final dayNames = <String>{_all, ...widget.sessions.map((s) => s.dayName)}
        .toList();
    var filtered = widget.sessions.reversed.toList();
    if (_dayFilter != _all) {
      filtered = filtered.where((s) => s.dayName == _dayFilter).toList();
    }
    if (_prOnly) {
      filtered =
          filtered.where((s) => s.exercises.any((e) => e.isPR)).toList();
    }
    final filtering = _dayFilter != _all || _prOnly;
    final shown = filtered.take(filtering ? 30 : 10).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('آخر التمارين'),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final name in dayNames)
                ChoiceChip(
                  label: Text(name, style: const TextStyle(fontSize: 12)),
                  selected: _dayFilter == name,
                  onSelected: (_) => setState(() => _dayFilter = name),
                  selectedColor: C.accent,
                  backgroundColor: C.panel2,
                  labelStyle:
                      TextStyle(color: _dayFilter == name ? Colors.white : C.text),
                  side: const BorderSide(color: C.border),
                ),
              FilterChip(
                label:
                    const Text('🏆 فيها PR بس', style: TextStyle(fontSize: 12)),
                selected: _prOnly,
                onSelected: (v) => setState(() => _prOnly = v),
                selectedColor: C.accent,
                backgroundColor: C.panel2,
                labelStyle: TextStyle(color: _prOnly ? Colors.white : C.text),
                side: const BorderSide(color: C.border),
              ),
            ],
          ),
        ),
        if (shown.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text('مفيش جلسات مطابقة للفلتر ده.',
                style: TextStyle(fontSize: 12.5, color: C.muted)),
          ),
        ...shown.map((s) => SCard(
              onTap: () =>
                  pushFade(context, SessionDetailScreen(sessionId: s.id)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${s.dayName} · ${fmtDateShort(s.date)}',
                            style: const TextStyle(fontSize: 13.5)),
                        const SizedBox(height: 3),
                        Text(
                          '${s.durationMinutes} دقيقة · ${Analytics.sessionVolume(s)}كجم حجم'
                          '${s.exercises.any((e) => e.isPR) ? ' · 🏆 PR' : ''}',
                          style: const TextStyle(
                              fontSize: 11.5, color: C.muted),
                        ),
                      ],
                    ),
                  ),
                  Pill(s.rating != null ? '${s.rating}/10' : '-',
                      accent: true),
                ],
              ),
            )),
      ],
    );
  }
}
