import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../data/default_program.dart';
import '../data/models.dart';
import '../data/providers.dart';
import '../data/store.dart';
import '../services/backup.dart';
import '../services/feedback.dart';
import '../services/notifications.dart';
import '../ui/theme.dart';
import '../ui/transitions.dart';
import '../ui/widgets.dart';
import 'day_detail_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(gymStoreProvider);
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final s = store.db.settings;
        final autoBackups = store.listAutoBackups().reversed.toList();

        return Scaffold(
          appBar: saqrAppBar(
              eyebrow: 'CUSTOMIZE', title: 'تعديل البرنامج', showBack: false),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
            children: [
              const SectionTitle('إعدادات عامة', topGap: 0),
              SCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _NumSetting(
                      label: 'تذكير شرب المية كل (دقيقة)',
                      value: s.waterIntervalMin.toString(),
                      onChanged: (v) {
                        // أقل حاجة 5 دقايق عشان محدش يحط 0 أو رقم صغير
                        // جدًا فيبقى التذكير بيجي كل شوية بشكل مزعج.
                        s.waterIntervalMin =
                            (int.tryParse(v) ?? 20).clamp(5, 180);
                        store.saveDebounced();
                      },
                    ),
                    _NumSetting(
                      label: 'وقت انتقال إضافي لو محتاج تركيب أوزان (ثانية)',
                      value: s.transitionSeconds.toString(),
                      onChanged: (v) {
                        s.transitionSeconds =
                            (int.tryParse(v) ?? 45).clamp(0, 600);
                        store.saveDebounced();
                      },
                    ),
                    _NumSetting(
                      label: 'وزن البار الفاضي (كجم) — لحاسبة الأطباق',
                      value: numStr(s.barWeight),
                      decimal: true,
                      onChanged: (v) {
                        s.barWeight = (double.tryParse(v) ?? 20).clamp(0, 50);
                        store.saveDebounced();
                      },
                    ),
                    const SizedBox(height: 6),
                    _Toggle(
                      label:
                          '🔼 اقتراح زيادة 2.5كجم تلقائي لو كملت كل مجموعاتك آخر مرة',
                      value: s.autoProgress,
                      onChanged: (v) {
                        s.autoProgress = v;
                        store.saveDebounced();
                      },
                      divider: false,
                    ),
                    const SizedBox(height: 6),
                    _NumSetting(
                      label:
                          '⚖️ وزن جسمك الافتراضي (كجم) — لتقدير السعرات لو مفيش قياس InBody',
                      value: numStr(s.fallbackBodyWeightKg),
                      decimal: true,
                      onChanged: (v) {
                        s.fallbackBodyWeightKg =
                            (double.tryParse(v) ?? 75).clamp(30, 250);
                        store.saveDebounced();
                      },
                    ),
                  ],
                ),
              ),

              const SectionTitle('🔔 تذكير التمرين'),
              SCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Toggle(
                      label: 'تذكير يومي بميعاد التمرين (إشعار نظام حقيقي)',
                      value: s.reminderEnabled,
                      onChanged: (v) async {
                        if (v) {
                          final granted = await NotificationService.instance
                              .requestPermission();
                          if (!granted) {
                            Fx.toast(
                                '⚠️ لازم توافق على صلاحية الإشعارات من إعدادات الجهاز الأول');
                            return;
                          }
                        }
                        s.reminderEnabled = v;
                        await store.saveSettings();
                        await NotificationService.instance
                            .rescheduleReminders();
                        if (v) Fx.toast('🔔 اتفعّل التذكير اليومي');
                      },
                    ),
                    Row(
                      children: [
                        const Expanded(
                          child: Text('ميعاد التذكير',
                              style: TextStyle(fontSize: 12.5, height: 1.6)),
                        ),
                        SButton(
                          '${s.reminderHour.toString().padLeft(2, '0')}:${s.reminderMinute.toString().padLeft(2, '0')}',
                          kind: BtnKind.secondary,
                          small: true,
                          expand: false,
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(
                                  hour: s.reminderHour,
                                  minute: s.reminderMinute),
                            );
                            if (picked == null) return;
                            s.reminderHour = picked.hour;
                            s.reminderMinute = picked.minute;
                            await store.saveSettings();
                            await NotificationService.instance
                                .rescheduleReminders();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _Toggle(
                      label:
                          '✅ زرار "سجّلت النهارده" جوه الإشعار (Quick-log بأوزان آخر مرة)',
                      value: s.reminderQuickLogEnabled,
                      onChanged: (v) async {
                        s.reminderQuickLogEnabled = v;
                        await store.saveSettings();
                        await NotificationService.instance
                            .rescheduleReminders();
                      },
                      divider: false,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'الزرار ده بيسجّل تمرين "الدور الجاي" كامل بأوزان آخر مرة من غير ما تفتح التطبيق خالص — لو حبيت تعدّل حاجة، افتح التطبيق عادي.',
                      style: TextStyle(fontSize: 11.5, color: C.muted, height: 1.6),
                    ),
                  ],
                ),
              ),

              const SectionTitle('تنبيهات'),
              SCard(
                child: Column(
                  children: [
                    _Toggle(
                      label: '🔊 صوت عند خلاص الراحة',
                      value: s.soundEnabled,
                      onChanged: (v) {
                        s.soundEnabled = v;
                        store.saveDebounced();
                      },
                    ),
                    _Toggle(
                      label: '📳 اهتزاز عند خلاص الراحة / إنهاء مجموعة',
                      value: s.vibrationEnabled,
                      onChanged: (v) {
                        s.vibrationEnabled = v;
                        store.saveDebounced();
                      },
                    ),
                    _Toggle(
                      label: '🔔 تنبيهات جوه التطبيق (راحة / مية)',
                      value: s.alertsEnabled,
                      onChanged: (v) {
                        s.alertsEnabled = v;
                        store.saveDebounced();
                      },
                    ),
                    _Toggle(
                      label: '💡 الشاشة تفضل مفتوحة وقت التمرين',
                      value: s.keepScreenOn,
                      onChanged: (v) {
                        s.keepScreenOn = v;
                        store.saveDebounced();
                      },
                      divider: false,
                    ),
                  ],
                ),
              ),

              const SectionTitle('أيام التدريب'),
              const _ExerciseSearchBox(),
              ...store.db.days.map((d) => _DayEditor(day: d)),
              SButton('+ إضافة يوم تدريب جديد',
                  kind: BtnKind.secondary,
                  onPressed: () async {
                    final name = await promptDialog(context,
                        title: 'اسم اليوم الجديد', initial: 'Push 3');
                    if (name != null && name.isNotEmpty) {
                      await store.addDay(name);
                    }
                  }),

              const SectionTitle('بيانات'),
              SCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🛟 بياناتك متخزنة على جهازك بس (مفيش سيرفر). لو مسحت بيانات التطبيق أو غيرت جهاز هتضيع، '
                      'فأحسن حماية إنك تشارك نسخة احتياطية بانتظام على درايف أو واتساب.',
                      style: TextStyle(
                          fontSize: 12.5, color: C.muted, height: 1.8),
                    ),
                    const SizedBox(height: 12),
                    SButton('📤 مشاركة نسخة احتياطية (Drive / WhatsApp / Files)',
                        small: true,
                        onPressed: () => BackupService.share(context)),
                    const SizedBox(height: 8),
                    SButton('⬇ حفظ نسخة احتياطية على الجهاز',
                        kind: BtnKind.secondary,
                        small: true,
                        onPressed: () => BackupService.saveToDevice(context)),
                    const SizedBox(height: 8),
                    SButton('⬆ استيراد نسخة احتياطية (JSON)',
                        kind: BtnKind.ghost,
                        small: true,
                        onPressed: () => BackupService.import(context)),
                    if (store.lastManualBackupAt > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          'آخر نسخة احتياطية يدوية: ${fmtDateTime(DateTime.fromMillisecondsSinceEpoch(store.lastManualBackupAt))}',
                          style:
                              const TextStyle(fontSize: 11.5, color: C.muted),
                        ),
                      ),
                  ],
                ),
              ),

              if (autoBackups.isNotEmpty) ...[
                const SectionTitle('نسخ تلقائية محفوظة على الجهاز'),
                SCard(
                  child: Column(
                    children: [
                      for (var i = 0; i < autoBackups.length; i++)
                        ListRow(
                          divider: i != autoBackups.length - 1,
                          start: Text(
                            fmtDateTime(DateTime.fromMillisecondsSinceEpoch(
                                autoBackups[i]['at'] as int)),
                            style: const TextStyle(fontSize: 12.5),
                          ),
                          end: SButton('استرجاع',
                              kind: BtnKind.ghost,
                              small: true,
                              expand: false, onPressed: () async {
                            final ok = await confirmDialog(
                              context,
                              'هيتم استرجاع النسخة دي وهتحل محل بياناتك الحالية. متأكد؟',
                              danger: true,
                            );
                            if (!ok) return;
                            await store.restoreAutoBackup(
                                autoBackups[i]['index'] as int);
                            Fx.toast('✅ اترجعت النسخة الاحتياطية');
                          }),
                        ),
                    ],
                  ),
                ),
              ],

              SCard(
                child: SButton('حذف كل البيانات والبدء من جديد',
                    kind: BtnKind.danger, small: true, onPressed: () async {
                  final ok = await confirmDialog(
                    context,
                    'هيتحذف كل حاجة (التمارين والتقارير والInBody والصور). متأكد؟',
                    danger: true,
                  );
                  if (!ok) return;
                  await store.resetAll(confirmed: true);
                  Fx.toast('اترجع البرنامج للوضع الافتراضي');
                }),
              ),
              const SizedBox(height: 10),
              const Text('SAQR TRAINING SYSTEM · نسخة 2.0',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: C.muted)),
            ],
          ),
        );
      },
    );
  }
}

