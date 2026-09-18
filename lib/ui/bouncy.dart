import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// دفعة 7 — #2 Bounce لزر "تم" + #7 Physics-based animations
///
/// غلاف عام لأي عنصر تحب تديله إحساس "نطّة" حقيقية لما يتلمس، مبني على
/// SpringSimulation (كتلة + تيبّس + احتكاك) بدل Tween/Curve عادي، فالحجم
/// بيعدي 1.0 شوية (overshoot) بعدين يرجع يستقر — بالظبط زي حاجة مطاطية
/// فعلية، مش أنيميشن خطي. بيتحكم في نسبة الـ overshoot عن طريق [intensity].
class BouncyTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  /// من 0 لـ 1: مقدار "النطّة" — استخدم قيمة أعلى للحظات الاحتفال
  /// (زي خلاص مجموعة أو رقم قياسي) وأقل للمس العادي.
  final double intensity;

  const BouncyTap({
    super.key,
    required this.child,
    this.onTap,
    this.intensity = 0.5,
  });

  @override
  State<BouncyTap> createState() => _BouncyTapState();
}

class _BouncyTapState extends State<BouncyTap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  double _scale = 1.0;

  @override
  void initState() {
    super.initState();
    _c = AnimationController.unbounded(vsync: this, value: 1.0)
      ..addListener(() => setState(() => _scale = _c.value));
  }

  void _bounce() {
    final overshoot = 1.0 + 0.14 * widget.intensity.clamp(0, 1);
    final sim = SpringSimulation(
      SpringDescription(
        mass: 1,
        stiffness: 380,
        damping: 14 - (4 * widget.intensity.clamp(0, 1)),
      ),
      0.85, // بداية الانضغاط الخفيف عند اللمس
      1.0,
      0,
    );
    _c
      ..stop()
      ..animateWith(_SimWithOvershoot(sim, overshoot));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap == null
          ? null
          : () {
              _bounce();
              widget.onTap!();
            },
      onTapDown: widget.onTap == null
          ? null
          : (_) => setState(() => _scale = 0.94),
      onTapCancel: () => setState(() => _scale = 1.0),
      child: Transform.scale(scale: _scale, child: widget.child),
    );
  }
}

/// يلف Simulation عادية بس يسمح للقيمة تتعدى 1.0 مؤقتًا (overshoot)
/// قبل ما تستقر، عشان إحساس النطّة يبان بصريًا مش بس رياضيًا.
class _SimWithOvershoot extends Simulation {
  final SpringSimulation base;
  final double peak;
  _SimWithOvershoot(this.base, this.peak);

  @override
  double x(double time) {
    final v = base.x(time);
    // أول 220 مللي ثانية بيتمدد فوق 1.0 بنسبة الـ peak بعدين يرجع يستقر
    if (time < 0.22) {
      final t = time / 0.22;
      final bump = (peak - 1.0) * (1 - (t - 1) * (t - 1));
      return v + bump;
    }
    return v;
  }

  @override
  double dx(double time) => base.dx(time);

  @override
  bool isDone(double time) => base.isDone(time);
}
