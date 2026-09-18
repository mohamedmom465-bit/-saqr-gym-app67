import 'dart:io';
import 'package:flutter/material.dart';

/// ملاحظة عامة: كل الكلاسات دي مطابقة لهيكل الـ DB اللي كان في نسخة الـ HTML،
/// عشان ملفات النسخ الاحتياطي القديمة (JSON) تتقرأ هنا من غير مشاكل.

double? _d(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  return double.tryParse(s);
}

int _i(dynamic v, int fallback) {
  if (v is num) return v.toInt();
  final s = v?.toString().trim() ?? '';
  return int.tryParse(s) ?? fallback;
}

/// تمرين داخل البرنامج (مش جلسة)
class ExerciseDef {
  String id;
  String name;
  int sets;
  String reps; // ممكن يكون "8-12" أو "10 دقائق"
  int rest; // ثواني
  bool plates; // محتاج تركيب أطباق
  bool core; // ضمن سيشن البطن
  bool cardio; // ضمن سيشن الكارديو
  bool isMain; // تمرين أساسي (يتحسبله 1RM في التقارير)
  bool noRestAfter; // سوبرست مع اللي بعده
  String? assetImage; // صورة مرجعية جاهزة جوه التطبيق
  String? filePath; // صورة رفعها المستخدم من الجهاز
  bool imageRemoved; // المستخدم شال الصورة بنفسه → متترجعش تلقائي

  ExerciseDef({
    required this.id,
    required this.name,
    this.sets = 3,
    this.reps = '10',
    this.rest = 60,
    this.plates = false,
    this.core = false,
    this.cardio = false,
    this.isMain = false,
    this.noRestAfter = false,
    this.assetImage,
    this.filePath,
    this.imageRemoved = false,
  });

  bool get hasImage => !imageRemoved && (filePath != null || assetImage != null);

  ImageProvider? get image {
    if (imageRemoved) return null;
    if (filePath != null && File(filePath!).existsSync()) {
      return FileImage(File(filePath!));
    }
    if (assetImage != null) return AssetImage(assetImage!);
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sets': sets,
        'reps': reps,
        'rest': rest,
        'plates': plates,
        'core': core,
        'cardio': cardio,
        'isMain': isMain,
        'noRestAfter': noRestAfter,
        'assetImage': assetImage,
        'filePath': filePath,
        'imageRemoved': imageRemoved,
      };

  factory ExerciseDef.fromJson(Map<String, dynamic> j) => ExerciseDef(
        id: j['id'].toString(),
        name: j['name']?.toString() ?? 'تمرين',
        sets: _i(j['sets'], 3),
        reps: j['reps']?.toString() ?? '10',
        rest: _i(j['rest'], 60),
        plates: j['plates'] == true,
        core: j['core'] == true,
        cardio: j['cardio'] == true,
        isMain: j['isMain'] == true,
        noRestAfter: j['noRestAfter'] == true,
        assetImage: j['assetImage']?.toString(),
        filePath: j['filePath']?.toString(),
        imageRemoved: j['imageRemoved'] == true,
      );
}

class WorkoutDay {
  String id;
  String name;
  List<ExerciseDef> exercises;

