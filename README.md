# SAQR GYM — نسخة Flutter (Native) 2.0

تطبيق Native حقيقي (مش غلاف لموقع) فيه **كل** مميزات نسخة الـ HTML، بنفس التصميم
الداكن والبرتقالي، وبنفس البرنامج (5 أيام + سيشن بطن + سيشن كارديو).

---

## المميزات الموجودة

### الرئيسية
- تحية حسب الوقت وحالة التمرين
- بانر الأيام المتتالية (Streak) 🔥
- تذكير بالنسخة الاحتياطية لو بقالك أسبوع من غير ما تاخد واحدة
- بانر "التمرين لسه شغال" عشان تكمل من حيث ما وقفت لو خرجت من الشاشة
- كروت أيام التدريب + آخر مرة اتعمل فيها اليوم ده

### تفاصيل اليوم
- الوقت المتوقع للتمرين (محسوب من العدات والراحة ووقت تركيب الأوزان)
- تقسيم تلقائي لسيشن البطن 🔥 وسيشن الكارديو 🚴
- زرار "شكل التمرين" بيفتح الصورة المرجعية (واضغط عليها تكبر)
- آخر أداء مسجّل لكل تمرين + شارة 🏆 PR

### الجلسة الشغالة
- تايمر التمرين الكلي
- تايمر راحة تلقائي بعد كل مجموعة + زرار **+30 ثانية** و**تخطي الراحة**
- **الفتح التدريجي**: المجموعة/التمرين اللي بعده بيتفتح لما تخلص اللي قبله، واللي اتفتح ما بيتقفلش تاني
- ملء تلقائي لأوزان آخر مرة، و**زيادة 2.5كجم تلقائي** لو كملت كل مجموعاتك آخر مرة
- ستيبر ‎−/+ 2.5كجم لكل مجموعة
- 🏋 **حاسبة الأطباق**: بتقولك تحط إيه على كل جنب حسب وزن البار بتاعك
- 📝 ملاحظة سريعة لكل مجموعة
- 🔽 **دروب سيت** بوزن أقل ~20% من غير راحة
- 🔄 تبديل اسم التمرين للجلسة دي بس (البرنامج الأساسي ما بيتغيرش)
- ⚡ دعم السوبرست (من غير راحة بين التمرينين)
- احتفال فوري بالرقم القياسي وسط التمرين (اهتزاز + تنبيه)
- تذكير شرب المية كل X دقيقة
- الشاشة بتفضل مفتوحة طول التمرين

### تقييم التمرين
- تقييم عام من 1 لـ 10 + تقييم لكل تمرين لوحده + ملاحظات
- كشف الأرقام القياسية وتسجيلها مع الجلسة

### التقارير
- حجم التمرين الأسبوعي (وزن × عدات × مجموعات) مع نسبة التغير عن الأسبوع اللي فات
- خريطة الانتظام لآخر 8 أسابيع
- مدة الجلسات (آخر 10) والمتوسط
- وزن الجسم من الـ InBody
- تقدير 1RM باستخدام متوسط ثلاث معادلات (Epley / Brzycki / Lombardi) للتمارين المعلّمة "أساسي" مع سهم الاتجاه
- عدد مرات كل يوم تدريب + التمارين الناقصة (آخر 30 يوم)
- آخر الجلسات — **واضغط على أي جلسة تشوف كل مجموعة سجلتها فيها** (جديد)

### InBody
- وزن / دهون / عضلات + مقاسات (زراع، صدر، وسط، فخذ) + ملاحظات
- آخر قياس والفرق عن اللي قبله + رسم تطور الوزن
- 📸 صور التقدم بالكاميرا أو من المعرض، دوس على صورتين عشان تقارن، واضغط مطوّل عشان تمسح

### التعديل
- كل الإعدادات: تذكير المية، وقت الانتقال، وزن البار، الزيادة التلقائية، الصوت، الاهتزاز، التنبيهات، الشاشة المفتوحة
- محرر كامل للأيام والتمارين: الاسم، المجموعات، العدات، الراحة، أوزان/أساسي/سوبرست/بطن/كارديو
- ترتيب التمارين فوق وتحت، وإضافة/حذف مع **تراجع ↩**
- تغيير صورة أي تمرين (أو رجوع الصورة الأصلية)
- نسخ احتياطية: مشاركة / حفظ على الجهاز عبر مدير الملفات / استيراد من ملف JSON مباشرة + نسخ تلقائية محلية

