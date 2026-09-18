import 'dart:math';
import 'package:flutter/material.dart';

import 'theme.dart';

/// دفعة 7 — #3 Confetti عند PR
///
/// كونفيتي خفيف مبني بالكامل بـ CustomPainter (من غير أي مكتبة خارجية)
/// عشان يفضل التطبيق خفيف. كل قصاصة ليها سرعة وميل ودوران عشوائي،
/// وبتتلاشى (fade out) في آخر ثلث الأنيميشن.
class ConfettiOverlay extends StatefulWidget {
  final VoidCallback? onDone;
  const ConfettiOverlay({super.key, this.onDone});

  /// بيحقن الكونفيتي كطبقة فوق أي شاشة لمدة قصيرة ثم بيشيل نفسه.
  static void celebrate(BuildContext context) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: ConfettiOverlay(onDone: () => entry.remove()),
      ),
    );
    overlay.insert(entry);
  }

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _Particle {
  double x, y, vx, vy, rotation, vr, size;
  Color color;
  _Particle(this.x, this.y, this.vx, this.vy, this.rotation, this.vr,
      this.size, this.color);
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  final _rnd = Random();
  final _particles = <_Particle>[];

  static const _colors = [
    C.accent,
    C.good,
    Color(0xFFFFD166),
    Color(0xFF4CC9F0),
    Colors.white,
  ];

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone?.call();
      });
    for (var i = 0; i < 60; i++) {
      _particles.add(_Particle(
        0.5 + (_rnd.nextDouble() - 0.5) * 0.3,
        0.0,
        (_rnd.nextDouble() - 0.5) * 1.6,
        0.6 + _rnd.nextDouble() * 1.0,
        _rnd.nextDouble() * pi * 2,
        (_rnd.nextDouble() - 0.5) * 8,
        4 + _rnd.nextDouble() * 5,
        _colors[_rnd.nextInt(_colors.length)],
      ));
    }
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => CustomPaint(
        size: MediaQuery.of(context).size,
        painter: _ConfettiPainter(_particles, _c.value),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double t;
  _ConfettiPainter(this.particles, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final opacity = t < 0.66 ? 1.0 : (1 - (t - 0.66) / 0.34).clamp(0.0, 1.0);
    for (final p in particles) {
      // جاذبية بسيطة: العجلة الرأسية بتزيد مع الوقت
      final px = (p.x + p.vx * t) * size.width;
      final py = (p.y + p.vy * t + 0.9 * t * t) * size.height * 0.55;
      final rot = p.rotation + p.vr * t;
      final paint = Paint()
        ..color = p.color.withOpacity(opacity)
        ..style = PaintingStyle.fill;
      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(rot);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 1.7),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}
