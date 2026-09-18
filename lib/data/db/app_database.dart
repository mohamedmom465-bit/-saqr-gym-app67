import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import '../models.dart';

part 'app_database.g.dart';

/// دفعة 10 — الهيكلة: قاعدة بيانات SQLite حقيقية (بدل الـ JSON الواحد اللي كان
/// متخزن كامل جوه SharedPreferences). كل جدول هنا مطابق لكلاس في models.dart.
///
/// ملاحظة تصميم: الشاشات ما زالت تعدّل GymDB في الميموري ثم تنادي save(),
/// لكن SQLite هنا بتعمل مزامنة تفاضلية: تكتب فقط الصفوف التي تغيّرت، وتحذف
/// فقط ما حذفه هذا الـisolate منذ آخر load/save. هذا يحافظ على API القديم
/// ويمنع كل تعديل صغير من إعادة بناء تاريخ التمرين بالكامل.
class Days extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class Exercises extends Table {
  TextColumn get id => text()();
  TextColumn get dayId => text()();
  TextColumn get name => text()();
  IntColumn get sets => integer().withDefault(const Constant(3))();
  TextColumn get reps => text().withDefault(const Constant('10'))();
  IntColumn get rest => integer().withDefault(const Constant(60))();
  BoolColumn get plates => boolean().withDefault(const Constant(false))();
  BoolColumn get core => boolean().withDefault(const Constant(false))();
  BoolColumn get cardio => boolean().withDefault(const Constant(false))();
  BoolColumn get isMain => boolean().withDefault(const Constant(false))();
  BoolColumn get noRestAfter => boolean().withDefault(const Constant(false))();
  TextColumn get assetImage => text().nullable()();
  TextColumn get filePath => text().nullable()();
  BoolColumn get imageRemoved => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class Sessions extends Table {
  TextColumn get id => text()();
  TextColumn get dayId => text()();
  TextColumn get dayName => text()();
  DateTimeColumn get date => dateTime()();
  IntColumn get startedAt => integer().withDefault(const Constant(0))();
  IntColumn get endedAt => integer().nullable()();
  IntColumn get unlockedExerciseCount => integer().withDefault(const Constant(1))();
  IntColumn get rating => integer().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SessionExerciseRow')
class SessionExercises extends Table {
  IntColumn get rowId => integer().autoIncrement()();
  TextColumn get sessionId => text()();
  TextColumn get exerciseId => text()();
  TextColumn get name => text()();
  IntColumn get targetSets => integer().withDefault(const Constant(3))();
  TextColumn get targetReps => text().withDefault(const Constant(''))();
  IntColumn get rest => integer().withDefault(const Constant(60))();
  BoolColumn get core => boolean().withDefault(const Constant(false))();
  BoolColumn get cardio => boolean().withDefault(const Constant(false))();
  BoolColumn get noRestAfter => boolean().withDefault(const Constant(false))();
  BoolColumn get prefilled => boolean().withDefault(const Constant(false))();
  BoolColumn get autoBumped => boolean().withDefault(const Constant(false))();
  BoolColumn get deloadSuggested => boolean().withDefault(const Constant(false))();
  BoolColumn get swapped => boolean().withDefault(const Constant(false))();
  BoolColumn get isPR => boolean().withDefault(const Constant(false))();
  IntColumn get unlockedSetCount => integer().withDefault(const Constant(1))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

@DataClassName('LoggedSetRow')
class LoggedSets extends Table {
  IntColumn get rowId => integer().autoIncrement()();
  IntColumn get sessionExerciseRowId => integer()();
  TextColumn get weight => text().withDefault(const Constant(''))();
  TextColumn get reps => text().withDefault(const Constant(''))();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  TextColumn get note => text().withDefault(const Constant(''))();
  BoolColumn get isDrop => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

class ExerciseRatings extends Table {
  TextColumn get sessionId => text()();
  TextColumn get exerciseId => text()();
  IntColumn get rating => integer()();

  @override
  Set<Column> get primaryKey => {sessionId, exerciseId};
}

class InbodyEntries extends Table {
  TextColumn get id => text()();
  DateTimeColumn get date => dateTime()();
  RealColumn get weight => real().nullable()();
  RealColumn get fat => real().nullable()();
  RealColumn get muscle => real().nullable()();
  RealColumn get arm => real().nullable()();
  RealColumn get chest => real().nullable()();
  RealColumn get waist => real().nullable()();
  RealColumn get thigh => real().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ProgressPhotoRow')
class ProgressPhotos extends Table {
  TextColumn get id => text()();
  DateTimeColumn get date => dateTime()();
  TextColumn get path => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class AppSettingsRow extends Table {
  IntColumn get id => integer().withDefault(const Constant(0))();
  IntColumn get waterIntervalMin => integer().withDefault(const Constant(20))();
  IntColumn get transitionSeconds => integer().withDefault(const Constant(45))();
  BoolColumn get soundEnabled => boolean().withDefault(const Constant(true))();
  BoolColumn get vibrationEnabled => boolean().withDefault(const Constant(true))();
  BoolColumn get alertsEnabled => boolean().withDefault(const Constant(true))();
  BoolColumn get keepScreenOn => boolean().withDefault(const Constant(true))();
  RealColumn get barWeight => real().withDefault(const Constant(20))();
  BoolColumn get autoProgress => boolean().withDefault(const Constant(true))();
  // دفعة 9 — أعمدة جديدة (schemaVersion 2): تذكير التمرين + استقلاب السعرات
  BoolColumn get reminderEnabled => boolean().withDefault(const Constant(false))();
  IntColumn get reminderHour => integer().withDefault(const Constant(18))();
  IntColumn get reminderMinute => integer().withDefault(const Constant(0))();
  BoolColumn get reminderQuickLogEnabled =>
      boolean().withDefault(const Constant(true))();
  RealColumn get fallbackBodyWeightKg => real().withDefault(const Constant(75))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [
  Days,
  Exercises,
  Sessions,
  SessionExercises,
  LoggedSets,
  ExerciseRatings,
  InbodyEntries,
  ProgressPhotos,
  AppSettingsRow,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// المسار الفعلي لملف SQLite. نستخدمه للنسخ المحلية فقط، وليس للكتابة
  /// المباشرة أثناء فتح قاعدة البيانات.
  static Future<File> databaseFile() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    return File(p.join(dbFolder.path, 'saqr_gym.sqlite'));
  }

  /// تأكيد كتابة صفحات SQLite إلى الملف قبل أخذ snapshot.
  Future<void> checkpoint() async {
    await customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
  }

  @override
  int get schemaVersion => 2;

  /// دفعة 9: ترقية من نسخة 1 (قبل التذكير/السعرات) لنسخة 2 من غير ما نفقد
  /// أي بيانات — بنضيف الأعمدة الجديدة بس بقيمها الافتراضية.
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(appSettingsRow, appSettingsRow.reminderEnabled);
            await m.addColumn(appSettingsRow, appSettingsRow.reminderHour);
            await m.addColumn(appSettingsRow, appSettingsRow.reminderMinute);
            await m.addColumn(
                appSettingsRow, appSettingsRow.reminderQuickLogEnabled);
            await m.addColumn(
                appSettingsRow, appSettingsRow.fallbackBodyWeightKg);
          }
        },
      );

  /// هل قاعدة البيانات فيها بيانات أصلًا؟ (بنستخدمها عشان نعرف نستورد
  /// من النسخة القديمة (SharedPreferences JSON) ولا لأ)
  Future<bool> hasAnyData() async {
    // لا نعتمد على جدول days وحده: قاعدة قديمة/مستوردة قد تحتوي جلسات
    // بينما جدول الأيام فارغ. في هذه الحالة يجب ألا نعتبرها "فارغة"
    // ونستبدلها ببيانات SharedPreferences أو defaultDB.
    final dayRows = await (select(days)..limit(1)).get();
    if (dayRows.isNotEmpty) return true;

    final sessionRows = await (select(sessions)..limit(1)).get();
    return sessionRows.isNotEmpty;
  }

  Future<GymDB> loadAll() async {
    final dayRows = await (select(days)
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    final workoutDays = <WorkoutDay>[];
    for (final d in dayRows) {
      final exRows = await (select(exercises)
            ..where((t) => t.dayId.equals(d.id))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();
      workoutDays.add(WorkoutDay(
        id: d.id,
        name: d.name,
        exercises: exRows
            .map((e) => ExerciseDef(
                  id: e.id,
                  name: e.name,
                  sets: e.sets,
                  reps: e.reps,
                  rest: e.rest,
                  plates: e.plates,
                  core: e.core,
                  cardio: e.cardio,
                  isMain: e.isMain,
                  noRestAfter: e.noRestAfter,
                  assetImage: e.assetImage,
                  filePath: e.filePath,
                  imageRemoved: e.imageRemoved,
                ))
            .toList(),
      ));
    }

    final sessionRows = await (select(sessions)
          ..orderBy([(t) => OrderingTerm.asc(t.startedAt)]))
        .get();
    final workoutSessions = <WorkoutSession>[];
    for (final s in sessionRows) {
      final sexRows = await (select(sessionExercises)
            ..where((t) => t.sessionId.equals(s.id))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();
      final sessionExList = <SessionExercise>[];
      for (final se in sexRows) {
        final setRows = await (select(loggedSets)
              ..where((t) => t.sessionExerciseRowId.equals(se.rowId))
              ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
            .get();
        sessionExList.add(SessionExercise(
          rowId: se.rowId,
          exerciseId: se.exerciseId,
          name: se.name,
          targetSets: se.targetSets,
          targetReps: se.targetReps,
          rest: se.rest,
          core: se.core,
          cardio: se.cardio,
          noRestAfter: se.noRestAfter,
          prefilled: se.prefilled,
          autoBumped: se.autoBumped,
          deloadSuggested: se.deloadSuggested,
          swapped: se.swapped,
          isPR: se.isPR,
          unlockedSetCount: se.unlockedSetCount,
          loggedSets: setRows
              .map((ls) => LoggedSet(
                    weight: ls.weight,
                    reps: ls.reps,
                    done: ls.done,
                    note: ls.note,
                    isDrop: ls.isDrop,
                  ))
              .toList(),
        ));
      }

      final ratingRows = await (select(exerciseRatings)
            ..where((t) => t.sessionId.equals(s.id)))
          .get();
      final ratingsMap = <String, int>{
        for (final r in ratingRows) r.exerciseId: r.rating,
      };

      workoutSessions.add(WorkoutSession(
        id: s.id,
        dayId: s.dayId,
        dayName: s.dayName,
        date: s.date,
        startedAt: s.startedAt,
        endedAt: s.endedAt,
        unlockedExerciseCount: s.unlockedExerciseCount,
        exercises: sessionExList,
        rating: s.rating,
        exerciseRatings: ratingsMap,
        notes: s.notes,
      ));
    }

    final inbodyRows = await (select(inbodyEntries)
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .get();
    final inbodyList = inbodyRows
        .map((e) => InBodyEntry(
              id: e.id,
              date: e.date,
              weight: e.weight,
              fat: e.fat,
              muscle: e.muscle,
              arm: e.arm,
              chest: e.chest,
              waist: e.waist,
              thigh: e.thigh,
              notes: e.notes,
            ))
        .toList();

    final photoRows = await (select(progressPhotos)
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .get();
    final photoList = photoRows
        .map((p0) => ProgressPhoto(id: p0.id, date: p0.date, path: p0.path))
        .toList();

    final settingsRows = await (select(appSettingsRow)..limit(1)).get();
    final settings = settingsRows.isEmpty
        ? AppSettings()
        : AppSettings(
            waterIntervalMin: settingsRows.first.waterIntervalMin,
            transitionSeconds: settingsRows.first.transitionSeconds,
            soundEnabled: settingsRows.first.soundEnabled,
            vibrationEnabled: settingsRows.first.vibrationEnabled,
            alertsEnabled: settingsRows.first.alertsEnabled,
            keepScreenOn: settingsRows.first.keepScreenOn,
            barWeight: settingsRows.first.barWeight,
            autoProgress: settingsRows.first.autoProgress,
            reminderEnabled: settingsRows.first.reminderEnabled,
            reminderHour: settingsRows.first.reminderHour,
            reminderMinute: settingsRows.first.reminderMinute,
            reminderQuickLogEnabled:
                settingsRows.first.reminderQuickLogEnabled,
            fallbackBodyWeightKg: settingsRows.first.fallbackBodyWeightKg,
          );

    final result = GymDB(
      days: workoutDays,
      sessions: workoutSessions,
      inbody: inbodyList,
      photos: photoList,
      settings: settings,
    );
    _captureSnapshots(result);
    return result;
  }

  // Snapshots of the last state observed by this isolate. They let saveAll()
  // detect real changes and, importantly, avoid deleting rows that another
  // isolate/process may have added since this isolate last loaded the DB.
  Map<String, String> _daySnapshots = {};
  Map<String, String> _exerciseSnapshots = {};
  Map<String, String> _sessionSnapshots = {};
  Map<String, String> _inbodySnapshots = {};
  Map<String, String> _photoSnapshots = {};
  String _settingsSnapshot = '';

  String _encode(Object value) => jsonEncode(value);

  String _daySnapshot(WorkoutDay d, int sortOrder) => _encode({
        'id': d.id,
        'name': d.name,
        'sortOrder': sortOrder,
      });

  String _exerciseSnapshot(ExerciseDef e, int sortOrder) => _encode({
        ...e.toJson(),
        'sortOrder': sortOrder,
      });

  String _settingsSnapshotOf(AppSettings s) => _encode(s.toJson());

  String _inbodySnapshot(InBodyEntry e) => _encode(e.toJson());

  String _photoSnapshot(ProgressPhoto p) => _encode(p.toJson());

  String _sessionSnapshot(WorkoutSession s) => _encode(s.toJson());

  void _captureSnapshots(GymDB db) {
    _daySnapshots = {
      for (var i = 0; i < db.days.length; i++)
        db.days[i].id: _daySnapshot(db.days[i], i),
    };
    _exerciseSnapshots = {
      for (final d in db.days)
        for (var i = 0; i < d.exercises.length; i++)
          d.exercises[i].id: _exerciseSnapshot(d.exercises[i], i),
    };
    _sessionSnapshots = {
      for (final s in db.sessions) s.id: _sessionSnapshot(s),
    };
    _inbodySnapshots = {
      for (final e in db.inbody) e.id: _inbodySnapshot(e),
    };
    _photoSnapshots = {
      for (final p in db.photos) p.id: _photoSnapshot(p),
    };
    _settingsSnapshot = _settingsSnapshotOf(db.settings);
  }

  Future<void> _deleteSessionChildren(String sessionId) async {
    final rows = await (select(sessionExercises)
          ..where((t) => t.sessionId.equals(sessionId)))
        .get();
    final rowIds = rows.map((r) => r.rowId).toList();
    if (rowIds.isNotEmpty) {
      await (delete(loggedSets)
            ..where((t) => t.sessionExerciseRowId.isIn(rowIds)))
          .go();
    }
    await (delete(sessionExercises)
          ..where((t) => t.sessionId.equals(sessionId)))
        .go();
    await (delete(exerciseRatings)
          ..where((t) => t.sessionId.equals(sessionId)))
        .go();
  }

  Future<void> saveAll(GymDB db) async {
    await transaction(() async {
      final currentDayIds = db.days.map((d) => d.id).toSet();
      final currentExerciseIds = {
        for (final d in db.days)
          for (final e in d.exercises) e.id,
      };
      final currentSessionIds = db.sessions.map((s) => s.id).toSet();
      final currentInbodyIds = db.inbody.map((e) => e.id).toSet();
      final currentPhotoIds = db.photos.map((p) => p.id).toSet();

      // Delete only records that this isolate knows were previously present
      // and that the current in-memory DB explicitly removed.
      for (final id in _daySnapshots.keys) {
        if (!currentDayIds.contains(id)) {
          await (delete(days)..where((t) => t.id.equals(id))).go();
        }
      }
      for (final id in _exerciseSnapshots.keys) {
        if (!currentExerciseIds.contains(id)) {
          await (delete(exercises)..where((t) => t.id.equals(id))).go();
        }
      }
      for (final id in _sessionSnapshots.keys) {
        if (!currentSessionIds.contains(id)) {
          await _deleteSessionChildren(id);
          await (delete(sessions)..where((t) => t.id.equals(id))).go();
        }
      }
      for (final id in _inbodySnapshots.keys) {
        if (!currentInbodyIds.contains(id)) {
          await (delete(inbodyEntries)..where((t) => t.id.equals(id))).go();
        }
      }
      for (final id in _photoSnapshots.keys) {
        if (!currentPhotoIds.contains(id)) {
          await (delete(progressPhotos)..where((t) => t.id.equals(id))).go();
        }
      }

      // Days/exercises: update/insert only changed rows.
      for (var di = 0; di < db.days.length; di++) {
        final d = db.days[di];
        final snap = _daySnapshot(d, di);
        if (_daySnapshots[d.id] != snap) {
          await into(days).insertOnConflictUpdate(
            DaysCompanion.insert(
              id: d.id,
              name: d.name,
              sortOrder: Value(di),
            ),
          );
        }

        for (var ei = 0; ei < d.exercises.length; ei++) {
          final e = d.exercises[ei];
          final eSnap = _exerciseSnapshot(e, ei);
          if (_exerciseSnapshots[e.id] != eSnap) {
            await into(exercises).insertOnConflictUpdate(
              ExercisesCompanion.insert(
                id: e.id,
                dayId: d.id,
                name: e.name,
                sets: Value(e.sets),
                reps: Value(e.reps),
                rest: Value(e.rest),
                plates: Value(e.plates),
                core: Value(e.core),
                cardio: Value(e.cardio),
                isMain: Value(e.isMain),
                noRestAfter: Value(e.noRestAfter),
                assetImage: Value(e.assetImage),
                filePath: Value(e.filePath),
                imageRemoved: Value(e.imageRemoved),
                sortOrder: Value(ei),
              ),
            );
          }
        }
      }

      // Sessions are the hot path. A session's child rows are rewritten only
      // when that particular session actually changed.
      for (final s in db.sessions) {
        final snap = _sessionSnapshot(s);
        if (_sessionSnapshots[s.id] == snap) continue;

        await into(sessions).insertOnConflictUpdate(
          SessionsCompanion.insert(
            id: s.id,
            dayId: s.dayId,
            dayName: s.dayName,
            date: s.date,
            startedAt: Value(s.startedAt),
            endedAt: Value(s.endedAt),
            unlockedExerciseCount: Value(s.unlockedExerciseCount),
            rating: Value(s.rating),
            notes: Value(s.notes),
          ),
        );

        await _deleteSessionChildren(s.id);

        for (var sei = 0; sei < s.exercises.length; sei++) {
          final se = s.exercises[sei];
          final seRowId = await into(sessionExercises).insert(
            SessionExercisesCompanion.insert(
              sessionId: s.id,
              exerciseId: se.exerciseId,
              name: se.name,
              targetSets: Value(se.targetSets),
              targetReps: Value(se.targetReps),
              rest: Value(se.rest),
              core: Value(se.core),
              cardio: Value(se.cardio),
              noRestAfter: Value(se.noRestAfter),
              prefilled: Value(se.prefilled),
              autoBumped: Value(se.autoBumped),
              deloadSuggested: Value(se.deloadSuggested),
              swapped: Value(se.swapped),
              isPR: Value(se.isPR),
              unlockedSetCount: Value(se.unlockedSetCount),
              sortOrder: Value(sei),
            ),
          );
          for (var lsi = 0; lsi < se.loggedSets.length; lsi++) {
            final ls = se.loggedSets[lsi];
            await into(loggedSets).insert(
              LoggedSetsCompanion.insert(
                sessionExerciseRowId: seRowId,
                weight: Value(ls.weight),
                reps: Value(ls.reps),
                done: Value(ls.done),
                note: Value(ls.note),
                isDrop: Value(ls.isDrop),
                sortOrder: Value(lsi),
              ),
            );
          }
        }

        for (final entry in s.exerciseRatings.entries) {
          await into(exerciseRatings).insertOnConflictUpdate(
            ExerciseRatingsCompanion.insert(
              sessionId: s.id,
              exerciseId: entry.key,
              rating: entry.value,
            ),
          );
        }
      }

      // InBody/photos are small tables but still get true partial syncing.
      for (final e in db.inbody) {
        final snap = _inbodySnapshot(e);
        if (_inbodySnapshots[e.id] != snap) {
          await into(inbodyEntries).insertOnConflictUpdate(
            InbodyEntriesCompanion.insert(
              id: e.id,
              date: e.date,
              weight: Value(e.weight),
              fat: Value(e.fat),
              muscle: Value(e.muscle),
              arm: Value(e.arm),
              chest: Value(e.chest),
              waist: Value(e.waist),
              thigh: Value(e.thigh),
              notes: Value(e.notes),
            ),
          );
        }
      }

      for (final p0 in db.photos) {
        final snap = _photoSnapshot(p0);
        if (_photoSnapshots[p0.id] != snap) {
          await into(progressPhotos).insertOnConflictUpdate(
            ProgressPhotosCompanion.insert(
              id: p0.id,
              date: p0.date,
              path: p0.path,
            ),
          );
        }
      }

      final settingsSnap = _settingsSnapshotOf(db.settings);
      if (_settingsSnapshot != settingsSnap) {
        final s = db.settings;
        await into(appSettingsRow).insertOnConflictUpdate(
          AppSettingsRowCompanion.insert(
            id: const Value(0),
            waterIntervalMin: Value(s.waterIntervalMin),
            transitionSeconds: Value(s.transitionSeconds),
            soundEnabled: Value(s.soundEnabled),
            vibrationEnabled: Value(s.vibrationEnabled),
            alertsEnabled: Value(s.alertsEnabled),
            keepScreenOn: Value(s.keepScreenOn),
            barWeight: Value(s.barWeight),
            autoProgress: Value(s.autoProgress),
            reminderEnabled: Value(s.reminderEnabled),
            reminderHour: Value(s.reminderHour),
            reminderMinute: Value(s.reminderMinute),
            reminderQuickLogEnabled: Value(s.reminderQuickLogEnabled),
            fallbackBodyWeightKg: Value(s.fallbackBodyWeightKg),
          ),
        );
      }
    });

    _captureSnapshots(db);
  }

  /// إعدادات التطبيق فقط — لا تلمس تاريخ التمرين أو InBody أو الصور.
  Future<void> saveSettings(AppSettings s) async {
    await transaction(() async {
      await into(appSettingsRow).insertOnConflictUpdate(
        AppSettingsRowCompanion.insert(
          id: const Value(0),
          waterIntervalMin: Value(s.waterIntervalMin),
          transitionSeconds: Value(s.transitionSeconds),
          soundEnabled: Value(s.soundEnabled),
          vibrationEnabled: Value(s.vibrationEnabled),
          alertsEnabled: Value(s.alertsEnabled),
          keepScreenOn: Value(s.keepScreenOn),
          barWeight: Value(s.barWeight),
          autoProgress: Value(s.autoProgress),
          reminderEnabled: Value(s.reminderEnabled),
          reminderHour: Value(s.reminderHour),
          reminderMinute: Value(s.reminderMinute),
          reminderQuickLogEnabled: Value(s.reminderQuickLogEnabled),
          fallbackBodyWeightKg: Value(s.fallbackBodyWeightKg),
        ),
      );
    });
    _settingsSnapshot = _settingsSnapshotOf(s);
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    // بيضمن تحميل مكتبة sqlite3 الأصلية الصح على أندرويد/iOS القديمة
    await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'saqr_gym.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