---

## البيانات

كل حاجة متخزنة على الجهاز (مفيش سيرفر). قاعدة البيانات الأساسية SQLite (Drift)،
وصور المستخدم بتتخزن كملفات جوه فولدر التطبيق مش base64.

النسخ التلقائية المحلية لا تعيد تسلسل قاعدة البيانات داخل SharedPreferences؛
بتاخد SQLite snapshot حقيقي وتحتفظ بآخر 3 snapshots، بينما SharedPreferences
يحتفظ بالـmetadata والمسارات فقط. النسخة اليدوية JSON تظل portable بين الأجهزة
وتضمّن صور المستخدم كـbase64 عند الحاجة.

**الاستيراد شغال مع ملفات النسخ الاحتياطي القديمة بتاعة نسخة الويب** — بيفك الصور
من base64 ويحوّلها لملفات تلقائيًا.

---

## دفعة 7 — Visual / Gamification

- **#1 انتقالات Hero/Fade+Scale**: كل تنقل بين الشاشات بقى Fade + Scale
  خفيف مبني على محاكاة نابض حقيقية (`lib/ui/transitions.dart`، دالتين
  `pushFade` / `pushReplaceFade`) بدل الـ Slide الافتراضي.
- **#2 Bounce لزر "تم"**: زرار تسجيل المجموعة بقى بينط لما يتلمس
  (`lib/ui/bouncy.dart` — `BouncyTap`)، وبنطّة أقوى لو المجموعة دي هتحقق
  رقم قياسي.
- **#3 Confetti عند PR**: كونفيتي مرسوم بالكامل بـ `CustomPainter` (من
  غير أي مكتبة خارجية) بيظهر لحظة ما تسجل رقم قياسي وسط التمرين، وكمان
  عند حفظ التمرين لو فيه رقم قياسي/إنجاز/ترقية مستوى (`lib/ui/confetti.dart`).
- **#6 Haptic Feedback متدرج**: `Fx.graduatedVibe(tier)` في
  `lib/services/feedback.dart` — 4 مستويات من الاهتزاز حسب حجم الإنجاز.
- **#7 Physics-based animations**: نفس `BouncyTap` وانتقال الشاشات
  مبنيين على `SpringSimulation` حقيقية (كتلة + تيبّس + احتكاك) مش
  Curve/Tween عادي، وكمان تبويبات الشاشة الرئيسية بقى ليها بنطّة خفيفة.
- **#19 Levels/Badges**: نظام مستويات كامل (`lib/data/gamification.dart`)
  محسوب من نقاط خبرة (حجم التمرين + عدد الجلسات + الأرقام القياسية) —
  كارت المستوى ظاهر في الرئيسية وبيودّي لشاشة تفصيلية.
- **#20 Achievements**: 14 إنجاز (أول تمرين، ستريك، أرقام قياسية، حجم
  تراكمي، InBody، صور تقدّم...) كلها بتتحسب لحظيًا من بياناتك الموجودة —
  مفيش أي حقل جديد أو Migration في الـ DB. شاشة جديدة `AchievementsScreen`
  بتوريها كلها (مفتوحة/مقفولة مع نسبة التقدّم).

كل عناصر دفعة 7 بتتفعّل تلقائي، ومفيش إعداد إضافي مطلوب.

---

## دفعة 8 — Analytics

- **#14 Interactive Charts**: كل رسم بياني خطي (`LineChartView` في
  `lib/ui/widgets.dart`) بقى بيستجيب للمس — دوس أو اسحب على أي نقطة
  عشان تشوف تولتيب فوقها فيه التاريخ والقيمة بالظبط، مع خط رأسي متقطع
  يوريك مكان النقطة. بيشتغل في كل الرسومات (حجم أسبوعي، مدة الجلسات،
  وزن InBody...) من غير أي تغيير في مكان استخدامها.
- **#16 Monthly Workout Calendar**: شاشة جديدة `CalendarScreen`
  (`lib/screens/calendar_screen.dart`) — تقويم شهر كامل بينقّل بالسهم،
  كل يوم فيه تمرين عليه نقطة (لون مختلف لو فيه رقم قياسي 🏆)، ودوس
  على اليوم يفتحلك الجلسة على طول (أو يوريك قائمة لو فيه أكتر من جلسة
  في نفس اليوم). الوصول ليها من زرار 📅 في هيدر شاشة "التقارير".