  WorkoutDay({required this.id, required this.name, List<ExerciseDef>? exercises})
      : exercises = exercises ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };

  factory WorkoutDay.fromJson(Map<String, dynamic> j) => WorkoutDay(
        id: j['id'].toString(),
        name: j['name']?.toString() ?? 'يوم',
        exercises: ((j['exercises'] as List?) ?? [])
            .map((e) => ExerciseDef.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

/// مجموعة واحدة متسجلة جوه جلسة
class LoggedSet {
  String weight; // نص عشان نفرق بين "فاضي" و 0
  String reps;
  bool done;
  String note;
  bool isDrop;

  LoggedSet({
    this.weight = '',
    this.reps = '',
    this.done = false,
    this.note = '',
    this.isDrop = false,
  });

  double get weightNum => double.tryParse(weight.trim()) ?? 0;
  double get repsNum => double.tryParse(reps.trim()) ?? 0;
  bool get hasWeight => weight.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'weight': weight,
        'reps': reps,
        'done': done,
        'note': note,
        'isDrop': isDrop,
      };

  factory LoggedSet.fromJson(Map<String, dynamic> j) => LoggedSet(
        weight: j['weight']?.toString() ?? '',
        reps: j['reps']?.toString() ?? '',
        done: j['done'] == true,
        note: j['note']?.toString() ?? '',
        isDrop: j['isDrop'] == true,
      );
}

class SessionExercise {
  /// SQLite row id for the session-exercise parent row. Zero means not yet persisted.
  int rowId;
  String exerciseId;
  String name;
  int targetSets;
  String targetReps;
  int rest;
  bool core;
  bool cardio;
  bool noRestAfter;
  bool prefilled;
  bool autoBumped;
  bool deloadSuggested;
  bool swapped;
  bool isPR;
  int unlockedSetCount; // القفل التصاعدي: بيزيد بس وما بيرجعش
  List<LoggedSet> loggedSets;

  SessionExercise({
    this.rowId = 0,
    required this.exerciseId,
    required this.name,
    required this.targetSets,
    required this.targetReps,
    required this.rest,
    this.core = false,
    this.cardio = false,
    this.noRestAfter = false,
    this.prefilled = false,
    this.autoBumped = false,
    this.deloadSuggested = false,
    this.swapped = false,
    this.isPR = false,
    this.unlockedSetCount = 1,
    List<LoggedSet>? loggedSets,
  }) : loggedSets = loggedSets ?? [];

  Map<String, dynamic> toJson() => {
        'rowId': rowId,
        'exerciseId': exerciseId,
        'name': name,
        'targetSets': targetSets,
        'targetReps': targetReps,
        'rest': rest,
        'core': core,
        'cardio': cardio,
        'noRestAfter': noRestAfter,
        'prefilled': prefilled,
        'autoBumped': autoBumped,
        'deloadSuggested': deloadSuggested,
        'swapped': swapped,
        'isPR': isPR,
        'unlockedSetCount': unlockedSetCount,
        'loggedSets': loggedSets.map((s) => s.toJson()).toList(),
      };

  factory SessionExercise.fromJson(Map<String, dynamic> j) => SessionExercise(
        rowId: _i(j['rowId'], 0),
        exerciseId: j['exerciseId'].toString(),
        name: j['name']?.toString() ?? '',
        targetSets: _i(j['targetSets'], 3),
        targetReps: j['targetReps']?.toString() ?? '',
        rest: _i(j['rest'], 60),
        core: j['core'] == true,
        cardio: j['cardio'] == true,
        noRestAfter: j['noRestAfter'] == true,
        prefilled: j['prefilled'] == true,
        autoBumped: j['autoBumped'] == true,
        deloadSuggested: j['deloadSuggested'] == true,
        swapped: j['swapped'] == true,
        isPR: j['isPR'] == true,
        unlockedSetCount: _i(j['unlockedSetCount'], 1),
        loggedSets: ((j['loggedSets'] as List?) ?? [])
            .map((s) => LoggedSet.fromJson(Map<String, dynamic>.from(s)))
            .toList(),
      );
}

class WorkoutSession {
  String id;
  String dayId;
  String dayName;
  DateTime date;
  int startedAt; // ms
  int? endedAt;
  int unlockedExerciseCount;
  List<SessionExercise> exercises;
  int? rating; // 1..10
  Map<String, int> exerciseRatings;
  String notes;

  WorkoutSession({
    required this.id,
    required this.dayId,
    required this.dayName,
    required this.date,
    required this.startedAt,
    this.endedAt,
    this.unlockedExerciseCount = 1,
    List<SessionExercise>? exercises,
    this.rating,
    Map<String, int>? exerciseRatings,
    this.notes = '',
  })  : exercises = exercises ?? [],
        exerciseRatings = exerciseRatings ?? {};

  int get durationMinutes => (endedAt == null)
      ? 0
      : ((endedAt! - startedAt) / 60000).round();

  /// جلسة Quick-log من الإشعار: تسجيل مُصرّح به من المستخدم لكنه غير موثّق
  /// كجلسة فعلية، لذلك يُفصل عن مؤشرات الأداء والأرقام القياسية.
  bool get isQuickLog => notes.trim() == 'تسجيل سريع من إشعار التذكير 🔔';

  Map<String, dynamic> toJson() => {
        'id': id,
        'dayId': dayId,
        'dayName': dayName,
        'date': date.toIso8601String(),
        'startedAt': startedAt,
        'endedAt': endedAt,
        'unlockedExerciseCount': unlockedExerciseCount,
        'exercises': exercises.map((e) => e.toJson()).toList(),
        'rating': rating,
        'exerciseRatings': exerciseRatings,
        'notes': notes,
      };

  factory WorkoutSession.fromJson(Map<String, dynamic> j) {
    final ratings = <String, int>{};
    final raw = j['exerciseRatings'];
    if (raw is Map) {
      raw.forEach((k, v) {
        final n = _i(v, 0);
        if (n > 0) ratings[k.toString()] = n;
      });
    }
    return WorkoutSession(
      id: j['id'].toString(),
      dayId: j['dayId']?.toString() ?? '',
      dayName: j['dayName']?.toString() ?? '',
      date: DateTime.tryParse(j['date']?.toString() ?? '') ?? DateTime.now(),
      startedAt: _i(j['startedAt'], 0),
      endedAt: j['endedAt'] == null ? null : _i(j['endedAt'], 0),
      unlockedExerciseCount: _i(j['unlockedExerciseCount'], 1),
      exercises: ((j['exercises'] as List?) ?? [])
          .map((e) => SessionExercise.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      rating: j['rating'] == null ? null : _i(j['rating'], 0),
      exerciseRatings: ratings,
      notes: j['notes']?.toString() ?? '',
    );
  }
}

class InBodyEntry {
  String id;
  DateTime date;
  double? weight, fat, muscle, arm, chest, waist, thigh;
  String notes;

  InBodyEntry({
    required this.id,
    required this.date,
    this.weight,
    this.fat,
    this.muscle,
    this.arm,
    this.chest,
    this.waist,
    this.thigh,
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'weight': weight,
        'fat': fat,
        'muscle': muscle,
        'arm': arm,
        'chest': chest,
        'waist': waist,
        'thigh': thigh,
        'notes': notes,
      };

  factory InBodyEntry.fromJson(Map<String, dynamic> j) => InBodyEntry(
        id: j['id'].toString(),
        date: DateTime.tryParse(j['date']?.toString() ?? '') ?? DateTime.now(),
        weight: _d(j['weight']),
        fat: _d(j['fat']),
        muscle: _d(j['muscle']),
        arm: _d(j['arm']),
        chest: _d(j['chest']),
        waist: _d(j['waist']),
        thigh: _d(j['thigh']),
        notes: j['notes']?.toString() ?? '',
      );
}

/// صورة تقدم — بتتخزن كملف جوه فولدر التطبيق (مش base64) عشان تفضل خفيفة
class ProgressPhoto {
  String id;
  DateTime date;
  String path;

  ProgressPhoto({required this.id, required this.date, required this.path});

  Map<String, dynamic> toJson() =>
      {'id': id, 'date': date.toIso8601String(), 'path': path};

  factory ProgressPhoto.fromJson(Map<String, dynamic> j) => ProgressPhoto(
        id: j['id'].toString(),
        date: DateTime.tryParse(j['date']?.toString() ?? '') ?? DateTime.now(),
        path: j['path']?.toString() ?? '',
      );
}

class AppSettings {
  int waterIntervalMin;
  int transitionSeconds;
  bool soundEnabled;
  bool vibrationEnabled;
  bool alertsEnabled; // تنبيهات داخل التطبيق
  bool keepScreenOn;
  double barWeight;
  bool autoProgress;

  // دفعة 9 — #18/#40 Push Notifications + Workout Reminder
  bool reminderEnabled; // تذكير يومي بميعاد التمرين (إشعار نظام حقيقي)
  int reminderHour; // 0-23
  int reminderMinute; // 0-59
  bool reminderQuickLogEnabled; // إظهار زرار "سجّلت النهارده" جوه الإشعار

  // دفعة 9 — #43 Calories Estimate
  double fallbackBodyWeightKg; // يُستخدم لو مفيش قياس InBody متسجل خالص

  AppSettings({
    this.waterIntervalMin = 20,
    this.transitionSeconds = 45,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.alertsEnabled = true,
    this.keepScreenOn = true,
    this.barWeight = 20,
    this.autoProgress = true,
    this.reminderEnabled = false,
    this.reminderHour = 18,
    this.reminderMinute = 0,
    this.reminderQuickLogEnabled = true,
    this.fallbackBodyWeightKg = 75,
  });

  Map<String, dynamic> toJson() => {
        'waterIntervalMin': waterIntervalMin,
        'transitionSeconds': transitionSeconds,
        'soundEnabled': soundEnabled,
        'vibrationEnabled': vibrationEnabled,
        'alertsEnabled': alertsEnabled,
        'keepScreenOn': keepScreenOn,
        'barWeight': barWeight,
        'autoProgress': autoProgress,
        'reminderEnabled': reminderEnabled,
        'reminderHour': reminderHour,
        'reminderMinute': reminderMinute,
        'reminderQuickLogEnabled': reminderQuickLogEnabled,
        'fallbackBodyWeightKg': fallbackBodyWeightKg,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        waterIntervalMin: _i(j['waterIntervalMin'], 20),
        transitionSeconds: _i(j['transitionSeconds'], 45),
        soundEnabled: j['soundEnabled'] != false,
        vibrationEnabled: j['vibrationEnabled'] != false,
        alertsEnabled: (j['alertsEnabled'] ?? j['notifyEnabled']) != false,
        keepScreenOn: j['keepScreenOn'] != false,
        barWeight: _d(j['barWeight']) ?? 20,
        autoProgress: j['autoProgress'] != false,
        reminderEnabled: j['reminderEnabled'] == true,
        reminderHour: _i(j['reminderHour'], 18).clamp(0, 23),
        reminderMinute: _i(j['reminderMinute'], 0).clamp(0, 59),
        reminderQuickLogEnabled: j['reminderQuickLogEnabled'] != false,
        fallbackBodyWeightKg: _d(j['fallbackBodyWeightKg']) ?? 75,
      );
}

/// قاعدة البيانات كلها
class GymDB {
  List<WorkoutDay> days;
  List<WorkoutSession> sessions;
  List<InBodyEntry> inbody;
  List<ProgressPhoto> photos;
  AppSettings settings;

  GymDB({
    required this.days,
    required this.sessions,
    required this.inbody,
    required this.photos,
    required this.settings,
  });

  Map<String, dynamic> toJson() => {
        'days': days.map((d) => d.toJson()).toList(),
        'sessions': sessions.map((s) => s.toJson()).toList(),
        'inbody': inbody.map((e) => e.toJson()).toList(),
        'photos': photos.map((p) => p.toJson()).toList(),
        'settings': settings.toJson(),
      };

  factory GymDB.fromJson(Map<String, dynamic> j) => GymDB(
        days: ((j['days'] as List?) ?? [])
            .map((d) => WorkoutDay.fromJson(Map<String, dynamic>.from(d)))
            .toList(),
        sessions: ((j['sessions'] as List?) ?? [])
            .map((s) => WorkoutSession.fromJson(Map<String, dynamic>.from(s)))
            .toList(),
        inbody: ((j['inbody'] as List?) ?? [])
            .map((e) => InBodyEntry.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        photos: ((j['photos'] as List?) ?? [])
            .map((p) => ProgressPhoto.fromJson(Map<String, dynamic>.from(p)))
            .toList(),
        settings: AppSettings.fromJson(
            Map<String, dynamic>.from(j['settings'] ?? const {})),
      );
}
