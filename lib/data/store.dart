import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive.dart';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'db/app_database.dart' hide ProgressPhoto;
import 'default_program.dart';
import 'models.dart';
import 'gamification.dart';

import 'reset_guard.dart';
import 'backup_import_guard.dart';
const _kDbKey = 'saqr_gym_db_v1';
const _kBackupsKey = 'saqr_gym_backups_v1';
const _kBackupMetaKey = 'saqr_gym_backup_meta_v1';
const _kLastManualBackupKey = 'saqr_gym_last_manual_backup';

String uid(String prefix) {
  final r = Random();
  return '${prefix}_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}${r.nextInt(99999).toRadixString(36)}';
}

/// المخزن الرئيسي — كل الشاشات بتسمع منه وبيحفظ تلقائي على الجهاز.
///
/// دفعة 10: البيانات دلوقتي متخزنة في قاعدة SQLite حقيقية (Drift) بدل ما
/// كانت JSON واحد كبير جوه SharedPreferences. الـ API هنا (db / init / save)
/// فضل زي ما هو بالظبط عشان باقي التطبيق (كل الشاشات) يشتغل من غير أي تعديل.
class GymStore extends ChangeNotifier {
  late GymDB db;
  late SharedPreferences _prefs;
  late AppDatabase _appDb;
  Directory? _docsDir;
  bool ready = false;
  Timer? _saveDebounce;
  Future<void> _saveQueue = Future.value();

  /// آخر خطأ في الكتابة إلى SQLite. لا نعتبر العملية ناجحة إذا فشل الحفظ؛
  /// الواجهة تقدر تعرض هذا الخطأ للمستخدم بدل ما يظن أن البيانات اتسجلت.
  Object? lastSaveError;
  DateTime? lastSaveErrorAt;
  bool get persistenceHealthy => lastSaveError == null;


  Future<void> _migrateBackupMetadata() async {
    final raw = _prefs.getStringList(_kBackupsKey);
    if (raw == null || raw.isEmpty) return;
    final clean = <String>[];
    for (final item in raw) {
      try {
        final m = jsonDecode(item);
        if (m is Map && m['path'] is String && (m['path'] as String).isNotEmpty) {
          clean.add(jsonEncode({
            'at': (m['at'] as num?)?.toInt() ?? 0,
            'path': m['path'],
          }));
        }
      } catch (_) {
        // Old versions stored the complete DB JSON here. Do not carry it
        // forward; automatic backups are SQLite files now.
      }
    }
    if (clean.length != raw.length) {
      if (clean.isEmpty) {
        await _prefs.remove(_kBackupsKey);
      } else {
        await _prefs.setStringList(_kBackupsKey, clean);
      }
    }
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _migrateBackupMetadata();
    _docsDir = await getApplicationDocumentsDirectory();
    _appDb = AppDatabase();

    final hasSqlData = await _appDb.hasAnyData();
    if (hasSqlData) {
      // مهم جدًا: لو قراءة SQLite فشلت، ممنوع نرجع إلى defaultDB()
      // ثم save()؛ هذا كان ممكن يستبدل قاعدة سليمة/قابلة للاسترجاع بقاعدة فارغة.
      try {
        db = _migrate(await _appDb.loadAll());
      } catch (e, st) {
        debugPrint('SQLite load error: $e');
        debugPrintStack(stackTrace: st);
        throw StateError(
          'تعذّر قراءة قاعدة بيانات SAQR GYM الحالية. '
          'لم يتم استبدالها ببيانات افتراضية حفاظًا على بياناتك.',
        );
      }
    } else {
      // أول مرة تفتح فيها النسخة الجديدة: لو فيه بيانات قديمة من نسخة
      // SharedPreferences (قبل دفعة 10)، رحّلها تلقائيًا لقاعدة SQLite.
      final raw = _prefs.getString(_kDbKey);
      if (raw == null) {
        db = defaultDB();
      } else {
        try {
          db = _migrate(
              GymDB.fromJson(jsonDecode(raw) as Map<String, dynamic>));
          // نحذف مفتاح الترحيل فقط بعد نجاح parsing + migration.
          await _prefs.remove(_kDbKey);
        } catch (e, st) {
          debugPrint('Legacy DB load error: $e');
          debugPrintStack(stackTrace: st);
          // لا نستبدل بيانات قديمة غير قابلة للقراءة بقاعدة فارغة.
          throw StateError(
            'تعذّر قراءة بيانات SAQR GYM القديمة. '
            'لم يتم إنشاء قاعدة افتراضية فوقها حفاظًا على بياناتك.',
          );
        }
      }
      await save();
    }
    ready = true;
    notifyListeners();
  }