- **#13 Smart Recommendations**: قسم "🧠 توصيات ذكية" أول شاشة
  التقارير، محسوب بالكامل من تحليلات موجودة بالفعل
  (`Analytics.smartRecommendations` في `lib/data/analytics.dart`):
  تغيّر حجم التمرين الأسبوعي، اقتراح Deload، الستريك الطويل، تمارين
  متجاهلة كتير، وفترة طويلة من غير تمرين — كله بيتحدّث لحظيًا من غير
  أي حقل جديد في الـ DB.
- **#15 Before/After Slider**: مقارنة صور التقدم في شاشة InBody بقت
  بسلايدر تقدر تسحبه يمين وشمال عشان تشوف الفرق بالظبط مكان ما تحب
  (`BeforeAfterSlider` في `lib/ui/before_after_slider.dart`)، مع خيار
  ترجع للعرض القديم "جنب بعض" من نفس الشاشة.

---

## دفعة 9 — Daily Automation

- **#18 Push Notifications**: طبقة إشعارات نظام حقيقية (`lib/services/notifications.dart`)
  مبنية على `flutter_local_notifications` — بتظهر حتى لو التطبيق مقفول
  تمامًا (مش زي التنبيهات الداخلية اللي كانت موجودة قبل كده واللي
  بتحتاج التطبيق يكون فاتح). بتطلب صلاحية الإشعارات وقت ما تفعّل
  التذكير من الإعدادات، مش تلقائي عند فتح التطبيق.
- **#40 Workout Reminder**: تذكير يومي بميعاد تحدده بنفسك من شاشة
  "التعديل ← 🔔 تذكير التمرين"، بيتجدول لأقرب 14 يوم وبيتحدّث تلقائي كل
  ما تفتح التطبيق أو تخلّص تمرين — لو أنت أصلًا سجلت تمرين النهارده
  (يدوي أو Quick-log)، التذكير بتاع النهارده بيتلغي لوحده من غير أي
  تدخل. النص بيقترح "الدور الجاي" من أيامك (Round-robin بعد آخر يوم
  اتعمل، لأن مفيش جدول أسبوعي ثابت في التطبيق أصلًا).
- **#42 Quick-log من الإشعار**: زرار "✅ سجّلت النهارده" جوه إشعار
  التذكير نفسه (تقدر تقفله من الإعدادات لو مش عايزه) — بيسجّل جلسة
  كاملة لتمرين "الدور الجاي" بنفس منطق ملء الأوزان العادي (آخر وزن +
  الزيادة/التخفيف التلقائي)، **من غير ما تفتح التطبيق خالص** — حتى لو
  كان مقفول تمامًا (بيشتغل جوه isolate خلفية منفصلة). بعد التسجيل بيجيلك
  إشعار تأكيد، وتقدر تفتح التطبيق بعدها تعدّل أي حاجة عادي.
- **#43 Calories Estimate**: تقدير تقريبي للسعرات المحروقة (معادلة MET
  حسب نوع كل تمرين — حديد/بطن/كارديو — ومدة الجلسة الحقيقية ووزن جسمك
  من آخر قياس InBody، أو وزن افتراضي تحدده من الإعدادات لو معملتش
  InBody خالص). ظاهر في شاشة تقييم التمرين، تفاصيل أي جلسة قديمة، ورسم
  بياني أسبوعي جديد في "التقارير".

**ملاحظة بناء مهمة**: ميزة الإشعارات النظامية مفعّلة فعلًا في التطبيق، بما فيها التذكير المجدول وQuick-log من الإشعار حتى لو التطبيق مقفول. مكتبة `flutter_local_notifications: ^18.0.1` تتطلب Core Library Desugaring، لذلك لم نترك هذا كإعداد يدوي: سكربتا `tool\bootstrap.bat` و`tool\build_apk.bat`، وكذلك GitHub Actions، يشغّلون `tool/configure_android.ps1` بعد `flutter create` لإضافة إعداد الـdesugaring تلقائيًا. كما يتم إضافة صلاحيات الكاميرا وWake Lock والإشعارات وإعادة الجدولة بعد إعادة التشغيل، وReceivers المطلوبة للإشعارات المجدولة وQuick-log. `tool/verify_android_setup.ps1` يوقف البناء إذا كان أي إعداد مطلوب ناقصًا. هذا يتوافق مع متطلبات `flutter_local_notifications` الرسمية.