class _Toggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool divider;
  const _Toggle({
    required this.label,
    required this.value,
    required this.onChanged,
    this.divider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: divider
          ? const BoxDecoration(
              border: Border(bottom: BorderSide(color: C.border)))
          : null,
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 12.5, height: 1.6)),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _NumSetting extends StatefulWidget {
  final String label;
  final String value;
  final bool decimal;
  final ValueChanged<String> onChanged;
  const _NumSetting({
    required this.label,
    required this.value,
    required this.onChanged,
    this.decimal = false,
  });

  @override
  State<_NumSetting> createState() => _NumSettingState();
}

class _NumSettingState extends State<_NumSetting> {
  late final TextEditingController ctrl =
      TextEditingController(text: widget.value);

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(widget.label),
        TextField(
          controller: ctrl,
          keyboardType: TextInputType.numberWithOptions(decimal: widget.decimal),
          style: const TextStyle(fontSize: 15, color: C.text),
          onChanged: widget.onChanged,
        ),
      ],
    );
  }
}

/// محرر يوم تدريب كامل — الاسم، التمارين، الترتيب، الصور
class _DayEditor extends StatelessWidget {
  final WorkoutDay day;
  const _DayEditor({required this.day});

  @override
  Widget build(BuildContext context) {
    return SCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _InlineText(
                  key: ValueKey('dayname_${day.id}'),
                  initial: day.name,
                  bold: true,
                  onChanged: (v) => store.renameDay(day.id, v),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.sort_rounded, color: C.muted, size: 20),
                tooltip: 'رتب: الأساسي الأول',
                onPressed: () async {
                  await store.autoOrderMainFirst(day.id);
                  Fx.toast('🔀 اترتبت التمارين — الأساسي دلوقتي الأول');
                },
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, color: C.muted, size: 20),
                tooltip: 'نسخ اليوم',
                onPressed: () async {
                  final copy = await store.duplicateDay(day.id);
                  Fx.toast('✅ اتنسخ اليوم باسم "${copy.name}"');
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: C.danger, size: 20),
                onPressed: () async {
                  final ok = await confirmDialog(
                      context, 'تأكيد حذف اليوم "${day.name}"؟',
                      danger: true);
                  if (!ok) return;
                  final idx = store.dayIndex(day.id);
                  final removed = await store.deleteDay(day.id);
                  if (removed != null) {
                    Fx.toastUndo('🗑 اتحذف يوم "${removed.name}"',
                        () => store.restoreDay(idx, removed));
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < day.exercises.length; i++)
            _ExerciseEditor(
              key: ValueKey('ex_${day.id}_${day.exercises[i].id}'),
              dayId: day.id,
              ex: day.exercises[i],
              canMoveUp: i > 0,
              canMoveDown: i < day.exercises.length - 1,
            ),
          const SizedBox(height: 8),
          SButton('+ إضافة تمرين',
              kind: BtnKind.ghost,
              small: true,
              onPressed: () => store.addExercise(day.id)),
        ],
      ),
    );
  }
}

