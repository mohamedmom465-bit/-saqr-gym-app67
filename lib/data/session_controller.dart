import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/feedback.dart';
import 'analytics.dart';
import 'gamification.dart';
import 'models.dart';
import 'store.dart';

/// نتيجة حفظ الجلسة: الأرقام القياسية + أي إنجازات (#20) اتفتحت جديد +
/// هل حصل ترقية مستوى (#19) — كلها بتتحسب مرة واحدة عند الحفظ عشان
/// شاشة تقييم التمرين تحتفل بيهم كلهم مع بعض.
class SaveResult {
  final List<String> prs;
  final List<Achievement> newAchievements;
  final bool leveledUp;
  final LevelInfo level;
  SaveResult({
    required this.prs,
    required this.newAchievements,
    required this.leveledUp,
    required this.level,
  });
}

const _kActiveSessionKey = 'saqr_gym_active_session_v1';

/// بيدير الجلسة الشغالة: التايمرات، فتح التمارين تدريجيًا، الدروب سيت... إلخ
/// وكمان بيحفظ حالتها أول بأول عشان لو التطبيق اتقفل فجأة (الجهاز قفله
/// أو نفدت الذاكرة) يرجع بالظبط من نفس اللحظة بدقة: وقت التمرين بيتحسب
/// من "وقت البدء" الحقيقي، وتايمر الراحة بيتحسب من "ديدلاين" (وقت نهاية
/// الراحة الفعلي) مش من عدّاد بينقص، فمهما فات وقت وانت مقفل التطبيق
/// هيرجع يوريك الرقم الصح بالظبط.
class SessionController extends ChangeNotifier with WidgetsBindingObserver {
  WorkoutSession? session;

  /// جلسة انتهت قبل اكتمال حفظها في SQLite. بنرجعها كجلسة قابلة للحفظ بدل
  /// حذفها من SharedPreferences وبالتالي فقدان التمرين بعد crash.

  Timer? _workTimer;
  Timer? _restTimer;
  Timer? _waterTimer;
  Timer? _saveDebounce;

  /// وقت نهاية الراحة الفعلي (epoch ms) — المرجع الوحيد للحساب
  int? _restDeadlineMs;

  /// ثواني التمرين الكلي — منفصلة عشان الساعة بس هي اللي تتحدث كل ثانية
  final ValueNotifier<int> workSeconds = ValueNotifier(0);

  /// ثواني الراحة المتبقية (null = مفيش راحة شغالة)
  final ValueNotifier<int?> restLeft = ValueNotifier(null);
  int restTotal = 0;

  bool get isActive => session != null;

  /// عنصر #5 Progress Ring — إجمالي المجموعات المخططة في التمرين الحالي
  /// (كل التمارين، حتى المقفولة لسه) وعدد اللي اتسجل منها فعلاً.
  /// النسبة دي بتتغذى منها الـ Progress Ring في أعلى شاشة التمرين.
  int get totalPlannedSets {
    final s = session;
    if (s == null) return 0;
    var n = 0;
    for (final ex in s.exercises) {
      n += ex.loggedSets.length;
    }
    return n;
  }

  int get completedSets {
    final s = session;
    if (s == null) return 0;
    var n = 0;
    for (final ex in s.exercises) {
      n += ex.loggedSets.where((set) => set.done).length;
    }
    return n;
  }

  /// نسبة من 0 لـ 1 — 0 لو مفيش مجموعات لسه (بداية التمرين).
  double get setsProgress {
    final total = totalPlannedSets;
    if (total == 0) return 0;
    return completedSets / total;
  }

