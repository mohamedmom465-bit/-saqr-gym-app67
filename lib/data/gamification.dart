import 'analytics.dart';
import 'models.dart';
import 'store.dart';

/// دفعة 7 — #19 Levels/Badges و #20 Achievements
///
/// كل حاجة هنا بتتحسب لحظيًا من بيانات المستخدم الموجودة بالفعل
/// (الجلسات، الـ InBody، الصور...) من غير ما نضيف أي حقل جديد في الـ DB
/// أو أي Migration — المستوى والإنجازات نتيجة طبيعية للبيانات مش حالة
/// منفصلة ممكن تتفرق عن الواقع.

class LevelInfo {
  final int level;
  final String title;
  final int xp;
  final int xpIntoLevel;
  final int xpForNextLevel;
  final double progress; // 0..1 لحد المستوى الجاي
  LevelInfo({
    required this.level,
    required this.title,
    required this.xp,
    required this.xpIntoLevel,
    required this.xpForNextLevel,
    required this.progress,
  });
}

class Achievement {
  final String id;
  final String emoji;
  final String title;
  final String description;
  final bool Function(GymDB db) isUnlocked;

  /// نص تقدّم اختياري زي "7 / 10" — بيتحسب بس لو مش مفتوح لسه
  final String Function(GymDB db)? progressText;

  const Achievement({
    required this.id,
    required this.emoji,
    required this.title,
    required this.description,
    required this.isUnlocked,
    this.progressText,
  });
}

class Gamification {
  static List<WorkoutSession> _realSessions(GymDB db) =>
      db.sessions.where((s) => !s.isQuickLog).toList();


  static GymDB get _db => store.db;
  static int? _cachedXp;
  static LevelInfo? _cachedLevel;
  static List<Achievement>? _cachedUnlocked;
  static List<Achievement>? _cachedLocked;

  /// التخزين المؤقت يمنع إعادة المرور على كل تاريخ الجلسات في كل rebuild.
  /// Store.invalidate() يناديها بعد أي حفظ يغيّر البيانات.
  static void invalidate() {
    _cachedXp = null;
    _cachedLevel = null;
    _cachedUnlocked = null;
    _cachedLocked = null;
  }

  // ---------- #19 Levels ----------

  static const _titles = [
    'مبتدئ', // 1
    'مجتهد', // 2
    'منتظم', // 3
    'ملتزم', // 4
    'قوي', // 5
    'متمرّس', // 6
    'محارب', // 7
    'وحش الحديد', // 8
    'بطل', // 9
    'أسطورة', // 10
  ];

  /// نقاط الخبرة = مجموع حجم كل الجلسات (وزن × عدات) / 100 + مكافأة لكل
  /// جلسة كاملة + مكافأة لكل رقم قياسي — عشان الاستمرارية والقوة الاتنين
  /// يبقى ليهم وزن، مش بس رقم واحد.
  static int totalXp() {
    final cached = _cachedXp;
    if (cached != null) return cached;
    var xp = 0;
    for (final s in _realSessions(_db)) {
      xp += (Analytics.sessionVolume(s) / 100).round();
      xp += 15; // مكافأة إكمال جلسة
      xp += s.exercises.where((e) => e.isPR).length * 40;
    }
    _cachedXp = xp;
    return xp;
  }

  /// عتبة تراكمية للمستوى n — بتزيد تصاعديًا (كل مستوى محتاج مجهود أكبر
  /// من اللي قبله) عن طريق متتالية تربيعية بسيطة.
  static int _xpThreshold(int level) => 150 * level * level;

  static LevelInfo currentLevel() {
    final cached = _cachedLevel;
    if (cached != null) return cached;
    final xp = totalXp();
    var level = 1;
    while (_xpThreshold(level + 1) <= xp && level < 60) {
      level++;
    }
    final base = _xpThreshold(level);
    final next = _xpThreshold(level + 1);
    final title = level <= _titles.length ? _titles[level - 1] : 'أسطورة×${level - _titles.length}';
    final span = (next - base).clamp(1, 1 << 30);
    final info = LevelInfo(
      level: level,
      title: title,
      xp: xp,
      xpIntoLevel: xp - base,
      xpForNextLevel: span,
      progress: ((xp - base) / span).clamp(0.0, 1.0),
    );
    _cachedLevel = info;
    return info;
  }

  // ---------- #20 Achievements ----------

  static int _totalPRs(GymDB db) =>
      _realSessions(db).fold(0, (a, s) => a + s.exercises.where((e) => e.isPR).length);

  static int _totalVolume(GymDB db) =>
      _realSessions(db).fold(0, (a, s) => a + Analytics.sessionVolume(s));

  static int _coreSessions(GymDB db) =>
      _realSessions(db).where((s) => s.exercises.any((e) => e.core)).length;

  static int _cardioSessions(GymDB db) =>
      _realSessions(db).where((s) => s.exercises.any((e) => e.cardio)).length;