  String get photosDirPath => '${_docsDir?.path}/photos';
  String get exerciseImagesDirPath => '${_docsDir?.path}/exercise_images';

  Future<Directory> _ensureDir(String path) async {
    final d = Directory(path);
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  /// لو النسخة القديمة (من ملف HTML مثلًا) ناقصة حاجات، نكملها هنا
  GymDB _migrate(GymDB d) {
    if (d.days.isEmpty) d.days = defaultDays();
    for (final day in d.days) {
      for (final ex in day.exercises) {
        // ربط الصور المرجعية الجاهزة بالتمارين اللي ليها id معروف،
        // من غير ما نلمس صورة رفعها المستخدم أو صورة شالها بنفسه
        if (ex.assetImage == null &&
            ex.filePath == null &&
            !ex.imageRemoved &&
            kExerciseImages.containsKey(ex.id)) {
          ex.assetImage = kExerciseImages[ex.id];
        }
      }
    }
    return d;
  }

  Future<void> save() async {
    // Serialize writes inside the app isolate. If an earlier write failed,
    // the queue is still allowed to recover and retry on the next save.
    Future<void> write() async {
      try {
        await _appDb.saveAll(db);
        lastSaveError = null;
        lastSaveErrorAt = null;
      } catch (e, st) {
        lastSaveError = e;
        lastSaveErrorAt = DateTime.now();
        debugPrint('DB save error: $e');
        debugPrintStack(stackTrace: st);
        notifyListeners();
        rethrow;
      }
    }

    _saveQueue = _saveQueue.then((_) => write(), onError: (_) => write());
    await _saveQueue;
    Gamification.invalidate();
    notifyListeners();
    unawaited(_maybeAutoSnapshot());
  }

  /// حفظ مؤجل للتعديلات النصية السريعة (مثلاً اسم تمرين/وزن افتراضي).
  /// لا نكتب SQLite مع كل حرف.
  void saveDebounced({Duration delay = const Duration(milliseconds: 350)}) {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(delay, () {
      unawaited(save());
    });
    notifyListeners();
  }

  /// تحديث صف الإعدادات فقط — لا يعيد مزامنة تاريخ التمرين.
  Future<void> saveSettings() async {
    _saveDebounce?.cancel();

    Future<void> write() async {
      try {
        await _appDb.saveSettings(db.settings);
        lastSaveError = null;
        lastSaveErrorAt = null;
      } catch (e, st) {
        lastSaveError = e;
        lastSaveErrorAt = DateTime.now();
        debugPrint('DB settings save error: $e');
        debugPrintStack(stackTrace: st);
        notifyListeners();
        rethrow;
      }
    }

    _saveQueue = _saveQueue.then((_) => write(), onError: (_) => write());
    await _saveQueue;
    Gamification.invalidate();
    notifyListeners();
    unawaited(_maybeAutoSnapshot());
  }

  /// نسخ تلقائية محلية: نحتفظ بـ SQLite snapshot حقيقي بدل نسخ db.toJson()
  /// بالكامل داخل SharedPreferences. الـ prefs يحتفظ بالـmetadata والمسارات فقط.
  Future<void> _maybeAutoSnapshot() async {
    try {
      final metaRaw = _prefs.getString(_kBackupMetaKey);
      final meta = metaRaw == null
          ? <String, dynamic>{}
          : jsonDecode(metaRaw) as Map<String, dynamic>;
      final last = (meta['lastSnapshot'] as num?)?.toInt() ?? 0;
      const twoDays = 2 * 24 * 60 * 60 * 1000;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - last < twoDays) return;

      final dir = await _ensureDir('${_docsDir!.path}/auto_backups');
      await _appDb.checkpoint();
      final source = await AppDatabase.databaseFile();
      if (!await source.exists()) return;

      final snapshot = File(
          '${dir.path}/saqr-gym-auto-${DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-')}.sqlite');
      await source.copy(snapshot.path);

      final list = _prefs.getStringList(_kBackupsKey) ?? [];
      list.add(jsonEncode({'at': now, 'path': snapshot.path}));
      while (list.length > 3) {
        final removed = list.removeAt(0);
        try {
          final old = jsonDecode(removed) as Map<String, dynamic>;
          BackupImportGuard.validateEnvelope(old);
final oldPath = old['path']?.toString();
          if (oldPath != null) {
            final f = File(oldPath);
            if (await f.exists()) await f.delete();
          }
        } catch (_) {}
      }
      await _prefs.setStringList(_kBackupsKey, list);
      await _prefs.setString(
          _kBackupMetaKey, jsonEncode({'lastSnapshot': now}));
    } catch (e) {
      debugPrint('snapshot error: $e');
    }
  }

  /// Metadata فقط؛ الملفات نفسها هي SQLite snapshots داخل مجلد التطبيق.
  List<Map<String, dynamic>> listAutoBackups() {
    final list = _prefs.getStringList(_kBackupsKey) ?? [];
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < list.length; i++) {
      try {
        final m = jsonDecode(list[i]) as Map<String, dynamic>;
        final path = m['path']?.toString();
        if (path == null || path.isEmpty) continue;
        out.add({
          'index': i,
          'at': (m['at'] as num).toInt(),
          'path': path,
        });
      } catch (_) {}
    }
    return out;
  }

  Future<void> restoreAutoBackup(int index) async {
    final list = _prefs.getStringList(_kBackupsKey) ?? [];
    if (index < 0 || index >= list.length) return;
    final m = jsonDecode(list[index]) as Map<String, dynamic>;
    final path = m['path']?.toString();
    if (path == null || path.isEmpty) return;
    final backup = File(path);
    if (!await backup.exists()) return;

    final current = await AppDatabase.databaseFile();
    final safety = File('${current.path}.before-restore');
    try {
      await _appDb.checkpoint();
      if (await current.exists()) await current.copy(safety.path);

      await _appDb.close();
      final wal = File('${current.path}-wal');
      final shm = File('${current.path}-shm');
      if (await wal.exists()) await wal.delete();
      if (await shm.exists()) await shm.delete();
      await backup.copy(current.path);

      _appDb = AppDatabase();
      db = _migrate(await _appDb.loadAll());
      notifyListeners();
    } catch (e) {
      debugPrint('restore snapshot error: $e');
      try {
        await _appDb.close();
      } catch (_) {}
      _appDb = AppDatabase();
      if (await safety.exists()) {
        try {
          await _appDb.close();
        } catch (_) {}
        await safety.copy(current.path);
        _appDb = AppDatabase();
        db = _migrate(await _appDb.loadAll());
      }
      rethrow;
    } finally {
      if (await safety.exists()) {
        try {
          await safety.delete();
        } catch (_) {}
      }
    }
  }

  int get lastManualBackupAt => _prefs.getInt(_kLastManualBackupKey) ?? 0;

  Future<void> markManualBackup() async {
    await _prefs.setInt(
        _kLastManualBackupKey, DateTime.now().millisecondsSinceEpoch);
    notifyListeners();
  }

  bool get needsBackupReminder {
    if (db.sessions.length < 3) return false;
    return DateTime.now().millisecondsSinceEpoch - lastManualBackupAt >
        7 * 24 * 60 * 60 * 1000;
  }

  /// نسخة احتياطية محمولة: ملف ZIP واحد يحتوي manifest.json والصور كملفات
  /// منفصلة. هذا يمنع تضخم JSON الناتج عن base64 ويظل قابلًا للنقل بين الأجهزة.
  Future<File> buildBackupFile() async {
    final archive = Archive();
    final map = db.toJson();
    final photosMeta = <Map<String, dynamic>>[];
    final exerciseImages = <String, String>{};

    for (final p in db.photos) {
      final f = File(p.path);
      if (await f.exists()) {
        final name = 'photos/${p.id}.jpg';
        archive.addFile(ArchiveFile(name, await f.length(), await f.readAsBytes()));
        photosMeta.add({
          'id': p.id,
          'date': p.date.toIso8601String(),
          'file': name,
        });
      } else {
        photosMeta.add({'id': p.id, 'date': p.date.toIso8601String()});
      }
    }

    for (final day in db.days) {
      for (final ex in day.exercises) {
        final path = ex.filePath;
        if (path == null) continue;
        final f = File(path);
        if (!await f.exists()) continue;
        final name = 'exercise_images/${ex.id}.jpg';
        archive.addFile(ArchiveFile(name, await f.length(), await f.readAsBytes()));
        exerciseImages[ex.id] = name;
      }
    }

    map['backupFormat'] = BackupImportGuard.supportedFormat;
    map['createdAt'] = DateTime.now().toIso8601String();
    map['photosEmbedded'] = photosMeta;
    map['exerciseImagesEmbedded'] = exerciseImages;
    final manifest = utf8.encode(const JsonEncoder.withIndent('  ').convert(map));
    archive.addFile(ArchiveFile('manifest.json', manifest.length, manifest));

    final bytes = ZipEncoder().encode(archive);
    if (bytes == null || bytes.isEmpty) {
      throw StateError('فشل إنشاء ملف النسخة الاحتياطية');
    }
    final dir = await getTemporaryDirectory();
    final name =
        'saqr-gym-backup-${DateTime.now().toIso8601String().substring(0, 10)}.saqrbackup';
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// استيراد النسخة الجديدة المضغوطة، مع استمرار دعم JSON القديم للتوافق.
  Future<bool> importBackup(File file) async {
    File? rollback;
    final createdFiles = <File>[];
    try {
      await _saveQueue;
      await _appDb.checkpoint();
      final current = await AppDatabase.databaseFile();
      if (await current.exists()) {
        rollback = File('${current.path}.before-import-${DateTime.now().microsecondsSinceEpoch}');
        await current.copy(rollback.path);
      }
      final lower = file.path.toLowerCase();
      Map<String, dynamic> map;
      Archive? archive;
      if (lower.endsWith('.json')) {
        map = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      } else {
        archive = ZipDecoder().decodeBytes(await file.readAsBytes());
        final manifestFile = archive.findFile('manifest.json');
        if (manifestFile == null) {
          if (rollback != null && await rollback.exists()) { try { await rollback.delete(); } catch (_) {} }
          return false;
        }
        map = jsonDecode(utf8.decode(manifestFile.content as List<int>))
            as Map<String, dynamic>;
      }
      if (map['days'] is! List) {
        if (rollback != null && await rollback.exists()) { try { await rollback.delete(); } catch (_) {} }
        return false;
      }
      if (archive != null) {
        BackupImportGuard.validateEnvelope(map);
      }

      final imported = GymDB.fromJson(map);

      // صور التقدم: النسخة الجديدة تحفظها كملفات داخل ZIP، والنسخ القديمة
      // تُقرأ من base64 كما هي للحفاظ على التوافق.
      final embedded = map['photosEmbedded'];
      if (embedded is List) {
        final dir = await _ensureDir(photosDirPath);
        imported.photos = [];
        for (final e in embedded) {
          final m = Map<String, dynamic>.from(e);
          List<int>? bytes;
          final zipName = m['file']?.toString();
          if (archive != null && zipName != null) {
            final entry = archive.findFile(zipName);
            if (entry != null) bytes = List<int>.from(entry.content as List<int>);
          } else if (m['data'] is String) {
            bytes = base64Decode(m['data'] as String);
          }
          if (bytes == null) continue;
          final f = File('${dir.path}/import_${DateTime.now().microsecondsSinceEpoch}_${m['id']}.jpg');
          await f.writeAsBytes(bytes, flush: true);
          createdFiles.add(f);
          imported.photos.add(ProgressPhoto(
            id: m['id'].toString(),
            date: DateTime.tryParse(m['date']?.toString() ?? '') ?? DateTime.now(),
            path: f.path,
          ));
        }
      } else if (map['photos'] is List) {
        final dir = await _ensureDir(photosDirPath);
        imported.photos = [];
        for (final e in (map['photos'] as List)) {
          final m = Map<String, dynamic>.from(e);
          final img = m['image']?.toString();
          if (img == null || !img.contains('base64,')) continue;
          final f = File('${dir.path}/import_${DateTime.now().microsecondsSinceEpoch}_${m['id']}.jpg');
          await f.writeAsBytes(base64Decode(img.split('base64,').last), flush: true);
          createdFiles.add(f);
          imported.photos.add(ProgressPhoto(
            id: m['id'].toString(),
            date: DateTime.tryParse(m['date']?.toString() ?? '') ?? DateTime.now(),
            path: f.path,
          ));
        }
      }

      final exDir = await _ensureDir(exerciseImagesDirPath);
      final exEmbedded = map['exerciseImagesEmbedded'];
      if (exEmbedded is Map) {
        for (final day in imported.days) {
          for (final ex in day.exercises) {
            final ref = exEmbedded[ex.id];
            List<int>? bytes;
            if (archive != null && ref is String) {
              final entry = archive.findFile(ref);
              if (entry != null) bytes = List<int>.from(entry.content as List<int>);
            } else if (ref is String) {
              bytes = base64Decode(ref);
            }
            if (bytes != null) {
              final f = File('${exDir.path}/import_${DateTime.now().microsecondsSinceEpoch}_${ex.id}.jpg');
              await f.writeAsBytes(bytes, flush: true);
              createdFiles.add(f);
              ex.filePath = f.path;
            } else if (archive != null) {
              ex.filePath = null;
            }
          }
        }
      } else {
        final rawDays = map['days'] as List;
        for (var di = 0; di < imported.days.length && di < rawDays.length; di++) {
          final rawExs =
              (Map<String, dynamic>.from(rawDays[di])['exercises'] as List?) ?? [];
          for (var ei = 0; ei < imported.days[di].exercises.length && ei < rawExs.length; ei++) {
            final img = Map<String, dynamic>.from(rawExs[ei])['image']?.toString();
            final ex = imported.days[di].exercises[ei];
            if (img != null && img.contains('base64,')) {
              final f = File('${exDir.path}/import_${DateTime.now().microsecondsSinceEpoch}_${ex.id}.jpg');
              await f.writeAsBytes(base64Decode(img.split('base64,').last), flush: true);
              createdFiles.add(f);
              ex.filePath = f.path;
            } else {
              ex.filePath = null;
              if (img == null) ex.imageRemoved = false;
            }
          }
        }
      }

      db = _migrate(imported);
      await save();
      if (rollback != null && await rollback.exists()) {
        try { await rollback.delete(); } catch (_) {}
      }
      return true;
    } catch (e) {
      debugPrint('import error: $e');
      for (final created in createdFiles) {
        try { if (await created.exists()) await created.delete(); } catch (_) {}
      }
      // Restore the pre-import DB if the final save failed.
      if (rollback != null && await rollback.exists()) {
        try {
          final current = await AppDatabase.databaseFile();
          await _appDb.close();
          final wal = File('${current.path}-wal');
          final shm = File('${current.path}-shm');
          if (await wal.exists()) await wal.delete();
          if (await shm.exists()) await shm.delete();
          await rollback.copy(current.path);
          _appDb = AppDatabase();
          db = _migrate(await _appDb.loadAll());
          lastSaveError = null;
          lastSaveErrorAt = null;
        } catch (rollbackError, rollbackStack) {
          debugPrint('import rollback error: $rollbackError');
          debugPrintStack(stackTrace: rollbackStack);
        } finally {
          try { await rollback.delete(); } catch (_) {}
        }
      }
      return false;
    }
  }

  Future<void> resetAll({bool confirmed = false}) async {
    requireResetConfirmation(confirmed);
    db = defaultDB();
    await save();
  }

  // ---------- تعديل البرنامج ----------
  Future<void> renameDay(String dayId, String name) async {
    db.days.firstWhere((d) => d.id == dayId).name = name;
    await save();
  }

  Future<WorkoutDay?> deleteDay(String dayId) async {
    final idx = db.days.indexWhere((d) => d.id == dayId);
    if (idx == -1) return null;
    final removed = db.days.removeAt(idx);
    await save();
    return removed;
  }

  Future<void> restoreDay(int index, WorkoutDay day) async {
    db.days.insert(index.clamp(0, db.days.length), day);
    await save();
  }

  int dayIndex(String dayId) => db.days.indexWhere((d) => d.id == dayId);

  Future<void> addDay(String name) async {
    db.days.add(WorkoutDay(id: uid('d'), name: name));
    await save();
  }

  /// نسخ يوم تدريب كامل بكل تمارينه — بيتحط بعد اليوم الأصلي مباشرة
  Future<WorkoutDay> duplicateDay(String dayId) async {
    final idx = db.days.indexWhere((d) => d.id == dayId);
    final original = db.days[idx];
    final copy = WorkoutDay(
      id: uid('d'),
      name: '${original.name} (نسخة)',
      exercises: original.exercises
          .map((e) => ExerciseDef.fromJson(e.toJson())..id = uid('e'))
          .toList(),
    );
    db.days.insert(idx + 1, copy);
    await save();
    return copy;
  }

  Future<void> addExercise(String dayId) async {
    final day = db.days.firstWhere((d) => d.id == dayId);
    day.exercises.add(ExerciseDef(
        id: uid('e'), name: 'تمرين جديد', sets: 3, reps: '10', rest: 60));
    await save();
  }

  Future<ExerciseDef?> deleteExercise(String dayId, String exId) async {
    final day = db.days.firstWhere((d) => d.id == dayId);
    final idx = day.exercises.indexWhere((e) => e.id == exId);
    if (idx == -1) return null;
    final removed = day.exercises.removeAt(idx);
    await save();
    return removed;
  }

  Future<void> restoreExercise(String dayId, int index, ExerciseDef ex) async {
    final day = db.days.firstWhere((d) => d.id == dayId);
    day.exercises.insert(index.clamp(0, day.exercises.length), ex);
    await save();
  }

  int exerciseIndex(String dayId, String exId) =>
      db.days.firstWhere((d) => d.id == dayId).exercises
          .indexWhere((e) => e.id == exId);

  Future<void> reorderExercise(String dayId, int oldIndex, int newIndex) async {
    final day = db.days.firstWhere((d) => d.id == dayId);
    if (newIndex > oldIndex) newIndex -= 1;
    final ex = day.exercises.removeAt(oldIndex);
    day.exercises.insert(newIndex.clamp(0, day.exercises.length), ex);
    await save();
  }

  ExerciseDef? findExercise(String exId) {
    for (final d in db.days) {
      for (final e in d.exercises) {
        if (e.id == exId) return e;
      }
    }
    return null;
  }

  WorkoutDay? dayOfExercise(String exId) {
    for (final d in db.days) {
      if (d.exercises.any((e) => e.id == exId)) return d;
    }
    return null;
  }

  /// صورة التمرين بتتقرأ من البرنامج الحالي عشان أي تعديل يبان فورًا
  ExerciseDef? defOf(String exId) => findExercise(exId);

  Future<void> setExerciseImageFile(
      String dayId, String exId, File picked) async {
    final dir = await _ensureDir(exerciseImagesDirPath);
    final dest = File('${dir.path}/${exId}_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await dest.writeAsBytes(await picked.readAsBytes());
    final day = db.days.firstWhere((d) => d.id == dayId);
    final ex = day.exercises.firstWhere((e) => e.id == exId);
    // امسح الصورة القديمة اللي المستخدم كان رافعها
    if (ex.filePath != null) {
      final old = File(ex.filePath!);
      if (await old.exists()) await old.delete();
    }
    ex.filePath = dest.path;
    ex.imageRemoved = false;
    await save();
  }

  Future<void> removeExerciseImage(String dayId, String exId) async {
    final day = db.days.firstWhere((d) => d.id == dayId);
    final ex = day.exercises.firstWhere((e) => e.id == exId);
    if (ex.filePath != null) {
      final old = File(ex.filePath!);
      if (await old.exists()) await old.delete();
      ex.filePath = null;
    }
    ex.imageRemoved = true;
    await save();
  }

  Future<void> restoreDefaultExerciseImage(String dayId, String exId) async {
    final day = db.days.firstWhere((d) => d.id == dayId);
    final ex = day.exercises.firstWhere((e) => e.id == exId);
    ex.imageRemoved = false;
    ex.assetImage = kExerciseImages[ex.id];
    await save();
  }

  // ---------- InBody ----------
  Future<void> addInbody(InBodyEntry e) async {
    db.inbody.add(e);
    await save();
  }

  Future<InBodyEntry?> deleteInbody(String id) async {
    final idx = db.inbody.indexWhere((e) => e.id == id);
    if (idx == -1) return null;
    final removed = db.inbody.removeAt(idx);
    await save();
    return removed;
  }

  // ---------- صور التقدم ----------
  Future<void> addProgressPhoto(File picked) async {
    final dir = await _ensureDir(photosDirPath);
    final id = uid('ph');
    final dest = File('${dir.path}/$id.jpg');
    await dest.writeAsBytes(await picked.readAsBytes());
    db.photos.add(ProgressPhoto(id: id, date: DateTime.now(), path: dest.path));
    await save();
  }

  Future<void> deletePhoto(String id) async {
    final idx = db.photos.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    final p = db.photos.removeAt(idx);
    final f = File(p.path);
    if (await f.exists()) await f.delete();
    await save();
  }

  // ---------- الجلسات ----------
  Future<void> addSession(WorkoutSession s) async {
    db.sessions.add(s);
    await save();
  }

  Future<WorkoutSession?> deleteSession(String id) async {
    final idx = db.sessions.indexWhere((s) => s.id == id);
    if (idx == -1) return null;
    final removed = db.sessions.removeAt(idx);
    await save();
    return removed;
  }

  Future<void> restoreSession(int index, WorkoutSession s) async {
    db.sessions.insert(index.clamp(0, db.sessions.length), s);
    await save();
  }

  /// ترتيب تلقائي أذكى: التمارين الأساسية (المتعلّمة isMain) الأول،
  /// عشان تتعمل وإنت لسه بأعلى طاقة، والباقي بعدها بنفس ترتيبهم
  Future<void> autoOrderMainFirst(String dayId) async {
    final day = db.days.firstWhere((d) => d.id == dayId);
    final mains = day.exercises.where((e) => e.isMain).toList();
    final others = day.exercises.where((e) => !e.isMain).toList();
    day.exercises = [...mains, ...others];
    await save();
  }
}

final store = GymStore();