  /// بيتنادى مرة واحدة عند فتح التطبيق (بعد store.init) عشان يشوف لو
  /// فيه جلسة كانت شغالة ووقفت فجأة، ويرجّعها بنفس دقة التوقيت.
  Future<void> restoreIfAny() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kActiveSessionKey);
      if (raw == null) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final restored =
          WorkoutSession.fromJson(Map<String, dynamic>.from(map['session']));
      // لو الجلسة كانت انتهت قبل ما SQLite تستقبلها، نخليها متاحة للحفظ.
      // ده يمنع فقدان التمرين لو حصل crash أثناء الانتقال لشاشة النهاية.
      session = restored;
      restTotal = (map['restTotal'] as num?)?.toInt() ?? 0;
      _restDeadlineMs = (map['restDeadline'] as num?)?.toInt();

      _startWorkTimer();
      _startWaterReminder();

      if (_restDeadlineMs != null) {
        final remaining =
            ((_restDeadlineMs! - DateTime.now().millisecondsSinceEpoch) / 1000)
                .ceil();
        if (remaining > 0) {
          restLeft.value = remaining;
          _tickRestLoop();
        } else {
          // الراحة خلصت وإحنا مقفلين التطبيق — نقفلها من غير تنبيه قديم
          _restDeadlineMs = null;
          restLeft.value = null;
        }
      }

      // ملحوظة: مبنفعلش الـ wake lock هنا — بيتفعّل بس لما المستخدم
      // يدخل فعليًا شاشة التمرين (Wake Lock ذكي، شوف session_screen.dart)
      notifyListeners();
    } catch (e) {
      debugPrint('session restore error: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // أي لحظة التطبيق بيروح الخلفية أو ممكن يتقفل فيها، نفرّغ أي حفظ
    // متأجل (debounce) فورًا عشان محدش يخسر ثانية وحدة من التقدّم.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _saveDebounce?.cancel();
      unawaited(_persist());
    }
  }

  // ---------- بدء الجلسة ----------

  /// دفعة 9: استخرجنا منطق ملء التمارين (أوزان آخر مرة، الزيادة/التخفيف
  /// التلقائي) في دالة static مستقلة عشان تتستخدم هنا وكمان من الـ
  /// Quick-log بتاع الإشعار (`lib/services/notifications.dart`) من غير
  /// أي تكرار في الكود.
  static List<SessionExercise> buildPrefilledExercises(WorkoutDay day) {
    final settings = store.db.settings;
    final exercises = <SessionExercise>[];

    for (final ex in day.exercises) {
      final prevSets = Analytics.lastSessionLoggedSets(ex.id, ex.name);
      final fullyCompleted = prevSets != null && prevSets.length >= ex.sets;
      final autoBump = fullyCompleted && settings.autoProgress;
      // #29 Auto-deload: لو مش بيكمل مجموعاته وواقف في نفس الوزن آخر
      // جلستين، اقترح تخفيف الحمل بدل ما نكمل نزوّد عادي أو نسيبه يتعب أكتر.
      final deload =
          !fullyCompleted && settings.autoProgress && Analytics.shouldDeload(ex.id, ex.name);

      final logged = List.generate(ex.sets, (i) {
        LoggedSet? prev;
        if (prevSets != null && prevSets.isNotEmpty) {
          prev = i < prevSets.length ? prevSets[i] : prevSets.last;
        }
        var w = prev?.weight ?? '';
        if (prev != null && autoBump) {
          final v = prev.weightNum + 2.5;
          w = v == v.roundToDouble() ? v.round().toString() : v.toString();
        } else if (prev != null && deload && prev.weightNum > 0) {
          final v = Analytics.deloadWeight(prev.weightNum);
          w = v == v.roundToDouble() ? v.round().toString() : v.toString();
        }
        return LoggedSet(weight: w, reps: prev?.reps ?? '');
      });

      exercises.add(SessionExercise(
        exerciseId: ex.id,
        name: ex.name,
        targetSets: ex.sets,
        targetReps: ex.reps,
        rest: ex.rest,
        core: ex.core,
        cardio: ex.cardio,
        noRestAfter: ex.noRestAfter,
        prefilled: prevSets != null,
        autoBumped: autoBump,
        deloadSuggested: deload,
        loggedSets: logged,
      ));
    }
    return exercises;
  }

  void start(WorkoutDay day) {
    session = WorkoutSession(
      id: uid('s'),
      dayId: day.id,
      dayName: day.name,
      date: DateTime.now(),
      startedAt: DateTime.now().millisecondsSinceEpoch,
      exercises: buildPrefilledExercises(day),
    );

    _startWorkTimer();
    _startWaterReminder();
    // الـ wake lock بيتفعّل من شاشة التمرين نفسها (Wake Lock ذكي)
    unawaited(_persist());
    notifyListeners();
  }

  void _startWorkTimer() {
    _workTimer?.cancel();
    workSeconds.value = session == null
        ? 0
        : ((DateTime.now().millisecondsSinceEpoch - session!.startedAt) / 1000)
            .round();
    _workTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (session == null) return;
      workSeconds.value =
          ((DateTime.now().millisecondsSinceEpoch - session!.startedAt) / 1000)
              .round();
    });
  }

  void _startWaterReminder() {
    _waterTimer?.cancel();
    final mins = max(1, store.db.settings.waterIntervalMin);
    _waterTimer = Timer.periodic(Duration(minutes: mins), (_) {
      if (session != null) {
        Fx.notify('💧 وقت شرب المية!', 'خد شوية ميه وكمل تمرينك');
      }
    });
  }

  // ---------- المجموعات ----------
  void updateWeight(int exIdx, int setIdx, String value) {
    session!.exercises[exIdx].loggedSets[setIdx].weight = value;
    _persistDebounced();
  }

  void updateReps(int exIdx, int setIdx, String value) {
    session!.exercises[exIdx].loggedSets[setIdx].reps = value;
    _persistDebounced();
  }

  void updateNote(int exIdx, int setIdx, String value) {
    session!.exercises[exIdx].loggedSets[setIdx].note = value;
    _persistDebounced();
  }

  /// زرار + / − بيزود أو ينقص 2.5 كجم
  String nudgeWeight(int exIdx, int setIdx, double delta) {
    final set = session!.exercises[exIdx].loggedSets[setIdx];
    var w = (set.weightNum + delta);
    if (w < 0) w = 0;
    w = (w * 100).round() / 100;
    set.weight = w == w.roundToDouble() ? w.round().toString() : w.toString();
    Fx.tapVibe();
    _persistDebounced();
    return set.weight;
  }

  void addSet(int exIdx) {
    final ex = session!.exercises[exIdx];
    ex.loggedSets.add(LoggedSet());
    ex.unlockedSetCount = max(ex.unlockedSetCount, ex.loggedSets.length);
    unawaited(_persist());
    notifyListeners();
  }

  void removeSet(int exIdx, int setIdx) {
    final ex = session!.exercises[exIdx];
    if (ex.loggedSets.length <= 1) return;
    ex.loggedSets.removeAt(setIdx);
    ex.unlockedSetCount = min(ex.unlockedSetCount, ex.loggedSets.length);
    unawaited(_persist());
    notifyListeners();
  }

  /// دروب سيت: وزن أخف ~20% وكمل على طول من غير راحة
  void addDropSet(int exIdx) {
    final ex = session!.exercises[exIdx];
    final lastSet = ex.loggedSets.last;
    final lastWeight = lastSet.weightNum;
    var dropWeight = '';
    if (lastWeight > 0) {
      var d = ((lastWeight * 0.8) / 1.25).round() * 1.25;
      if (d >= lastWeight) d = max(0, lastWeight - 2.5);
      dropWeight = d == d.roundToDouble() ? d.round().toString() : d.toString();
    }
    ex.loggedSets.add(LoggedSet(weight: dropWeight, isDrop: true));
    ex.unlockedSetCount = ex.loggedSets.length;
    _cancelRest();
    Fx.setDoneVibe();
    Fx.toast(
      '🔽 دروب سيت! نزّل الوزن لـ${dropWeight.isEmpty ? 'وزن أخف' : dropWeight}كجم وكمل على طول من غير راحة',
      duration: const Duration(milliseconds: 2800),
    );
    unawaited(_persist());
    notifyListeners();
  }

  /// تبديل اسم التمرين للجلسة دي بس
  void swapExercise(int exIdx, String newName) {
    final ex = session!.exercises[exIdx];
    ex.name = newName;
    ex.swapped = true;
    unawaited(_persist());
    notifyListeners();
  }

  void toggleSet(int exIdx, int setIdx) {
    final ex = session!.exercises[exIdx];
    final set = ex.loggedSets[setIdx];
    set.done = !set.done;

    if (!set.done) {
      unawaited(_persist());
      notifyListeners();
      return;
    }

    // احتفال بالرقم القياسي وسط التمرين — الكونفيتي والهابتك المتدرج
    // بيتولّوا من الواجهة (session_screen) عشان نعرف مكان اللمسة بالظبط،
    // وهنا بس بنعرض التوست لو حصل رقم قياسي.
    final bestBefore = Analytics.bestEverWeight(ex.exerciseId, ex.name);
    final w = set.weightNum;
    if (w > 0 && w > bestBefore) {
      Fx.toast('🏆 رقم قياسي جديد في "${ex.name}"! ${set.weight}كجم',
          duration: const Duration(milliseconds: 2600));
    }

    // فتح تدريجي ثابت: اللي اتفتح ما بيتقفلش تاني
    ex.unlockedSetCount = max(ex.unlockedSetCount, setIdx + 2);
    final allDone = ex.loggedSets.every((s) => s.done);
    if (allDone) {
      Fx.toast('💥 خلصت "${ex.name}"! كمل كده',
          duration: const Duration(milliseconds: 1800));
      session!.unlockedExerciseCount =
          max(session!.unlockedExerciseCount, exIdx + 2);
    }

    final isLastSetOfEx = setIdx == ex.loggedSets.length - 1;
    final isLastEx = exIdx == session!.exercises.length - 1;
    final skipForSuperset = isLastSetOfEx && ex.noRestAfter && !isLastEx;

    if (!(isLastSetOfEx && isLastEx) && !skipForSuperset && ex.rest > 0) {
      startRest(ex.rest);
    }
    unawaited(_persist());
    notifyListeners();
  }

  // ---------- تايمر الراحة ----------
  /// بيبدأ الراحة معتمد على "ديدلاين" (وقت نهاية فعلي) بدل عداد بينقص،
  /// عشان لو التطبيق راح الخلفية أو اتقفل، لما يرجع يحسب الوقت الصح
  /// من الفرق الحقيقي بين دلوقتي ووقت النهاية — مش من آخر رقم شافه.
  void startRest(int seconds) {
    _restTimer?.cancel();
    restTotal = seconds;
    _restDeadlineMs = DateTime.now().millisecondsSinceEpoch + seconds * 1000;
    restLeft.value = seconds;
    _tickRestLoop();
    unawaited(_persist());
    notifyListeners();
  }

  void _tickRestLoop() {
    _restTimer?.cancel();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_restDeadlineMs == null) {
        t.cancel();
        return;
      }
      final remaining =
          ((_restDeadlineMs! - DateTime.now().millisecondsSinceEpoch) / 1000)
              .ceil();
      restLeft.value = remaining;
      if (remaining == 3 && restTotal > 5) {
        Fx.restWarnVibe();
      }
      if (remaining <= 0) {
        t.cancel();
        _restDeadlineMs = null;
        restLeft.value = null;
        Fx.beep();
        Fx.restEndVibe();
        Fx.notify('⏱ خلصت الراحة', 'ابدأ المجموعة الجاية!');
        unawaited(_persist());
        notifyListeners();
      }
    });
  }

  void addRest(int seconds) {
    if (_restDeadlineMs == null) return;
    _restDeadlineMs = _restDeadlineMs! + seconds * 1000;
    restTotal += seconds;
    restLeft.value =
        ((_restDeadlineMs! - DateTime.now().millisecondsSinceEpoch) / 1000)
            .ceil();
    unawaited(_persist());
  }

  void skipRest() => _cancelRest();

  void _cancelRest() {
    _restTimer?.cancel();
    _restDeadlineMs = null;
    restLeft.value = null;
    unawaited(_persist());
    notifyListeners();
  }

  // ---------- إنهاء ----------
  void finish() {
    _workTimer?.cancel();
    _waterTimer?.cancel();
    _restTimer?.cancel();
    _restDeadlineMs = null;
    restLeft.value = null;
    session?.endedAt = DateTime.now().millisecondsSinceEpoch;
    Fx.keepScreenOn(false);
    unawaited(_persist());
    notifyListeners();
  }

  /// حفظ الجلسة + كشف الأرقام القياسية + الإنجازات الجديدة وترقية المستوى
  Future<SaveResult> save() async {
    final s = session!;
    final prs = Analytics.detectAndMarkPRs(s);

    // لقطة من الحالة قبل الحفظ عشان نقدر نقارن ونعرف إيه اللي اتفتح جديد
    final beforeSnapshot = GymDB.fromJson(store.db.toJson());
    final levelBefore = Gamification.currentLevel().level;

    await store.addSession(s);
    session = null;
    await _clearPersisted();

    final newAchievements = Gamification.newlyUnlocked(beforeSnapshot);
    final levelAfter = Gamification.currentLevel();
    final leveledUp = levelAfter.level > levelBefore;

    notifyListeners();
    return SaveResult(
      prs: prs,
      newAchievements: newAchievements,
      leveledUp: leveledUp,
      level: levelAfter,
    );
  }

  void abandon() {
    _workTimer?.cancel();
    _waterTimer?.cancel();
    _restTimer?.cancel();
    _restDeadlineMs = null;
    restLeft.value = null;
    session = null;
    Fx.keepScreenOn(false);
    unawaited(_clearPersisted());
    notifyListeners();
  }

  // ---------- الحفظ اللحظي ----------
  void _persistDebounced() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), () {
      unawaited(_persist());
    });
  }

  Future<void> _persist() async {
    if (session == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kActiveSessionKey,
        jsonEncode({
          'session': session!.toJson(),
          'restDeadline': _restDeadlineMs,
          'restTotal': restTotal,
          'savedAt': DateTime.now().millisecondsSinceEpoch,
        }),
      );
    } catch (e) {
      debugPrint('session persist error: $e');
    }
  }

  Future<void> _clearPersisted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kActiveSessionKey);
    } catch (e) {
      debugPrint('session clear error: $e');
    }
  }

  @override
  void dispose() {
    _workTimer?.cancel();
    _waterTimer?.cancel();
    _restTimer?.cancel();
    _saveDebounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

final sessionCtrl = SessionController();