class _ExerciseEditor extends StatefulWidget {
  final String dayId;
  final ExerciseDef ex;
  final bool canMoveUp;
  final bool canMoveDown;
  const _ExerciseEditor({
    super.key,
    required this.dayId,
    required this.ex,
    required this.canMoveUp,
    required this.canMoveDown,
  });

  @override
  State<_ExerciseEditor> createState() => _ExerciseEditorState();
}

class _ExerciseEditorState extends State<_ExerciseEditor> {
  bool open = false;

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: C.panel,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: C.text),
              title: const Text('من المعرض'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: C.text),
              title: const Text('كاميرا'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final x = await ImagePicker()
          .pickImage(source: source, maxWidth: 900, imageQuality: 78);
      if (x == null) return;
      await store.setExerciseImageFile(widget.dayId, widget.ex.id, File(x.path));
      Fx.toast('✅ اتضافت الصورة');
    } catch (e) {
      Fx.toast('⚠️ مقدرناش نفتح الصور، اتأكد من صلاحيات التطبيق');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ex = widget.ex;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: C.panel2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _InlineText(
                  key: ValueKey('exname_${ex.id}'),
                  initial: ex.name,
                  onChanged: (v) {
                    ex.name = v;
                    store.saveDebounced();
                  },
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32),
                icon: Icon(open ? Icons.expand_less : Icons.expand_more,
                    color: C.muted, size: 20),
                onPressed: () => setState(() => open = !open),
              ),
            ],
          ),
          if (!open)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${ex.sets} × ${ex.reps} · راحة ${ex.rest}ث'
                '${ex.plates ? ' · أوزان' : ''}'
                '${ex.isMain ? ' · أساسي' : ''}'
                '${ex.core ? ' · بطن' : ''}'
                '${ex.cardio ? ' · كارديو' : ''}',
                style: const TextStyle(fontSize: 11.5, color: C.muted),
              ),
            ),
          if (open) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _MiniField(
                    key: ValueKey('sets_${ex.id}'),
                    hint: 'مجموعات',
                    initial: ex.sets.toString(),
                    number: true,
                    onChanged: (v) {
                      // لازم مجموعة واحدة على الأقل، غير كده شاشة التمرين
                      // هتفضل فاضية للتمرين ده.
                      ex.sets = (int.tryParse(v) ?? ex.sets).clamp(1, 20);
                      store.saveDebounced();
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _MiniField(
                    key: ValueKey('reps_${ex.id}'),
                    hint: 'عدات',
                    initial: ex.reps,
                    onChanged: (v) {
                      ex.reps = v;
                      store.saveDebounced();
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _MiniField(
                    key: ValueKey('rest_${ex.id}'),
                    hint: 'راحة(ث)',
                    initial: ex.rest.toString(),
                    number: true,
                    onChanged: (v) {
                      ex.rest = (int.tryParse(v) ?? ex.rest).clamp(0, 900);
                      store.saveDebounced();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              runSpacing: 0,
              children: [
                _check('أوزان', ex.plates, (v) {
                  ex.plates = v;
                  store.saveDebounced();
                }),
                _check('أساسي (1RM)', ex.isMain, (v) {
                  ex.isMain = v;
                  store.saveDebounced();
                }),
                _check('⚡ سوبرست مع اللي بعده', ex.noRestAfter, (v) {
                  ex.noRestAfter = v;
                  store.saveDebounced();
                }),
                _check('🔥 بطن', ex.core, (v) {
                  ex.core = v;
                  store.saveDebounced();
                }),
                _check('🚴 كارديو', ex.cardio, (v) {
                  ex.cardio = v;
                  store.saveDebounced();
                }),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: C.panel,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: C.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ex.image != null
                      ? Image(
                          image: ex.image!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.broken_image_outlined,
                              color: C.muted,
                              size: 18),
                        )
                      : const Icon(Icons.photo_camera_outlined,
                          color: C.muted, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SButton('تغيير الصورة',
                      kind: BtnKind.secondary, small: true, onPressed: _pickImage),
                ),
                if (ex.hasImage) ...[
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: C.danger, size: 19),
                    onPressed: () =>
                        store.removeExerciseImage(widget.dayId, ex.id),
                  ),
                ] else if (kHasDefaultImage(ex.id)) ...[
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'رجّع الصورة الأصلية',
                    icon: const Icon(Icons.restore_rounded,
                        color: C.muted, size: 19),
                    onPressed: () => store.restoreDefaultExerciseImage(
                        widget.dayId, ex.id),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (widget.canMoveUp)
                  IconButton(
                    icon: const Icon(Icons.arrow_upward_rounded,
                        size: 18, color: C.muted),
                    onPressed: () {
                      final i = store.exerciseIndex(widget.dayId, ex.id);
                      store.reorderExercise(widget.dayId, i, i - 1);
                    },
                  ),
                if (widget.canMoveDown)
                  IconButton(
                    icon: const Icon(Icons.arrow_downward_rounded,
                        size: 18, color: C.muted),
                    onPressed: () {
                      final i = store.exerciseIndex(widget.dayId, ex.id);
                      store.reorderExercise(widget.dayId, i, i + 2);
                    },
                  ),
                const Spacer(),
                SButton('🗑 حذف التمرين',
                    kind: BtnKind.ghost,
                    small: true,
                    expand: false, onPressed: () async {
                  final idx = store.exerciseIndex(widget.dayId, ex.id);
                  final removed =
                      await store.deleteExercise(widget.dayId, ex.id);
                  if (removed != null) {
                    Fx.toastUndo('🗑 اتحذف تمرين "${removed.name}"',
                        () => store.restoreExercise(widget.dayId, idx, removed));
                  }
                }),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _check(String label, bool value, ValueChanged<bool> onChanged) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 26,
            height: 26,
            child: Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 2),
          Text(label, style: const TextStyle(fontSize: 11.5)),
        ],
      ),
    );
  }
}