الإشعارات المجدولة تستخدم `AndroidScheduleMode.inexactAllowWhileIdle`، لذلك لا نطلب `SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM`؛ لا توجد حاجة لصلاحية المنبهات الدقيقة في هذا التطبيق.

لو بنيت المشروع يدويًا بدون السكربتات، شغّل بعد `flutter create .`:
```powershell
powershell -ExecutionPolicy Bypass -File tool/configure_android.ps1
powershell -ExecutionPolicy Bypass -File tool/verify_android_setup.ps1
```

---

## حماية البيانات

- إذا فشلت قراءة SQLite، التطبيق **لا** يرجع إلى `defaultDB()` ولا ينفذ `save()` فوق القاعدة الحالية؛ يعرض شاشة خطأ ويوقف الـbootstrap.
- إذا فشلت قراءة بيانات SharedPreferences القديمة، لا يتم حذف المفتاح القديم ولا استبداله بقاعدة فارغة.
- فشل الحفظ في SQLite أصبح خطأً حقيقيًا في `Future` بدل ابتلاعه في `catch`، مع حالة `lastSaveError` يمكن للواجهة مراقبتها.
- `hasAnyData()` يفحص `days` و`sessions` حتى لا تُعتبر قاعدة تحتوي جلسات ولكن بلا أيام "فارغة".
- `FutureBuilder` في startup يفحص `snap.hasError` ويعرض حالة فشل مع إعادة محاولة بدل فتح التطبيق وهو غير جاهز.

## الهيكلة (دفعة 10)

- **إدارة الحالة**: Riverpod (`flutter_riverpod`) — `ProviderScope` في جذر التطبيق،
  و`gymStoreProvider` بيوصّل كل شاشة بنفس مخزن البيانات القديم (`GymStore`)
  عن طريق `ref.watch(gymStoreProvider)` بدل الاعتماد على `AnimatedBuilder`
  يدوي على مستوى التطبيق كله.
- **قاعدة البيانات**: SQLite حقيقية عن طريق Drift (`lib/data/db/app_database.dart`)
  بدل ما كانت البيانات كلها JSON واحد جوه SharedPreferences. أول مرة تفتح
  فيها النسخة الجديدة، بيترحّل أي بيانات قديمة تلقائيًا من غير ما تعمل حاجة.
