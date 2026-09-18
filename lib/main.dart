import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/providers.dart';
import 'data/session_controller.dart';
import 'data/store.dart';
import 'screens/home_screen.dart';
import 'screens/inbody_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';
import 'services/feedback.dart';
import 'services/notifications.dart';
import 'ui/bouncy.dart';
import 'ui/skeleton.dart';
import 'ui/theme.dart';

/// كل حاجة التطبيق محتاج يحملها قبل ما يبقى جاهز للاستخدام: بيانات
/// المستخدم (store) + استرجاع أي جلسة تمرين كانت شغالة ووقفت فجأة.
/// بنمسك الـ Future دي في متغير واحد عشان نقدر نعرض شاشة الـ
/// Skeleton (#4) طول ما هي شغالة، بدل ما الواجهة توقف بالكامل لحدها.

Future<void> _bootstrap() async {
  await store.init();
  // لو فيه جلسة تمرين كانت شغالة ووقفت فجأة (قفل التطبيق، نفدت
  // الذاكرة...)، رجّعها هنا بالظبط بنفس دقة التوقيت قبل ما الواجهة تتبني.
  await sessionCtrl.restoreIfAny();
  // دفعة 9 — #18: تجهيز طبقة الإشعارات + إعادة بناء جدول تذكير التمرين
  // (بيتأكد إن مفيش تذكيرات فاتت أو محتاجة تتلغي لو المستخدم سجّل
  // تمرين وهو التطبيق مقفول عن طريق الـ Quick-log مثلًا).
  try {
    await NotificationService.instance.init();
    await NotificationService.instance.rescheduleReminders();
  } catch (e) {
    debugPrint('notifications bootstrap error: $e');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: C.bg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  // مسجّل مرة واحدة طول عمر التطبيق عشان يقدر يحفظ حالة الجلسة فورًا
  // أي لحظة التطبيق يروح الخلفية أو يتقفل، مش بس وهو شغال.
  WidgetsBinding.instance.addObserver(sessionCtrl);
  // دفعة 10 — Riverpod: ProviderScope هو جذر إدارة الحالة الجديد للتطبيق.
  runApp(const ProviderScope(child: SaqrGymApp()));
}

class SaqrGymApp extends StatefulWidget {
  const SaqrGymApp({super.key});

  @override
  State<SaqrGymApp> createState() => _SaqrGymAppState();
}

class _SaqrGymAppState extends State<SaqrGymApp> {
  late Future<void> _startup;

  @override
  void initState() {
    super.initState();
    _startup = _bootstrap();
  }

  void _retryStartup() {
    setState(() {
      _startup = _bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SAQR GYM',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: messengerKey,
      theme: buildTheme(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
      home: FutureBuilder<void>(
        future: _startup,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const AppStartupSkeleton();
          }
          if (snap.hasError) {
            return StartupFailure(
              error: snap.error,
              onRetry: _retryStartup,
            );
          }
          return const RootShell();
        },
      ),
    );
  }
}

class StartupFailure extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;

  const StartupFailure({
    super.key,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('⚠️', style: TextStyle(fontSize: 42)),
                  const SizedBox(height: 14),
                  const Text(
                    'التطبيق لم يكتمل تشغيله',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: C.text,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'حصل خطأ أثناء تجهيز البيانات. لم يتم استبدال قاعدة البيانات ببيانات افتراضية حفاظًا على بياناتك.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: C.muted, fontSize: 13, height: 1.7),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: C.danger,
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: onRetry,
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RootShell extends ConsumerStatefulWidget {
  const RootShell({super.key});

  @override
  ConsumerState<RootShell> createState() => _RootShellState();
}

class _RootShellState extends ConsumerState<RootShell> {
  int index = 0;

  // دفعة 10 / #28 Lazy Loading: كل تاب بيتبني أول مرة بس لما المستخدم يفتحه،
  // مش الأربعة مع بعض من أول ما التطبيق يفتح. بعد أول زيارة بيفضل محفوظ
  // (IndexedStack) عشان ما يتفقدش حالته لو رجع تاني.
  final List<Widget?> _built = List<Widget?>.filled(4, null);

  static const _factories = <Widget Function()>[
    HomeScreen.new,
    ReportsScreen.new,
    InBodyScreen.new,
    SettingsScreen.new,
  ];

  Widget _tab(int i) => _built[i] ??= _factories[i]();

  @override
  Widget build(BuildContext context) {
    // بيربط الشاشة بأي تغيير في GymStore عبر Riverpod بدل الاعتماد على
    // AnimatedBuilder يدوي فقط.
    ref.watch(gymStoreProvider);
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: List.generate(
            4, (i) => i == index ? _tab(i) : (_built[i] ?? const SizedBox.shrink())),
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
              children: [
                _navItem(0, '🏠', 'الرئيسية'),
                _navItem(1, '📊', 'التقارير'),
                _navItem(2, '🧬', 'InBody'),
                _navItem(3, '⚙️', 'التعديل'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int i, String icon, String label) {
    final active = index == i;
    // دفعة 7 — #7 Physics-based animations: التبديل بين التابات بقى
    // بنطّة نابضية خفيفة بدل التغيير الفوري، وبرضه بيدي إحساس لمس حقيقي.
    return Expanded(
      child: BouncyTap(
        intensity: 0.35,
        onTap: () => setState(() => index = i),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: active ? 1.12 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: Text(icon, style: TextStyle(fontSize: active ? 20 : 18)),
            ),
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
      ),
    );
  }
}
