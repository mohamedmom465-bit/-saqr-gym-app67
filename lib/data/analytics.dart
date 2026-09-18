import 'dart:math';

import 'models.dart';
import 'store.dart';

/// نقطة على أي رسم بياني
class ChartPoint {
  final DateTime date;
  final double value;
  final String reps;
  final bool isPR;
  ChartPoint(this.date, this.value, {this.reps = '', this.isPR = false});
}

class LastPerformance {
  final DateTime date;
  final String weight;
  final String reps;
  final int setsLogged;
  LastPerformance(this.date, this.weight, this.reps, this.setsLogged);
}

class Analytics {
  /// الجلسات الفعلية فقط. Quick-log يظل موجودًا في السجل، لكن لا يدخل
  /// في الحجم/الـPR/التاريخ/التوصيات حتى لا يحوّل تأكيد الإشعار إلى
  /// أداء مُسجّل فعليًا.
  static List<WorkoutSession> get realSessions =>
      db.sessions.where((s) => !s.isQuickLog).toList();


  static GymDB get db => store.db;

  /// استخراج رقم مفيد من نص العدات زي "8-12" أو "10 دقائق"
  static double parseRepsNum(String reps) {
    final nums = RegExp(r'\d+').allMatches(reps).map((m) => m.group(0)!).toList();
    if (nums.isEmpty) return 10;
    if (nums.length >= 2) {
      return (int.parse(nums[0]) + int.parse(nums[1])) / 2;
    }
    return double.parse(nums[0]);
  }

  /// الوقت المتوقع لليوم بالثواني (نفس معادلة نسخة الويب)
  static int estimateDuration(WorkoutDay day) {
    final s = db.settings;
    double total = 0;
    for (final ex in day.exercises) {
      if (ex.cardio && ex.reps.contains('دقيق')) {
        total += parseRepsNum(ex.reps) * 60 * ex.sets;
        continue;
      }
      total += parseRepsNum(ex.reps) * 3 * ex.sets;
      total += ex.rest * max(0, ex.sets - 1);
      if (ex.plates) total += s.transitionSeconds;
    }
    total += (day.exercises.length - 1) * 20;
    return total.round();
  }

  /// آخر أداء متسجل لتمرين معيّن
  static LastPerformance? lastPerformance(String exId, String name) {
    for (final s in realSessions.reversed) {
      final match = _findLog(s, exId, name);
      if (match != null) {
        final done =
            match.loggedSets.where((x) => x.done && x.hasWeight).toList();
        if (done.isNotEmpty) {
          final top = done.reduce((a, b) => b.weightNum > a.weightNum ? b : a);
          return LastPerformance(s.date, top.weight, top.reps, done.length);
        }
      }
    }
    return null;
  }

  static SessionExercise? _findLog(
      WorkoutSession s, String exId, String name) {
    for (final e in s.exercises) {
      if (e.exerciseId == exId || e.name == name) return e;
    }
    return null;
  }

  /// كل المجموعات المتسجلة آخر مرة — بتستخدم في ملء الجلسة الجديدة تلقائي
  static List<LoggedSet>? lastSessionLoggedSets(String exId, String name) {
    for (final s in realSessions.reversed) {
      final match = _findLog(s, exId, name);
      if (match != null) {
        final done =
            match.loggedSets.where((x) => x.done && x.hasWeight).toList();
        if (done.isNotEmpty) return done;
      }
    }
    return null;
  }

  /// تاريخ أعلى وزن لكل جلسة لتمرين معيّن
  static List<ChartPoint> exerciseHistory(String exId, String name) {
    final rows = <ChartPoint>[];
    for (final s in realSessions) {
      final match = _findLog(s, exId, name);
      if (match == null) continue;
      final done = match.loggedSets
          .where((x) => x.done && x.hasWeight && x.weightNum > 0)
          .toList();
      if (done.isEmpty) continue;
      final top = done.reduce((a, b) => b.weightNum > a.weightNum ? b : a);
      rows.add(ChartPoint(s.date, top.weightNum,
          reps: top.reps, isPR: match.isPR));
    }
    return rows;
  }

