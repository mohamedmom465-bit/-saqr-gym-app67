import 'dart:io';

import 'package:flutter/material.dart';

import 'theme.dart';

/// #15 Before/After Slider — قارن صورتين تقدّم بسحب خط في النص بدل
/// عرضهم جنب بعض بس. اسحب يمين/شمال أو دوس في أي مكان عشان تحرّك الخط.
class BeforeAfterSlider extends StatefulWidget {
  final File before;
  final File after;
  final String beforeLabel;
  final String afterLabel;
  const BeforeAfterSlider({
    super.key,
    required this.before,
    required this.after,
    required this.beforeLabel,
    required this.afterLabel,
  });

  @override
  State<BeforeAfterSlider> createState() => _BeforeAfterSliderState();
}

class _BeforeAfterSliderState extends State<BeforeAfterSlider> {
  double _pos = 0.5;

  void _setFromDx(double dx, double width) {
    if (width <= 0) return;
    setState(() => _pos = (dx / width).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          return ClipRRect(
            borderRadius: BorderRadius.circular(kRadius),
            child: Container(
              color: C.panel2,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _setFromDx(d.localPosition.dx, w),
                onHorizontalDragStart: (d) =>
                    _setFromDx(d.localPosition.dx, w),
                onHorizontalDragUpdate: (d) =>
                    _setFromDx(d.localPosition.dx, w),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(widget.after, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const _brokenImg()),
                    ClipRect(
                      clipper: _LeftClipper(_pos),
                      child: Image.file(widget.before,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const _brokenImg()),
                    ),
                    Positioned(
                      left: (_pos * w - 1).clamp(0.0, w - 2),
                      top: 0,
                      bottom: 0,
                      child: Container(width: 2, color: Colors.white70),
                    ),
                    Positioned(
                      left: (_pos * w - 16).clamp(-16.0, w - 16),
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black45,
                                  blurRadius: 6,
                                  offset: Offset(0, 2)),
                            ],
                          ),
                          child: const Icon(Icons.swap_horiz_rounded,
                              size: 18, color: Colors.black87),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _tag(widget.beforeLabel),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _tag(widget.afterLabel),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _tag(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
      );
}

class _brokenImg extends StatelessWidget {
  const _brokenImg();
  @override
  Widget build(BuildContext context) => Container(
        color: C.panel2,
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image_outlined, color: C.muted),
      );
}

class _LeftClipper extends CustomClipper<Rect> {
  final double pos;
  _LeftClipper(this.pos);
  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width * pos, size.height);
  @override
  bool shouldReclip(covariant _LeftClipper old) => old.pos != pos;
}
