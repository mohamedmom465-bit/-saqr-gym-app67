import 'package:flutter/material.dart';

import 'theme.dart';

/// عنصر #35 — كيبورد أرقام كبير
/// بديل لكيبورد النظام الصغير وقت تسجيل الوزن/العدات جوه التمرين —
/// أزرار كبيرة سهل تدوس عليها الصح حتى لو إيدك بتعرق أو وانت لاهث،
/// وبيفضل شكل شاشة التمرين واحد، مش الكيبورد الافتراضي بتاع النظام
/// اللي بيغطي نص الشاشة وحروفه صغيرة على رقم/حرف واحد.

/// معلومات الحقل اللي حاليًا بيتاخد فيه إدخال من الكيبورد الكبير.
class KeypadTarget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool decimal;
  const KeypadTarget({
    required this.controller,
    required this.onChanged,
    this.decimal = false,
  });
}

/// جسر مشترك بين أي TextField جوه الشاشة والـ Keypad اللي هيتعرض في
/// أسفل الشاشة — نفس فكرة store/sessionCtrl الـ singletons الموجودة
/// بالفعل في التطبيق.
class KeypadBridge extends ChangeNotifier {
  KeypadTarget? active;

  void attach(KeypadTarget target) {
    active = target;
    notifyListeners();
  }

  /// يقفل الكيبورد. لو اتبعت target بيتأكد إنه هو نفسه المفتوح حاليًا
  /// (عشان صف اتقفل/اتمسح ميقفلش كيبورد صف تاني فتحه المستخدم بعده).
  void release([TextEditingController? forController]) {
    if (forController != null &&
        !identical(active?.controller, forController)) {
      return;
    }
    active = null;
    notifyListeners();
  }

  void _apply(String Function(String current) transform) {
    final t = active;
    if (t == null) return;
    final newValue = transform(t.controller.text);
    t.controller.value = TextEditingValue(
      text: newValue,
      selection: TextSelection.collapsed(offset: newValue.length),
    );
    t.onChanged(newValue);
    notifyListeners();
  }

  void tapDigit(String d) {
    _apply((cur) {
      if (cur == '0') return d;
      // حد أقصى منطقي لعدد الخانات عشان محدش يكتب رقم بلا معنى بالغلط
      if (cur.replaceAll('.', '').length >= 5) return cur;
      return cur + d;
    });
  }

  void tapDot() {
    final t = active;
    if (t == null || !t.decimal) return;
    _apply((cur) {
      if (cur.isEmpty) return '0.';
      if (cur.contains('.')) return cur;
      return '$cur.';
    });
  }

  void backspace() {
    _apply((cur) => cur.isEmpty ? cur : cur.substring(0, cur.length - 1));
  }

  void clear() => _apply((_) => '');
}

/// نسخة واحدة تعيش طول عمر التطبيق، زي store و sessionCtrl بالظبط.
final keypadBridge = KeypadBridge();

/// شريط الكيبورد نفسه — بيتحط مكان أي شريط تاني في أسفل الشاشة (زي
/// bottomNavigationBar) طول ما فيه حقل مفتوح، وبيرجع الشريط الأصلي
/// تاني أول ما المستخدم يدوس "تم".
class BigKeypadBar extends StatelessWidget {
  const BigKeypadBar({super.key});

  @override
  Widget build(BuildContext context) {
    final target = keypadBridge.active;
    final decimal = target?.decimal ?? false;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: const BoxDecoration(
          color: C.panel,
          border: Border(top: BorderSide(color: C.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.dialpad_rounded, size: 16, color: C.muted),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text('اكتب الرقم',
                      style: TextStyle(fontSize: 12, color: C.muted)),
                ),
                InkWell(
                  onTap: keypadBridge.release,
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Text('تم ✓',
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: C.accent)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _keyRow(const ['1', '2', '3']),
            const SizedBox(height: 8),
            _keyRow(const ['4', '5', '6']),
            const SizedBox(height: 8),
            _keyRow(const ['7', '8', '9']),
            const SizedBox(height: 8),
            _keyRow([decimal ? '.' : '', '0', '⌫']),
          ],
        ),
      ),
    );
  }

  Widget _keyRow(List<String> keys) {
    return Row(
      children: keys
          .map((k) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _KeypadKey(label: k),
                ),
              ))
          .toList(),
    );
  }
}

class _KeypadKey extends StatelessWidget {
  final String label;
  const _KeypadKey({required this.label});

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox(height: 52);
    final isBackspace = label == '⌫';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (isBackspace) {
            keypadBridge.backspace();
          } else if (label == '.') {
            keypadBridge.tapDot();
          } else {
            keypadBridge.tapDigit(label);
          }
        },
        onLongPress: isBackspace ? keypadBridge.clear : null,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: C.panel2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: C.border),
          ),
          child: isBackspace
              ? const Icon(Icons.backspace_outlined, size: 18, color: C.text)
              : Text(label,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: C.text)),
        ),
      ),
    );
  }
}