  /// تقدير الرقم الأقصى — متوسط 3 معادلات (Epley + Brzycki + Lombardi)
  /// عشان يبقى أدق من معادلة واحدة لوحدها، خصوصًا في مدى العدات المختلف
  static int estimate1RM(double weight, String reps) {
    final r = double.tryParse(reps.trim()) ?? 1;
    if (weight <= 0 || r <= 0) return 0;
    if (r == 1) return weight.round();

    final epley = weight * (1 + r / 30);
    final brzyckiDenom = 1.0278 - 0.0278 * r;
    final brzycki = brzyckiDenom > 0.2 ? weight / brzyckiDenom : epley;
    final lombardi = weight * pow(r, 0.10);

    return ((epley + brzycki + lombardi) / 3).round();
  }

  /// حجم التمرين = وزن × عدات لكل المجموعات المكتملة
  static int sessionVolume(WorkoutSession s) {
    double total = 0;
    for (final ex in s.exercises) {
      for (final set in ex.loggedSets) {
        if (set.done && set.hasWeight && set.reps.trim().isNotEmpty) {
          total += set.weightNum * set.repsNum;
        }
      }
    }
    return total.round();
  }

  static DateTime weekStart(DateTime d) {
    final dt = DateTime(d.year, d.month, d.day);
    // نفس منطق الويب: الأسبوع بيبدأ يوم الأحد
    return dt.subtract(Duration(days: dt.weekday % 7));
  }

  static List<ChartPoint> weeklyVolume({int weeksBack = 8}) {
    final map = <int, int>{};
    for (final s in realSessions) {
      final key = weekStart(s.date).millisecondsSinceEpoch;
      map[key] = (map[key] ?? 0) + sessionVolume(s);
    }
    final cursor = weekStart(DateTime.now());
    final rows = <ChartPoint>[];
    for (var i = weeksBack - 1; i >= 0; i--) {
      final wk = cursor.subtract(Duration(days: i * 7));
      rows.add(ChartPoint(
          wk, (map[wk.millisecondsSinceEpoch] ?? 0).toDouble()));
    }
    return rows;
  }

  static List<ChartPoint> sessionDurations({int limit = 10}) {
    final list = realSessions.length > limit
        ? realSessions.sublist(realSessions.length - limit)
        : realSessions;
    return list
        .map((s) => ChartPoint(s.date, s.durationMinutes.toDouble()))
        .toList();
  }

  static List<ChartPoint> inbodyWeightTrend() {
    final list = db.inbody
        .where((m) => m.weight != null && m.weight! > 0)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return list.map((m) => ChartPoint(m.date, m.weight!)).toList();
  }

