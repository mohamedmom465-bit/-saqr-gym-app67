import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// دفعة 7 — #1 انتقالات Hero/Fade+Scale + #7 Physics-based animations
///
/// بدل الانتقال الافتراضي (Slide من الشمال) بتاع MaterialPageRoute،
/// الشاشة الجديدة بتدخل بـ Fade + Scale خفيف (من 0.96 لـ 1.0) بإحساس
/// "نابض" شوية بدل الخط المستقيم العادي — عن طريق منحنى Spring حقيقي
/// (SpringSimulation) بدل Curve ثابت، فالحركة بتحس طبيعية زي ما بتتحرك
/// حاجة فعلية ليها كتلة واحتكاك مش انتقال متحرك بمعادلة رياضية بس.
class FadeScaleRoute<T> extends PageRouteBuilder<T> {
  FadeScaleRoute({required WidgetBuilder builder, super.settings})
      : super(
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 220),
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: _SpringCurve(),
              reverseCurve: Curves.easeIn,
            );
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween(begin: 0.96, end: 1.0).animate(curved),
                child: child,
              ),
            );
          },
        );
}

/// منحنى مبني على محاكاة نابض (Spring) حقيقية بدل Curve رياضي جاهز،
/// عشان الحركة تحس طبيعية أكتر (overshoot بسيط جدًا بعدين استقرار).
class _SpringCurve extends Curve {
  static final SpringSimulation _sim = SpringSimulation(
    const SpringDescription(mass: 1, stiffness: 300, damping: 22),
    0,
    1,
    0,
  );

  @override
  double transform(double t) => _sim.x(t * 0.5);
}

Future<T?> pushFade<T>(BuildContext context, Widget page) {
  return Navigator.push<T>(
    context,
    FadeScaleRoute<T>(builder: (_) => page),
  );
}

Future<T?> pushReplaceFade<T, TO>(BuildContext context, Widget page) {
  return Navigator.pushReplacement<T, TO>(
    context,
    FadeScaleRoute<T>(builder: (_) => page),
  );
}