bool kHasDefaultImage(String id) => kExerciseImages.containsKey(id);

/// خانة نص بتحفظ لما تخلص كتابة
class _InlineText extends StatefulWidget {
  final String initial;
  final ValueChanged<String> onChanged;
  final bool bold;
  const _InlineText({
    super.key,
    required this.initial,
    required this.onChanged,
    this.bold = false,
  });

  @override
  State<_InlineText> createState() => _InlineTextState();
}

class _InlineTextState extends State<_InlineText> {
  late final TextEditingController ctrl =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      style: TextStyle(
        fontSize: widget.bold ? 15 : 13.5,
        fontWeight: widget.bold ? FontWeight.w700 : FontWeight.w500,
        color: C.text,
      ),
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      ),
      onChanged: widget.onChanged,
    );
  }
}

class _MiniField extends StatefulWidget {
  final String hint;
  final String initial;
  final bool number;
  final ValueChanged<String> onChanged;
  const _MiniField({
    super.key,
    required this.hint,
    required this.initial,
    required this.onChanged,
    this.number = false,
  });

  @override
  State<_MiniField> createState() => _MiniFieldState();
}

class _MiniFieldState extends State<_MiniField> {
  late final TextEditingController ctrl =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      keyboardType: widget.number ? TextInputType.number : TextInputType.text,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 13, color: C.text),
      decoration: InputDecoration(
        hintText: widget.hint,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      ),
      onChanged: widget.onChanged,
    );
  }
}

