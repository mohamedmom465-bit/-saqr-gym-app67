import 'package:flutter/material.dart';

import 'theme.dart';

/// عنصر #4 — Shimmer / Skeleton Loading
/// مجموعة Widgets عامة قابلة لإعادة الاستخدام في أي شاشة محتاجة "هيكل تحميل"
/// بدل الفراغ الأبيض أو الـ CircularProgressIndicator التقليدي.

/// يحرك تدرج لوني (Gradient) فوق أي Widget تاني بشكل لا نهائي —
/// ده اللي بيدي إحساس "اللمعة" الماشية على الصناديق وهي بتحمل.
class Shimmer extends StatefulWidget {
  final Widget child;
  const Shimmer({super.key, required this.child});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) => LinearGradient(
          colors: const [
            C.panel2,
            C.panel2,
            Color(0xFF3B4247),
            C.panel2,
            C.panel2,
          ],
          stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
          begin: const Alignment(-1, -0.1),
          end: const Alignment(1, 0.1),
          transform: _SlidingGradientTransform(_ctrl.value * 3 - 1.5),
        ).createShader(bounds),
        child: child,
      ),
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;
  const _SlidingGradientTransform(this.slidePercent);

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0, 0);
  }
}

/// صندوق أساسي رمادي بحواف دائرية — لبنة بناء أي Skeleton.
class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  const SkeletonBox({
    super.key,
    this.width = double.infinity,
    this.height = 14,
    this.radius = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: C.panel2,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// سطر نص وهمي — نفس SkeletonBox لكن بشكل مخصص للنصوص.
class SkeletonLine extends StatelessWidget {
  final double width;
  final double height;
  const SkeletonLine({super.key, this.width = double.infinity, this.height = 13});

  @override
  Widget build(BuildContext context) =>
      SkeletonBox(width: width, height: height, radius: 5);
}

/// كارت وهمي بنفس شكل SCard/_dayCard (أيقونة + سطرين) — يُستخدم في أي
/// قائمة بتتحمل (الرئيسية، تاريخ التمرين، إلخ).
class SkeletonListCard extends StatelessWidget {
  const SkeletonListCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: C.panel,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: C.border),
      ),
      child: Row(
        children: [
          const SkeletonBox(width: 42, height: 42, radius: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonLine(width: 130, height: 15),
                SizedBox(height: 8),
                SkeletonLine(width: 170, height: 11),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// شاشة الـ Skeleton اللي بتتعرض أول ما التطبيق يفتح لحد ما بيانات
/// المستخدم (store.init) تخلص تحميل — بديل احترافي للشاشة الفاضية/السبلاش.
/// نفس تخطيط الشاشة الرئيسية بالظبط عشان الانتقال بينها وبين الشاشة
/// الحقيقية يبقى سلس ومحسوس إنه نفس المكان.
class AppStartupSkeleton extends StatelessWidget {
  const AppStartupSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 4,
        leading: const Padding(
          padding: EdgeInsets.all(10),
          child: Shimmer(child: SkeletonBox(width: 40, height: 40, radius: 20)),
        ),
        title: const Shimmer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SkeletonLine(width: 90, height: 9),
              SizedBox(height: 6),
              SkeletonLine(width: 170, height: 16),
            ],
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: C.border),
        ),
      ),
      body: const Shimmer(
        child: _StartupSkeletonBody(),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: C.bg,
          border: Border(top: BorderSide(color: C.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              children: const [
                _NavPlaceholder('🏠', 'الرئيسية', active: true),
                _NavPlaceholder('📊', 'التقارير'),
                _NavPlaceholder('🧬', 'InBody'),
                _NavPlaceholder('⚙️', 'التعديل'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StartupSkeletonBody extends StatelessWidget {
  const _StartupSkeletonBody();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
      children: const [
        SkeletonLine(width: 220, height: 12),
        SizedBox(height: 18),
        SkeletonListCard(),
        SkeletonListCard(),
        SkeletonListCard(),
        SkeletonListCard(),
      ],
    );
  }
}

class _NavPlaceholder extends StatelessWidget {
  final String icon;
  final String label;
  final bool active;
  const _NavPlaceholder(this.icon, this.label, {this.active = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: TextStyle(fontSize: active ? 20 : 18)),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              color: active ? C.accent : C.muted,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
