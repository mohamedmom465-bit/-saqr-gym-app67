import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../data/analytics.dart';
import '../data/models.dart';
import '../data/providers.dart';
import '../data/store.dart';
import '../services/feedback.dart';
import '../ui/before_after_slider.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class InBodyScreen extends ConsumerStatefulWidget {
  const InBodyScreen({super.key});

  @override
  ConsumerState<InBodyScreen> createState() => _InBodyScreenState();
}

class _InBodyScreenState extends ConsumerState<InBodyScreen> {
  DateTime date = DateTime.now();
  final weight = TextEditingController();
  final fat = TextEditingController();
  final muscle = TextEditingController();
  final arm = TextEditingController();
  final chest = TextEditingController();
  final waist = TextEditingController();
  final thigh = TextEditingController();
  final notes = TextEditingController();

  final List<String> compare = [];
  bool sliderMode = true; // #15 Before/After Slider هي الوضع الافتراضي

  @override
  void dispose() {
    for (final c in [weight, fat, muscle, arm, chest, waist, thigh, notes]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _v(TextEditingController c) => double.tryParse(c.text.trim());

  Future<void> _add() async {
    if (_v(weight) == null && _v(fat) == null && _v(muscle) == null) {
      Fx.toast('اكتب الوزن على الأقل');
      return;
    }
    await store.addInbody(InBodyEntry(
      id: uid('ib'),
      date: date,
      weight: _v(weight),
      fat: _v(fat),
      muscle: _v(muscle),
      arm: _v(arm),
      chest: _v(chest),
      waist: _v(waist),
      thigh: _v(thigh),
      notes: notes.text.trim(),
    ));
    for (final c in [weight, fat, muscle, arm, chest, waist, thigh, notes]) {
      c.clear();
    }
    if (!mounted) return;
    setState(() => date = DateTime.now());
    Fx.toast('✅ اتحفظ القياس');
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: C.accent,
            surface: C.panel,
          ),
        ),
        child: child!,
      ),
    );
    if (d != null && mounted) setState(() => date = d);
  }

  Future<void> _addPhoto(ImageSource source) async {
    try {
      final x = await ImagePicker()
          .pickImage(source: source, maxWidth: 1400, imageQuality: 82);
      if (x == null) return;
      await store.addProgressPhoto(File(x.path));
      Fx.toast('✅ اتضافت صورة التقدم');
    } catch (e) {
      Fx.toast('⚠️ مقدرناش نفتح الصور، اتأكد من صلاحيات التطبيق');
    }
  }

  void _toggleCompare(String id) {
    setState(() {
      if (compare.contains(id)) {
        compare.remove(id);
      } else {
        compare.add(id);
        if (compare.length > 2) compare.removeAt(0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(gymStoreProvider);
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final sorted = [...store.db.inbody]
          ..sort((a, b) => b.date.compareTo(a.date));
        final latest = sorted.isNotEmpty ? sorted.first : null;
        final prev = sorted.length > 1 ? sorted[1] : null;
        final photos = [...store.db.photos]
          ..sort((a, b) => b.date.compareTo(a.date));
        final trend = Analytics.inbodyWeightTrend();

        return Scaffold(
          appBar: saqrAppBar(
              eyebrow: 'BODY COMPOSITION',
              title: 'بيانات InBody',
              showBack: false),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
            children: [
              SCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FieldLabel('التاريخ'),
                    InkWell(
                      onTap: _pickDate,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 13),
                        decoration: BoxDecoration(
                          color: C.panel2,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: C.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(fmtDate(date),
                                style: const TextStyle(fontSize: 14)),
                            const Icon(Icons.calendar_today_rounded,
                                size: 16, color: C.muted),
                          ],
                        ),
                      ),
                    ),
                    _numField('الوزن (كجم)', weight),
                    _numField('نسبة الدهون %', fat),
                    _numField('الكتلة العضلية (كجم)', muscle),
                    const SectionTitle('قياسات الجسم (اختياري، سم)', topGap: 16),
                    Row(children: [
                      Expanded(child: _numField('الزراع', arm, topGap: 0)),
                      const SizedBox(width: 10),
                      Expanded(child: _numField('الصدر', chest, topGap: 0)),
                    ]),
                    Row(children: [
                      Expanded(child: _numField('الوسط', waist)),
                      const SizedBox(width: 10),
                      Expanded(child: _numField('الفخذ', thigh)),
                    ]),
                    const FieldLabel('ملاحظات'),
                    TextField(
                      controller: notes,
                      maxLines: 2,
                      style: const TextStyle(fontSize: 14, color: C.text),
                    ),
                    const SizedBox(height: 14),
                    SButton('+ إضافة قياس', onPressed: _add),
                  ],
                ),
              ),

              if (latest != null) ...[
                const SectionTitle('آخر قياس'),
                StatGrid([
                  StatBox(latest.weight != null ? numStr(latest.weight!) : '-',
                      'الوزن (كجم)'),
                  StatBox(
                      latest.fat != null ? numStr(latest.fat!) : '-', 'دهون %'),
                  StatBox(latest.muscle != null ? numStr(latest.muscle!) : '-',
                      'عضلات (كجم)'),
                  StatBox(
                    (prev != null &&
                            latest.weight != null &&
                            prev.weight != null)
                        ? '${latest.weight! - prev.weight! >= 0 ? '+' : ''}${(latest.weight! - prev.weight!).toStringAsFixed(1)}'
                        : '-',
                    'فرق الوزن عن القياس السابق',
                  ),
                ]),
              ],

              if (trend.length >= 2) ...[
                const SectionTitle('تطور الوزن'),
                SCard(child: LineChartView(trend, suffix: 'كجم')),
              ],

              if (sorted.isNotEmpty) ...[
                const SectionTitle('سجل القياسات'),
                ...sorted.map(_entryCard),
              ] else
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: EmptyBox('لسه معملتش InBody. ضيف أول قياس فوق.'),
                ),

              const SectionTitle('📸 صور التقدم'),
              SCard(
                child: Row(
                  children: [
                    Expanded(
                      child: SButton('📷 كاميرا',
                          kind: BtnKind.secondary,
                          small: true,
                          onPressed: () => _addPhoto(ImageSource.camera)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SButton('🖼 من المعرض',
                          kind: BtnKind.secondary,
                          small: true,
                          onPressed: () => _addPhoto(ImageSource.gallery)),
                    ),
                  ],
                ),
              ),
              if (photos.isNotEmpty) ...[
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.78,
                  children: photos.map(_photoTile).toList(),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                      'دوس على صورتين عشان تقارن بينهم جنب بعض · اضغط مطوّل على أي صورة عشان تمسحها',
                      style: TextStyle(fontSize: 11.5, color: C.muted, height: 1.6)),
                ),
                if (compare.length == 2) _compareView(photos),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _numField(String label, TextEditingController c, {double topGap = 12}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: topGap, bottom: 6),
          child: Text(label,
              style: const TextStyle(fontSize: 12.5, color: C.muted)),
        ),
        TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 15, color: C.text),
        ),
      ],
    );
  }

  Widget _entryCard(InBodyEntry m) {
    final bits = <String>[];
    if (m.arm != null) bits.add('زراع ${numStr(m.arm!)}');
    if (m.chest != null) bits.add('صدر ${numStr(m.chest!)}');
    if (m.waist != null) bits.add('وسط ${numStr(m.waist!)}');
    if (m.thigh != null) bits.add('فخذ ${numStr(m.thigh!)}');

    return SCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(fmtDateShort(m.date),
                  style: const TextStyle(fontSize: 13.5)),
              Row(
                children: [
                  Pill(
                      '${m.weight != null ? numStr(m.weight!) : '-'}kg · ${m.fat != null ? numStr(m.fat!) : '-'}% · ${m.muscle != null ? numStr(m.muscle!) : '-'}kg'),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 34),
                    icon: const Icon(Icons.close_rounded,
                        size: 17, color: C.muted),
                    onPressed: () async {
                      final removed = await store.deleteInbody(m.id);
                      if (removed != null) {
                        Fx.toastUndo('🗑 اتحذف القياس',
                            () => store.addInbody(removed));
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          if (bits.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('${bits.join(' · ')} سم',
                  style: const TextStyle(fontSize: 12, color: C.muted)),
            ),
          if (m.notes.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(m.notes,
                  style: const TextStyle(
                      fontSize: 12, color: C.muted, height: 1.6)),
            ),
        ],
      ),
    );
  }

  Widget _photoTile(ProgressPhoto p) {
    final selected = compare.contains(p.id);
    return GestureDetector(
      onTap: () => _toggleCompare(p.id),
      onLongPress: () async {
        final ok = await confirmDialog(context, 'تأكيد حذف الصورة دي؟',
            danger: true);
        if (ok) {
          compare.remove(p.id);
          await store.deletePhoto(p.id);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? C.accent : C.border, width: selected ? 2.5 : 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(File(p.path), fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                        color: C.panel2,
                        child: const Icon(Icons.broken_image_outlined,
                            color: C.muted),
                      )),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.black54,
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(fmtDateShort(p.date),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 10, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _compareView(List<ProgressPhoto> photos) {
    final p1 = photos.firstWhere((p) => p.id == compare[0],
        orElse: () => photos.first);
    final p2 = photos.firstWhere((p) => p.id == compare[1],
        orElse: () => photos.first);
    final ordered = p1.date.isBefore(p2.date) ? [p1, p2] : [p2, p1];
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('🔀 سلايدر', style: TextStyle(fontSize: 12)),
                selected: sliderMode,
                onSelected: (_) => setState(() => sliderMode = true),
                selectedColor: C.accent,
                backgroundColor: C.panel2,
                labelStyle: TextStyle(
                    color: sliderMode ? Colors.white : C.text),
                side: const BorderSide(color: C.border),
              ),
              ChoiceChip(
                label: const Text('⬜ جنب بعض', style: TextStyle(fontSize: 12)),
                selected: !sliderMode,
                onSelected: (_) => setState(() => sliderMode = false),
                selectedColor: C.accent,
                backgroundColor: C.panel2,
                labelStyle: TextStyle(
                    color: !sliderMode ? Colors.white : C.text),
                side: const BorderSide(color: C.border),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (sliderMode)
            BeforeAfterSlider(
              before: File(ordered[0].path),
              after: File(ordered[1].path),
              beforeLabel: fmtDateShort(ordered[0].date),
              afterLabel: fmtDateShort(ordered[1].date),
            )
          else
            Row(
              children: ordered
                  .map((p) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child:
                                    Image.file(File(p.path), fit: BoxFit.cover),
                              ),
                              const SizedBox(height: 6),
                              Text(fmtDateShort(p.date),
                                  style: const TextStyle(
                                      fontSize: 11, color: C.muted)),
                            ],
                          ),
                        ),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }
}