/// بحث سريع عن تمرين بالاسم عبر كل أيام التدريب
class _ExerciseSearchBox extends StatefulWidget {
  const _ExerciseSearchBox();

  @override
  State<_ExerciseSearchBox> createState() => _ExerciseSearchBoxState();
}

class _ExerciseSearchBoxState extends State<_ExerciseSearchBox> {
  final ctrl = TextEditingController();
  String query = '';

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = <(WorkoutDay, ExerciseDef)>[];
    final q = query.trim();
    if (q.length >= 2) {
      for (final day in store.db.days) {
        for (final ex in day.exercises) {
          if (ex.name.toLowerCase().contains(q.toLowerCase())) {
            results.add((day, ex));
          }
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: TextField(
            controller: ctrl,
            style: const TextStyle(fontSize: 14, color: C.text),
            decoration: const InputDecoration(
              icon: Icon(Icons.search_rounded, color: C.muted, size: 20),
              hintText: '🔍 ابحث عن تمرين في كل الأيام...',
              border: InputBorder.none,
            ),
            onChanged: (v) => setState(() => query = v),
          ),
        ),
        if (q.length >= 2)
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 4),
            child: results.isEmpty
                ? const Text('مفيش نتائج مطابقة.',
                    style: TextStyle(fontSize: 12.5, color: C.muted))
                : Column(
                    children: results
                        .map((r) => SCard(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              onTap: () {
                                setState(() {
                                  query = '';
                                  ctrl.clear();
                                });
                                FocusScope.of(context).unfocus();
                                pushFade(
                                    context, DayDetailScreen(dayId: r.$1.id));
                              },
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(r.$2.name,
                                        style:
                                            const TextStyle(fontSize: 13.5)),
                                  ),
                                  Pill(r.$1.name, accent: true),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
          ),
      ],
    );
  }
}