- **Lazy Loading (#28)**: تابات الرئيسية/التقارير/InBody/الإعدادات بقت
  بتتبني أول مرة بس لما تفتحها، مش الأربعة مع بعض من أول تشغيل للتطبيق.
- **مهم عند البناء**: لازم تشغّل توليد أكواد Drift قبل `flutter build apk`:
  ```bash
  dart run build_runner build --delete-conflicting-outputs
  ```
  (ده متضاف بالفعل في GitHub Actions workflow تلقائيًا).

---

## طريقة البناء

> **مهم:** مجلدات `android/` و`ios/` وملف `app_database.g.dart` ملفات مولّدة وليست جزءًا من المصدر المرفق.
> سكربت `tool\bootstrap.bat` ينشئ منصات Flutter، يضبط Android، ثم يشغّل `build_runner` لتوليد كود Drift.
> لذلك لا تحاول تشغيل `flutter build` مباشرة على ZIP خام قبل تنفيذ الـbootstrap.

### الطريقة 1: من جهازك

```bash
# 1) تأكد إن Flutter مركب
flutter doctor

# 2) جوه فولدر المشروع — مرة واحدة بس عشان يولّد فولدرات android/ios
flutter create .

# 3) المكتبات
flutter pub get

# 4) توليد أكواد قاعدة البيانات (Drift) — خطوة جديدة من دفعة 10
dart run build_runner build --delete-conflicting-outputs

# 5) ابني الـ APK
flutter build apk --release
```

الملف هيبقى هنا:

```
build/app/outputs/flutter-apk/app-release.apk
```

**مهم:** إذا كنت تبني يدويًا بالخطوات أعلاه، نفّذ بعد `flutter create .`:
```powershell
powershell -ExecutionPolicy Bypass -File tool/configure_android.ps1
powershell -ExecutionPolicy Bypass -File tool/verify_android_setup.ps1
```
ولا تضف الصلاحيات يدويًا؛ السكربت يضيف كل إعدادات Android المطلوبة ويتحقق منها قبل البناء.

### الطريقة 2: من غير ما تركب حاجة (GitHub)

المشروع جاي معاه workflow جاهز في `.github/workflows/build-apk.yml`:

1. ارفع الفولدر ده على مستودع GitHub
2. روح تاب **Actions** ← **Build SAQR GYM APK** ← **Run workflow**
3. بعد حوالي 10 دقايق هتلاقي الـ APK في **Artifacts** تحمّله على الموبايل

الـ workflow بيعمل `flutter create` ثم يشغّل `tool/configure_android.ps1` و`tool/verify_android_setup.ps1` تلقائيًا، فيفعّل الـdesugaring ويضيف الصلاحيات وReceivers المطلوبة قبل البناء.

---

## النسخ الاحتياطية — دفعة الإصلاح

- زر **استيراد** يفتح منتقي ملفات النظام مباشرة؛ لم يعد مطلوبًا فتح JSON ونسخه
  ولصقه داخل TextField.
- زر **حفظ على الجهاز** يستخدم واجهة اختيار مكان من النظام بدل الكتابة المباشرة
  إلى `/storage/emulated/0/Download`، لتفادي مشاكل Scoped Storage على أندرويد.
- النسخ التلقائية المحلية أصبحت SQLite snapshots حقيقية، وآخر 3 فقط محفوظة.

## الإشعارات النظامية

الإشعارات النظامية **مضمنة ومفعّلة** وليست ميزة مستبعدة. التطبيق يهيّئ `flutter_local_notifications`، يطلب صلاحية الإشعارات عند تفعيل التذكير، ويجدول التذكيرات لأقرب 14 يومًا. زر Quick-log داخل الإشعار يمكنه تسجيل جلسة حتى عندما تكون واجهة التطبيق مغلقة، ثم يعرض إشعار تأكيد ويعيد جدولة التذكيرات.

إعداد Android المطلوب لا يعتمد على تعديل يدوي: `tool/configure_android.ps1` يفعّل Core Library Desugaring ويضيف `desugar_jdk_libs:2.1.4`، ويضيف صلاحيات `CAMERA`, `WAKE_LOCK`, `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, و`VIBRATE`، بالإضافة إلى Receivers المطلوبة للإشعارات المجدولة وNotification Actions. سكربت `tool/verify_android_setup.ps1` يتحقق من كل ذلك قبل البناء.

---

## هيكل المشروع

```
lib/
  main.dart                    # نقطة البداية + التابات
  data/
    models.dart                # كل نماذج البيانات
    default_program.dart       # البرنامج الافتراضي + خريطة الصور
    store.dart                 # التخزين، النسخ الاحتياطية، تعديل البرنامج
    analytics.dart             # كل الحسابات (PR، 1RM، الحجم، الأطباق...)
    session_controller.dart    # إدارة الجلسة الشغالة والتايمرات
  screens/                     # 9 شاشات
  services/
    feedback.dart              # صوت، اهتزاز، تنبيهات، تنسيق الوقت والتاريخ
    backup.dart                # مشاركة/حفظ/استيراد النسخ
  ui/
    theme.dart                 # نفس ألوان نسخة الويب بالظبط
    widgets.dart               # الكروت والأزرار والرسوم البيانية
assets/
  exercises/                   # 73 صورة تمرين
  brand/                       # صورة البروفايل
```

## Build / Backup architecture (fixed)

- SQLite/Drift is the source of truth for app data.
- The legacy SharedPreferences JSON database key is removed after a successful migration.
- Legacy automatic-backup JSON entries in SharedPreferences are discarded during upgrade; new automatic backups are SQLite snapshot files and only their small metadata is kept in SharedPreferences.
- Manual portable backups use `.saqrbackup` ZIP archives containing `manifest.json` plus image files, avoiding base64 inflation. Legacy `.json` backups remain importable.
- Manual backup import uses the system file picker; there is no clipboard/TextField import flow.
- Direct writes to `/storage/emulated/0/Download` are not used.
- `tool/bootstrap.bat` creates Android/iOS platform folders, installs packages, generates Drift code, and runs the analyzer.
- `tool/build_apk.bat` performs the same bootstrap steps and builds a release APK.
- Gamification XP/level/achievement calculations are cached and invalidated after data saves.