  /// نفس منطق Analytics.computeStreak() بالظبط، بس بياخد أي GymDB كباراميتر
  /// بدل ما يعتمد على store.db العالمي — محتاجينها هنا عشان نقدر نحسب
  /// الستريك على "لقطة قبل الحفظ" مش بس الحالة الحالية، وإلا مستحيل نعرف
  /// إن إنجاز الستريك اتفتح جديد بالظبط في الجلسة دي.
  static int _streakFor(GymDB db) {
    if (_realSessions(db).isEmpty) return 0;
    final days = _realSessions(db)
        .map((s) => DateTime(s.date.year, s.date.month, s.date.day))
        .toSet();
    var cursor = DateTime.now();
    cursor = DateTime(cursor.year, cursor.month, cursor.day);
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

  static final List<Achievement> all = [
    Achievement(
      id: 'first_session',
      emoji: '🥇',
      title: 'أول خطوة',
      description: 'سجّلت أول تمرين ليك',
      isUnlocked: (db) => _realSessions(db).isNotEmpty,
    ),
    Achievement(
      id: 'sessions_10',
      emoji: '📅',
      title: 'روتين بيتبني',
      description: '10 جلسات تمرين',
      isUnlocked: (db) => _realSessions(db).length >= 10,
      progressText: (db) => '${_realSessions(db).length} / 10',
    ),
    Achievement(
      id: 'sessions_50',
      emoji: '📆',
      title: 'نص المية',
      description: '50 جلسة تمرين',
      isUnlocked: (db) => _realSessions(db).length >= 50,
      progressText: (db) => '${_realSessions(db).length} / 50',
    ),
    Achievement(
      id: 'sessions_100',
      emoji: '🗓️',
      title: 'مية جلسة',
      description: '100 جلسة تمرين — استمرارية حقيقية',
      isUnlocked: (db) => _realSessions(db).length >= 100,
      progressText: (db) => '${_realSessions(db).length} / 100',
    ),
    Achievement(
      id: 'streak_7',
      emoji: '🔥',
      title: 'أسبوع نار',
      description: '7 أيام متتالية',
      isUnlocked: (db) => _streakFor(db) >= 7,
      progressText: (db) => '${_streakFor(db)} / 7',
    ),
    Achievement(
      id: 'streak_30',
      emoji: '🔥🔥',
      title: 'شهر كامل نار',
      description: '30 يوم متتالي',
      isUnlocked: (db) => _streakFor(db) >= 30,
      progressText: (db) => '${_streakFor(db)} / 30',
    ),
    Achievement(
      id: 'first_pr',
      emoji: '🏆',
      title: 'أول رقم قياسي',
      description: 'كسرت رقمك القياسي في تمرين لأول مرة',
      isUnlocked: (db) => _totalPRs(db) >= 1,
    ),
    Achievement(
      id: 'pr_10',
      emoji: '🏆🏆',
      title: 'صياد الأرقام',
      description: '10 أرقام قياسية إجمالي',
      isUnlocked: (db) => _totalPRs(db) >= 10,
      progressText: (db) => '${_totalPRs(db)} / 10',
    ),
    Achievement(
      id: 'volume_100k',
      emoji: '🏋️',
      title: '100 طن',
      description: '100,000 كجم حجم تمرين تراكمي',
      isUnlocked: (db) => _totalVolume(db) >= 100000,
      progressText: (db) => '${(_totalVolume(db) / 1000).toStringAsFixed(0)} / 100 طن',
    ),
    Achievement(
      id: 'volume_500k',
      emoji: '🏋️‍♂️',
      title: 'نص مليون كيلو',
      description: '500,000 كجم حجم تمرين تراكمي',
      isUnlocked: (db) => _totalVolume(db) >= 500000,
      progressText: (db) => '${(_totalVolume(db) / 1000).toStringAsFixed(0)} / 500 طن',
    ),
    Achievement(
      id: 'core_10',
      emoji: '🔥',
      title: 'بطن حديد',
      description: '10 سيشن بطن',
      isUnlocked: (db) => _coreSessions(db) >= 10,
      progressText: (db) => '${_coreSessions(db)} / 10',
    ),
    Achievement(
      id: 'cardio_10',
      emoji: '🚴',
      title: 'قلب رياضي',
      description: '10 سيشن كارديو',
      isUnlocked: (db) => _cardioSessions(db) >= 10,
      progressText: (db) => '${_cardioSessions(db)} / 10',
    ),
    Achievement(
      id: 'inbody_5',
      emoji: '🧬',
      title: 'متابع جاد',
      description: '5 قياسات InBody',
      isUnlocked: (db) => db.inbody.length >= 5,
      progressText: (db) => '${db.inbody.length} / 5',
    ),
    Achievement(
      id: 'photos_2',
      emoji: '📸',
      title: 'قبل / بعد',
      description: 'صورتين تقدّم عشان تقارن',
      isUnlocked: (db) => db.photos.length >= 2,
      progressText: (db) => '${db.photos.length} / 2',
    ),
  ];

  static List<Achievement> unlocked() {
    final cached = _cachedUnlocked;
    if (cached != null) return cached;
    final value = all.where((a) => a.isUnlocked(_db)).toList(growable: false);
    _cachedUnlocked = value;
    return value;
  }

  static List<Achievement> locked() {
    final cached = _cachedLocked;
    if (cached != null) return cached;
    final value = all.where((a) => !a.isUnlocked(_db)).toList(growable: false);
    _cachedLocked = value;
    return value;
  }

  /// بيتنادى بعد ما جلسة تتحفظ — بيرجّع أي إنجاز جديد اتفتح النهارده
  /// بالظبط (مقارنة قبل/بعد الحفظ)، عشان نقدر نحتفل بيه فورًا.
  static List<Achievement> newlyUnlocked(GymDB before) {
    final beforeUnlocked = all.where((a) => a.isUnlocked(before)).map((a) => a.id).toSet();
    return all
        .where((a) => !beforeUnlocked.contains(a.id) && a.isUnlocked(_db))
        .toList();
  }
}
