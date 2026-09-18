import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// عنصر #5 — Progress Ring
/// حلقة تقدّم دائرية بتتحرك بسلاسة لأي نسبة (0 → 1)، بنفس هوية ألوان
/// التطبيق. مستخدمة حاليًا لتقدّم مجموعات التمرين الشغال، وقابلة
/// لإعادة الاستخدام في أي مكان تاني محتاج يوري نسبة إنجاز بشكل دائري.
class ProgressRing extends StatelessWidget {
  /// نسبة من 0 لـ 1.
  final double progress;
  final double size;
  final double strokeWidth;
  final Color color;
  final Color trackColor;

  /// المحتوى اللي بيتحط في نص الحلقة (رقم، نسبة، أيقونة...).
  final Widget? center;

  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 64,
    this.strokeWidth = 7,
    this.color = C.accent,
    this.trackColor = C.panel2,
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        // انتقال ناعم بين النسبة القديمة والجديدة بدل ما القيمة تقفز
        // فجأة كل ما تسجل مجموعة.
        tween: Tween(begin: 0, end: clamped),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) {
          return CustomPaint(
            painter: _RingPainter(
              progress: value,
              color: color,
              trackColor: trackColor,
              strokeWidth: strokeWidth,
            ),
            child: center == null
                ? null
                : Center(child: center),
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawArc(rect, 0, 2 * math.pi, false, track);

    if (progress <= 0) return;
    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    // بيبدأ من فوق (12 الساعة) وبيلف مع عقارب الساعة.
    const start = -math.pi / 2;
    canvas.drawArc(rect, start, 2 * math.pi * progress, false, arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) {
    return old.progress != progress ||
        old.color != color ||
        old.trackColor != trackColor ||
        old.strokeWidth != strokeWidth;
  }
}
