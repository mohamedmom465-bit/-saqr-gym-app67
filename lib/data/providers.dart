import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'store.dart';

/// دفعة 10 — Riverpod: بوابة الوصول لنفس الـ GymStore (singleton) اللي
/// التطبيق كله شغال بيه، بس دلوقتي عن طريق ProviderScope بدل ما كل شاشة
/// تعتمد على AnimatedBuilder يدوي. الشاشات بتعمل:
///   ref.watch(gymStoreProvider);
/// عشان تتربط بأي تغيير في البيانات وتتبني تاني تلقائي.
final gymStoreProvider = ChangeNotifierProvider<GymStore>((ref) => store);
