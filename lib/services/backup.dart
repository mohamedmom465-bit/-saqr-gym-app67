import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../data/store.dart';
import '../ui/theme.dart';
import 'feedback.dart';

class BackupService {
  /// مشاركة نسخة احتياطية (درايف / واتساب / ملفات)
  static Future<void> share(BuildContext context) async {
    try {
      final file = await store.buildBackupFile();
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/zip')],
        subject: 'نسخة احتياطية - نظام صقر',
        text: 'نسخة احتياطية من تطبيق SAQR GYM',
      );
      await store.markManualBackup();
      Fx.toast('✅ اتشاركت النسخة الاحتياطية');
    } catch (e) {
      Fx.toast('⚠️ مقدرناش نشارك الملف: $e', duration: const Duration(seconds: 4));
    }
  }

  /// حفظ نسخة عبر مدير الملفات/واجهة اختيار مكان النظام بدل الكتابة
  /// لمسار /storage/emulated/0/Download مباشرة (Scoped Storage).
  static Future<void> saveToDevice(BuildContext context) async {
    try {
      final file = await store.buildBackupFile();
      final bytes = await file.readAsBytes();
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'حفظ نسخة SAQR GYM الاحتياطية',
        fileName: file.uri.pathSegments.last,
        type: FileType.custom,
        allowedExtensions: const ['saqrbackup', 'json'],
      );
      if (path == null || path.isEmpty) return;
      await File(path).writeAsBytes(bytes, flush: true);
      await store.markManualBackup();
      Fx.toast('✅ اتحفظت النسخة الاحتياطية');
    } catch (e) {
      Fx.toast('⚠️ مقدرناش نحفظ الملف: $e',
          duration: const Duration(seconds: 4));
    }
  }

  /// استيراد نسخة احتياطية من خلال منتقي ملفات النظام.
  /// لا نطلب من المستخدم نسخ JSON ولصقه في TextField.
  static Future<void> import(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'اختيار نسخة SAQR GYM الاحتياطية',
        type: FileType.custom,
        allowedExtensions: const ['saqrbackup', 'json'],
        withData: false,
      );
      if (result == null || result.files.isEmpty) return;

      final picked = result.files.single;
      final path = picked.path;
      if (path == null || path.isEmpty) {
        Fx.toast('⚠️ مقدرناش نقرأ الملف المختار');
        return;
      }

      final file = File(path);
      if (!await file.exists()) {
        Fx.toast('⚠️ الملف مش موجود');
        return;
      }

      final map = await _readBackupManifest(file);
      if (map == null || map['days'] is! List) {
        Fx.toast('⚠️ الملف مش نسخة احتياطية صحيحة');
        return;
      }

      if (!context.mounted) return;
      final ok = await _confirmWithComparison(context, map);
      if (!ok || !context.mounted) return;

      final done = await store.importBackup(file);
      Fx.toast(done
          ? '✅ اتستوردت النسخة الاحتياطية بنجاح'
          : '⚠️ الملف مش نسخة احتياطية صحيحة');
    } on FormatException {
      Fx.toast('⚠️ الملف مش JSON صحيح');
    } catch (e) {
      debugPrint('backup import UI error: $e');
      Fx.toast('⚠️ حصلت مشكلة وإحنا بنقرأ النسخة الاحتياطية');
    }
  }

  static Future<Map<String, dynamic>?> _readBackupManifest(File file) async {
    final lower = file.path.toLowerCase();
    if (lower.endsWith('.json')) {
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    }
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final entry = archive.findFile('manifest.json');
    if (entry == null) return null;
    return jsonDecode(utf8.decode(entry.content as List<int>))
        as Map<String, dynamic>;
  }

  /// حوار مقارنة بيانات حالية مقابل بيانات النسخة المستوردة — عشان محدش
  /// يستبدل بيانات جديدة بغلط بنسخة قديمة من غير ما يلاحظ
  static Future<bool> _confirmWithComparison(
      BuildContext context, Map<String, dynamic> map) async {
    final curDays = store.db.days.length;
    final curSessions = store.db.sessions.length;
    final curInbody = store.db.inbody.length;
    DateTime? curLast;
    for (final s in store.db.sessions) {
      if (curLast == null || s.date.isAfter(curLast)) curLast = s.date;
    }

    final newDays = (map['days'] as List).length;
    final newSessions = (map['sessions'] is List) ? (map['sessions'] as List).length : 0;
    final newInbody = (map['inbody'] is List) ? (map['inbody'] as List).length : 0;
    DateTime? newLast;
    if (map['sessions'] is List) {
      for (final s in (map['sessions'] as List)) {
        final d = DateTime.tryParse(
            Map<String, dynamic>.from(s)['date']?.toString() ?? '');
        if (d != null && (newLast == null || d.isAfter(newLast))) newLast = d;
      }
    }

    final warnOlder =
        curLast != null && newLast != null && newLast.isBefore(curLast);
    final warnFewer = curSessions > 0 && newSessions < curSessions;

    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.panel,
        surfaceTintColor: Colors.transparent,
        title: const Text('قارن قبل ما تستورد',
            style: TextStyle(fontSize: 15, color: C.text)),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Expanded(flex: 2, child: SizedBox()),
                  Expanded(
                      child: Text('حالي',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: C.muted))),
                  Expanded(
                      child: Text('الملف',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 11,
                              color: C.accent,
                              fontWeight: FontWeight.w700))),
                ],
              ),
              const Divider(color: C.border, height: 14),
              _compareRow('أيام التدريب', '$curDays', '$newDays'),
              _compareRow('الجلسات المسجلة', '$curSessions', '$newSessions'),
              _compareRow('قياسات InBody', '$curInbody', '$newInbody'),
              _compareRow('آخر جلسة', curLast == null ? '-' : fmtDateShort(curLast),
                  newLast == null ? '-' : fmtDateShort(newLast)),
              const SizedBox(height: 10),
              if (warnOlder || warnFewer)
                const Text(
                  '⚠️ الملف ده يبدو أقدم أو فيه بيانات أقل من اللي عندك دلوقتي — '
                  'هتفقد أي تمرين اتسجل بعد كده لو كملت.',
                  style: TextStyle(fontSize: 12, color: C.danger, height: 1.6),
                )
              else
                const Text(
                  'هيتم استبدال كل البيانات الحالية بالنسخة دي.',
                  style: TextStyle(fontSize: 12, color: C.muted, height: 1.6),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(color: C.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(warnOlder || warnFewer ? 'استورد برضه' : 'استيراد',
                style: const TextStyle(
                    color: C.danger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  static Widget _compareRow(String label, String cur, String next) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
              flex: 2,
              child: Text(label,
                  style: const TextStyle(fontSize: 12.5, color: C.text))),
          Expanded(
              child: Text(cur,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12.5, color: C.muted))),
          Expanded(
              child: Text(next,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12.5,
                      color: C.accent,
                      fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}