  /// أيام متتالية فيها تمرين
  static int computeStreak() {
    if (realSessions.isEmpty) return 0;
    final days = realSessions
        .map((s) => DateTime(s.date.year, s.date.month, s.date.day))
        .toSet();
    var cursor = DateTime.now();
    cursor = DateTime(cursor.year, cursor.month, cursor.day);
    // لو النهارده لسه ما اتعملش فيه تمرين، نبدأ نعد من إمبارح بدل
    // ما نوقف على طول (عشان الستريك يفضل شغال لحد ما اليوم يخلص).
    if (!days.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!days.contains(cursor)) return 0;
    }
    var streak = 0;
    while (days.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// خريطة الانتظام: قائمة من (فيه تمرين؟، في المستقبل؟) بترتيب الأسابيع
  static List<List<bool>> consistencyGrid({int weeks = 8}) {
    final today = DateTime.now();
    final t = DateTime(today.year, today.month, today.day);
    var start = weekStart(t).subtract(Duration(days: (weeks - 1) * 7));
    final dates = realSessions
        .map((s) => DateTime(s.date.year, s.date.month, s.date.day))
        .toSet();
    final cells = <List<bool>>[];
    for (var i = 0; i < weeks * 7; i++) {
      final d = start.add(Duration(days: i));
      cells.add([dates.contains(d), d.isAfter(t)]);
    }
    return cells;
  }

  /// كشف الأرقام القياسية قبل حفظ الجلسة
  static List<String> detectAndMarkPRs(WorkoutSession session) {
    final newPRs = <String>[];
    for (final ex in session.exercises) {
      final done = ex.loggedSets
          .where((s) => s.done && s.hasWeight && s.weightNum > 0)
          .toList();
      if (done.isEmpty) continue;
      final topWeight =
          done.map((s) => s.weightNum).reduce((a, b) => a > b ? a : b);
      double priorBest = 0;
      for (final s in realSessions) {
        final match = _findLog(s, ex.exerciseId, ex.name);
        if (match == null) continue;
        final mdone = match.loggedSets
            .where((x) => x.done && x.hasWeight && x.weightNum > 0)
            .toList();
        if (mdone.isEmpty) continue;
        final mtop =
            mdone.map((x) => x.weightNum).reduce((a, b) => a > b ? a : b);
        if (mtop > priorBest) priorBest = mtop;
      }
      if (topWeight > priorBest) {
        ex.isPR = true;
        newPRs.add(ex.name);
      }
    }
    return newPRs;
  }

  static double bestEverWeight(String exId, String name) {
    final hist = exerciseHistory(exId, name);
    if (hist.isEmpty) return 0;
    return hist.map((h) => h.value).reduce((a, b) => a > b ? a : b);
  }

  // ---------- حاسبة الأطباق ----------
  static Map<String, dynamic>? calcPlates(double total, {double? bar}) {
    final b = bar ?? db.settings.barWeight;
    final perSide = (total - b) / 2;
    if (perSide <= 0) return null;
    const denom = [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25];
    var remaining = (perSide * 4).round() / 4;
    final used = <double>[];
    for (final p in denom) {
      while (remaining >= p - 0.001) {
        used.add(p);
        remaining -= p;
      }
    }
    return {'used': used, 'leftover': max(0, remaining), 'bar': b};
  }

  static String platesText(double total) {
    final bar = db.settings.barWeight;
    final r = calcPlates(total);
    if (r == null) {
      return 'الوزن ده أقل من أو يساوي وزن البار (${_n(bar)}كجم).';
    }
    final used = (r['used'] as List<double>);
    if (used.isEmpty) return 'بار فاضي بس (${_n(bar)}كجم).';
    var txt =
        'كل جنب: ${used.map(_n).join(' + ')} كجم (بار ${_n(bar)}كجم)';
    final leftover = (r['leftover'] as num).toDouble();
    if (leftover > 0.01) {
      txt +=
          ' — فاضل ${leftover.toStringAsFixed(2)}كجم مش قابلة للتقسيم بالأطباق العادية';
    }
    return txt;
  }

  static String _n(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();

  // ---------- أرقام التقارير ----------
  static String avgRating(List<WorkoutSession> list) {
    final rated = list.where((s) => s.rating != null).toList();
    if (rated.isEmpty) return '-';
    final sum = rated.fold<int>(0, (a, s) => a + s.rating!);
    return (sum / rated.length).toStringAsFixed(1);
  }

  static Map<String, int> skippedExercises(List<WorkoutSession> last30) {
    final skip = <String, int>{};
    for (final s in last30) {
      for (final ex in s.exercises) {
        final completed = ex.loggedSets
            .where((set) => set.done && set.reps.trim().isNotEmpty)
            .length;
        if (completed < ex.targetSets) {
          skip[ex.name] = (skip[ex.name] ?? 0) + 1;
        }
      }
    }
    return skip;
  }

  // ---------- #29 Auto-deload ----------

  /// لكل جلسة قديمة سجّل فيها التمرين ده: هل خلّص كل المجموعات المطلوبة؟
  /// وإيه أعلى وزن سجّله فيها. بترجع الأحدث الأول.
  static List<({bool fullyCompleted, double topWeight})> _recentExercisePerf(
      String exId, String name, {int limit = 3}) {
    final rows = <({bool fullyCompleted, double topWeight})>[];
    for (final s in realSessions.reversed) {
      final match = _findLog(s, exId, name);
      if (match == null) continue;
      final done = match.loggedSets
          .where((x) => x.done && x.hasWeight && x.weightNum > 0)
          .toList();
      if (done.isEmpty) continue;
      final top = done.map((x) => x.weightNum).reduce((a, b) => a > b ? a : b);
      final completedCount =
          match.loggedSets.where((x) => x.done && x.hasWeight).length;
      rows.add((
        fullyCompleted: completedCount >= match.targetSets,
        topWeight: top,
      ));
      if (rows.length >= limit) break;
    }
    return rows;
  }

  /// مقترح تقليل حمل (Deload): لو آخر جلستين على الأقل فشل فيهم المستخدم
  /// يخلّص كل المجموعات المطلوبة *و* الوزن مستني أو نازل (مش بيتحسن) —
  /// ده مؤشر إرهاق تراكمي محتاج أسبوع حمل أخف بدل ما يكمل يزوّد عادي.
  static bool shouldDeload(String exId, String name) {
    final recent = _recentExercisePerf(exId, name, limit: 3);
    if (recent.length < 2) return false;
    final lastTwoFailed = recent.take(2).every((r) => !r.fullyCompleted);
    if (!lastTwoFailed) return false;
    // الوزن مش بيتحسن (آخر مرة ≤ اللي قبلها) — مش مجرد يوم تعبان واحد
    final notImproving = recent[0].topWeight <= recent[1].topWeight;
    return notImproving;
  }

  /// نسبة تقليل الحمل المقترحة عند الـ Deload — 10% تخفيف كلاسيكي،
  /// مقرّب لأقرب 2.5 كجم عشان يبقى رقم عملي على الأطباق.
  static double deloadWeight(double lastWeight) {
    final target = lastWeight * 0.9;
    return (target / 2.5).round() * 2.5;
  }

  // ---------- #30 Fatigue Detection ----------

  /// إرهاق داخل نفس الجلسة: بيقارن متوسط عدات آخر مجموعتين اتسجلوا
  /// بأول مجموعة (بنفس الوزن أو أعلى) — هبوط واضح في العدات مع
  /// استمرار نفس الوزن أو زيادته علامة كلاسيكية على الإرهاق العضلي.
  static bool intraSessionFatigue(List<LoggedSet> loggedSets) {
    final done = loggedSets
        .where((s) => s.done && s.hasWeight && s.reps.trim().isNotEmpty)
        .toList();
    if (done.length < 3) return false;
    final first = done.first;
    final last = done.last;
    if (first.repsNum <= 0) return false;
    final sameOrHeavier = last.weightNum >= first.weightNum - 0.01;
    final repsDropped = last.repsNum <= first.repsNum * 0.7;
    return sameOrHeavier && repsDropped;
  }

  // ---------- #33 Volume Tracker (تفصيلي لكل تمرين) ----------

  static int _setVolume(SessionExercise ex) {
    var total = 0.0;
    for (final s in ex.loggedSets) {
      if (s.done && s.hasWeight && s.reps.trim().isNotEmpty) {
        total += s.weightNum * s.repsNum;
      }
    }
    return total.round();
  }

  /// حجم (وزن × عدات) التمرين المعيّن ده بس، عبر كل الجلسات اللي اتسجل فيها
  static List<ChartPoint> exerciseVolumeHistory(String exId, String name) {
    final rows = <ChartPoint>[];
    for (final s in realSessions) {
      final match = _findLog(s, exId, name);
      if (match == null) continue;
      final v = _setVolume(match);
      if (v <= 0) continue;
      rows.add(ChartPoint(s.date, v.toDouble()));
    }
    return rows;
  }

  /// نسبة تغيّر حجم التمرين الكلي: الأسبوع الحالي مقابل اللي قبله —
  /// null لو مفيش بيانات كفاية للمقارنة.
  static double? weeklyVolumeChangePct() {
    final weeks = weeklyVolume(weeksBack: 2);
    if (weeks.length < 2) return null;
    final prev = weeks[0].value;
    final curr = weeks[1].value;
    if (prev <= 0) return null;
    return ((curr - prev) / prev) * 100;
  }

  // ---------- دفعة 8 / #13 Smart Recommendations ----------

  /// توصيات ذكية مبنية بالكامل على تحليلات موجودة بالفعل (حجم أسبوعي،
  /// Deload، الستريك، التمارين المتجاهلة...) — مفيش أي حقل جديد في الـ DB.
  static List<Recommendation> smartRecommendations() {
    final list = <Recommendation>[];
    if (realSessions.isEmpty) return list;

    final volChange = weeklyVolumeChangePct();
    if (volChange != null) {
      if (volChange <= -15) {
        list.add(Recommendation(
          '📉',
          'حجم تمرينك نزل ${volChange.abs().round()}% عن الأسبوع اللي فات — خد بالك من النوم والأكل، ولو حاسس بإرهاق متردّدش تاخد يوم راحة زيادة.',
          RecoLevel.warn,
        ));
      } else if (volChange >= 20) {
        list.add(Recommendation(
          '📈',
          'حجم تمرينك زاد ${volChange.round()}% عن الأسبوع اللي فات — حافظ على النوم والبروتين عشان تساير الحمل الجديد وتقلل خطر الإصابة.',
          RecoLevel.good,
        ));
      }
    }

    final deloadNames = <String>{};
    for (final d in db.days) {
      for (final ex in d.exercises) {
        if (deloadNames.contains(ex.name)) continue;
        if (shouldDeload(ex.id, ex.name)) deloadNames.add(ex.name);
      }
    }
    if (deloadNames.isNotEmpty) {
      list.add(Recommendation(
        '🔻',
        'آخر جلستين على ${deloadNames.take(3).join('، ')} مكملتش المجموعات المطلوبة من غير تحسّن في الوزن — جرب تقلل الوزن ~10% أسبوع واحد وارجع زوّد تاني بعدها.',
        RecoLevel.warn,
      ));
    }

    final streak = computeStreak();
    if (streak >= 6) {
      list.add(Recommendation(
        '😴',
        'أنت مكمل $streak يوم متتالي — جسمك محتاج يوم راحة كامل عشان العضلات تتعافى وتكبر صح.',
        RecoLevel.info,
      ));
    }

    final last30 = realSessions
        .where((s) => DateTime.now().difference(s.date).inDays <= 30)
        .toList();
    final skipped = skippedExercises(last30).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (skipped.isNotEmpty && skipped.first.value >= 3) {
      list.add(Recommendation(
        '⚠️',
        'تمرين "${skipped.first.key}" ناقص أو متجاهل ${skipped.first.value} مرة في آخر 30 يوم — جرب تحطه أول التمرين أو تقلل عدد مجموعاته.',
        RecoLevel.warn,
      ));
    }

    final gap = DateTime.now().difference(realSessions.last.date).inDays;
    if (gap >= 4) {
      list.add(Recommendation(
        '👋',
        'مرّ $gap أيام من غير تمرين — ابدأ بجلسة خفيفة عشان ترجع بسهولة من غير ما تحمّل نفسك جامد من أول مرة.',
        RecoLevel.info,
      ));
    }

    if (list.isEmpty) {
      list.add(Recommendation(
        '✅',
        'كل المؤشرات كويسة — حجم تمرينك ثابت أو بيزيد، ومفيش علامات إرهاق واضحة. استمر بنفس النمط.',
        RecoLevel.good,
      ));
    }
    return list;
  }

  // ---------- دفعة 9 / #43 Calories Estimate ----------

  /// معدلات MET تقريبية (Compendium of Physical Activities): تمرين حديد
  /// عادي مع فترات راحة، سيشن بطن كثيف، وكارديو مستمر.
  static const double _metStrength = 5.0;
  static const double _metCore = 4.0;
  static const double _metCardio = 7.5;

  /// وزن الجسم المستخدم في حساب السعرات: آخر قياس InBody متسجل، أو
  /// الوزن الافتراضي من الإعدادات لو مفيش قياس خالص.
  static double get bodyWeightForCalories {
    final withWeight =
        db.inbody.where((e) => e.weight != null && e.weight! > 0).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    if (withWeight.isNotEmpty) return withWeight.last.weight!;
    return db.settings.fallbackBodyWeightKg;
  }

  /// تقدير السعرات المحروقة في جلسة — بيوزّع مدة الجلسة الحقيقية على
  /// حديد/بطن/كارديو حسب عدد المجموعات المكتملة من كل نوع، وبيطبّق
  /// معامل MET مختلف لكل نوع. تقدير تقريبي (زي أي تطبيق تمرين) مش دقيق طبيًا.
  static int estimateCalories(WorkoutSession s) {
    final weight = bodyWeightForCalories;
    final minutes = s.durationMinutes;
    if (minutes <= 0 || weight <= 0) return 0;
    final hours = minutes / 60;

    var cardioSets = 0, coreSets = 0, strengthSets = 0;
    for (final ex in s.exercises) {
      final done = ex.loggedSets.where((x) => x.done).length;
      if (ex.cardio) {
        cardioSets += done;
      } else if (ex.core) {
        coreSets += done;
      } else {
        strengthSets += done;
      }
    }
    final totalSets = cardioSets + coreSets + strengthSets;
    if (totalSets == 0) {
      // جلسة من غير مجموعات متسجلة (زي Quick-log من الإشعار) — معدل عام
      return (_metStrength * weight * hours).round();
    }
    double kcal = 0;
    kcal += (cardioSets / totalSets) * hours * _metCardio * weight;
    kcal += (coreSets / totalSets) * hours * _metCore * weight;
    kcal += (strengthSets / totalSets) * hours * _metStrength * weight;
    return kcal.round();
  }

  /// إجمالي السعرات المقدّرة لكل أسبوع — نفس شكل weeklyVolume بالظبط
  /// عشان يتعرض بنفس الرسم البياني التفاعلي.
  static List<ChartPoint> weeklyCalories({int weeksBack = 8}) {
    final map = <int, int>{};
    for (final s in realSessions) {
      final key = weekStart(s.date).millisecondsSinceEpoch;
      map[key] = (map[key] ?? 0) + estimateCalories(s);
    }
    final cursor = weekStart(DateTime.now());
    final rows = <ChartPoint>[];
    for (var i = weeksBack - 1; i >= 0; i--) {
      final wk = cursor.subtract(Duration(days: i * 7));
      rows.add(
          ChartPoint(wk, (map[wk.millisecondsSinceEpoch] ?? 0).toDouble()));
    }
    return rows;
  }

  // ---------- دفعة 9 / #40 Workout Reminder + #42 Quick-log ----------

  /// هل فيه جلسة اتسجلت في تاريخ معيّن (مقارنة باليوم بس، من غير وقت)؟
  static bool hasSessionOnDate(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return db.sessions.any(
        (s) => DateTime(s.date.year, s.date.month, s.date.day) == d);
  }

  /// اليوم "الجاي في الدور" — التمرين اللي بعد آخر يوم اتعمل في نفس
  /// ترتيب قائمة الأيام (Round-robin)، لأن مفيش جدول أسبوعي ثابت في
  /// التطبيق أصلًا. بتُستخدم في نص إشعار التذكير وفي الـ Quick-log.
  static WorkoutDay? suggestedNextDay() {
    if (db.days.isEmpty) return null;
    if (db.sessions.isEmpty) return db.days.first;
    final latest =
        db.sessions.reduce((a, b) => b.date.isAfter(a.date) ? b : a);
    final idx = db.days.indexWhere((d) => d.id == latest.dayId);
    if (idx == -1) return db.days.first;
    return db.days[(idx + 1) % db.days.length];
  }
}

enum RecoLevel { info, good, warn }

class Recommendation {
  final String icon;
  final String text;
  final RecoLevel level;
  Recommendation(this.icon, this.text, this.level);
}
