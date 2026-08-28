# خطة بناء طبقة الحالة (State Layer) — تطبيق الموبايل

> **آخر تحديث:** أغسطس ٢٠٢٦ — **الخطة خلصت بالكامل.** كل المسارات (A · الخطوة صفر · B · C · D) وكل الشاشات المؤجّلة اتنقلت. `features/` دلوقتي صفر `_api.get|post|put|patch|delete|multipart*` (اتأكد بـ grep على الشجرة كلها). الجزء الأول من الملف ده كان بيوثّق **الوضع وقت آخر تحديث فعلي للأرقام** (أسفل، بالأرقام القديمة قبل الجزء التاني)، والجزء التاني بيوثّق **الخطة اللي اتنفّذت بالكامل دلوقتي**.

---

## المبدأ الحاكم (ما اتغيّرش ومايتغيّرش)

> في أي لحظة، الكود القديم يفضل شغّال لحد ما البديل الجديد يثبت إنه شغّال. مانمسحش حاجة قبل ما نتأكد.

**القاعدة النهائية**: `features/` مايبقاش فيها ولا `_api.get(...)`. لو موجود، يبقى النقل ما خلصش.

*استثناء واحد مقصود ومتّبع في كل الشاشات المنقولة*: القراءات غير المؤثّرة من `ApiClient` — `resolveFileUrl()`، `workspaceId`، `role`، `userId` — بتفضل استدعاء مباشر. دي مش استدعاءات شبكة، دي قراءة حالة جلسة محليّة، ونقلها لطبقة Repository هيبقى تعقيد بلا فايدة.

---

## البنية المستهدفة (اتنفّذت)

```
lib/
  models/            ← ٥ موديلات
    client.dart  manager.dart  app_notification.dart  meeting.dart  approval.dart
  data/              ← ١٥ Repository — كل استدعاءات الـ API مجمّعة حسب المجال
    client_  manager_  notification_  file_  approval_  meeting_  contract_
    payment_  settings_  dashboard_  chat_  sub_user_  signature_
    audit_log_  report_repository.dart
  providers/         ← موصّلين فعليًا في main.dart ومستخدمين في الشاشات
  features/          ← الواجهات: تقرا من Providers
  core/
    api_client.dart  ← زي ما هو، بس مايتنادىش من الواجهات
```

---

## الوضع الحالي (أرقام محقّقة، مش تقديرية)

| البند | عند بداية الخطة | دلوقتي |
|---|---|---|
| استدعاءات `_api.*` مباشرة في `features/` | ~١٨٠ | **٩٩** |
| ملفات واجهة فيها استدعاء مباشر | ~٤٠ | **١٤** |
| Repositories | ٠ | **١٥** |
| Models | ٠ | **٥** |
| ملفات اختبار widget | ٩ | **٣٦** |

### اللي خلص

كل الشرائح الرأسية الـ ١٢ (٠ Auth لحد ١١ Chat) خلّصت **طبقة البيانات** بتاعتها: Model + Repository + Provider + اختبارات وحدة. يعني أي شاشة متبقية دلوقتي **مش محتاجة سباكة جديدة** في الغالب — محتاجة نقل الشاشة نفسها بس.

الشاشات المنقولة بالكامل (٢٦ شاشة)، آخر عشرة منهم:
`profile_page` · `forgot_password_page` · `sa_team_page` · `sa_approvals_page` · `client_profile_tab` · `calendar_tab` · `approvals_tab` · `audit_log_page` · `reports_tab` · `meetings_tab`

---

## ليه الخطة الباقية مختلفة عن الأولى

الخطة الأصلية كانت مقسّمة **بالمجال** (شريحة Clients، شريحة Contracts…). ده اشتغل كويس لأن أغلب المجالات كان فيها شاشات صغيرة/متوسطة نبدأ بيها.

اللي فضل دلوقتي **مش موزّع بالمجال** — كله شاشات كبيرة صفر تغطية. أصغر واحدة فيهم مربوطة بالـ realtime، وأكبر واحدة ١٢٣٣ سطر. فالتقسيم الجديد **بالعائق** مش بالمجال:

| المسار | العائق | الحل |
|---|---|---|
| A — Payments | حجم + صفر تغطية | اختبار توصيفي ثم نقل. **الـ Repository جاهز ١٠٠٪** |
| B — Contracts | حجم + صفر تغطية + تكرار بين ٤ ملفات | اختبار توصيفي ثم نقل. الـ Repository جاهز |
| C — Settings/Onboarding | حجم + تعدد مجالات + FCM/lifecycle | اختبار توصيفي + سباكة ناقصة بسيطة |
| D — Realtime | `ReverbService` متشابك مع `initState` | **refactor تمكيني قبل أي نقل** |

---

## جرد ما تبقّى (١٤ ملف · ٩٩ استدعاء)

### المسار A — Payments (١٥ استدعاء · الأرخص)

| الملف | أسطر | استدعاءات | حالة السباكة |
|---|---|---|---|
| `payments/payments_page.dart` | ٩١٢ | ٨ | `PaymentRepository` مغطّي كل الـ endpoints |
| `am/workspace/payments_tab.dart` | ٧٣٢ | ٧ | نفس الكلام |

الـ `PaymentRepository` اتوسّع في مهمة #139 خصّيصًا عشان الشاشتين دول: `create` · `uploadProof` · `review` · `schedule` · `updateSchedule` · `deleteSchedule` · `requestPayment` — كلهم متغطّيين باختبارات وحدة. **فاضل نقل الشاشتين بس.**

### المسار B — Contracts (٢٢ استدعاء)

| الملف | أسطر | استدعاءات |
|---|---|---|
| `contracts/contracts_page.dart` | ٨٥٥ | ٦ |
| `contracts/contract_detail_modal.dart` | ٦٠١ | ٥ |
| `am/workspace/contracts_tab.dart` | ٥٣٢ | ٧ |
| `am/widgets/contract_builder.dart` | ٤١١ | ٤ |

`ContractRepository` مغطّي: `clientAction` · `performAction` · `companyApprove` · `create` · `update` · `send` · `delete` · `fetchClauseTemplates` · `fetchWorkspace`. **الأربع ملفات فيهم تكرار منطق حقيقي** — النقل فرصة لتوحيده، بس **مش في نفس الكوميت**: ننقل الأول، نوحّد بعدين.

### المسار C — Settings / Onboarding (٢١ استدعاء)

| الملف | أسطر | استدعاءات | الخاص فيه |
|---|---|---|---|
| `am/settings/admin_settings_page.dart` | ٩٧١ | ١٥ | ٤ مجالات منفصلة في ملف واحد |
| `onboarding/client_onboarding_screen.dart` | ١٠٤٠ | ٦ | `WidgetsBindingObserver` + اشتراك FCM + auto-advance |

**تقسيم `admin_settings_page.dart` لمجاله الأربعة** (ده اللي بيخلّيها قابلة للتنفيذ):

1. `/auth/me` (قراءة + تعديل + رفع أفاتار) → `AuthProvider` موجود
2. `/settings` (قراءة + تعديل نسبة الضريبة) → `SettingsProvider` موجود
3. `/contract-clause-templates` (CRUD + reorder) → **سباكة ناقصة** — محتاجة `ClauseTemplateRepository` جديد
4. `/auth/sign` (توقيع الـ AM: رفع/نصّي/حذف) → **سباكة ناقصة** — `SignatureRepository` الحالي بيغطّي `/clients/:id/sign` مش `/auth/sign`

### المسار D — Realtime (٤١ استدعاء · محجوب)

| الملف | أسطر | استدعاءات | سبب الحجب |
|---|---|---|---|
| `am/workspace/chat_tab.dart` | ١٢٣٣ | ٩ | `ReverbService` في `initState` + polling |
| `chat/chat_page.dart` | ١٢٣٢ | ١١ | نفس الكلام |
| `am/dashboard/am_dashboard_page.dart` | ١١٠٨ | ١٤ | `ReverbService` |
| `dashboard/client_dashboard_screen.dart` | ٥٠٤ | ٥ | `ReverbService` |
| `am/workspace/am_workspace_page.dart` | ١٧٥ | ١ | **صغيرة**، بس بتضمّ `ChatTab` جوه `IndexedStack` |
| `dashboard/dashboard_page.dart` | ١١٣ | ١ | **صغيرة**، بس بتضمّ شاشات realtime |

آخر اتنين مهمين: حجمهم تافه واستدعاء واحد لكل واحد، ومع ذلك **مش قابلين للاختبار** لأن أي `pumpWidget` ليهم بيهيّئ `ReverbService` و`FirebaseMessaging` حقيقيين. دول بيتحلّوا مجانًا بمجرد ما الـ refactor التمكيني يخلص.

---

## الخطوة صفر: الـ refactor التمكيني للـ realtime

**دي أهم خطوة في الخطة الباقية، ومفيش حاجة في المسار D تبدأ قبلها.**

المشكلة بالظبط (`chat_tab.dart:52-87`):

```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addObserver(this);
  _load().then((_) => _markRead());
  _startPolling();                  // Timer.periodic حقيقي
  final reverb = ReverbService();   // singleton — بيفتح WebSocket فعلي
  reverb.onMessageReceived = ...;
  reverb.connect(wsId);             // اتصال شبكة وقت الاختبار
}
```

`ReverbService` معمول singleton بنفس نمط `ApiClient` بالظبط:

```dart
static final ReverbService _instance = ReverbService._();
factory ReverbService() => _instance;
```

و`ApiClient` عنده بالفعل `ApiClient.forTesting(...)` — **فالحل موجود ومجرّب في نفس الكود بيز**، بس محتاج يتطبّق على `ReverbService`.

**الحل (٣ كوميتات، مايلمسش أي شاشة):**

1. `ReverbService.forTesting({...})` + واجهة تسمح بنسخة صامتة (no-op) — بنفس نمط `ApiClient.forTesting`، وباختبار وحدة يثبت إن النسخة الصامتة مابتفتحش سوكيت.
2. `_startPolling()` يبقى قابل للتعطيل عبر بارامتر اختياري (`bool enablePolling = true`) — الـ `Timer.periodic` هو تاني أكبر سبب لتعليق `pumpAndSettle` في الاختبار.
3. كل شاشة realtime تاخد بارامتر اختياري `ReverbService? reverb` — **نفس نمط الـ providers الاختيارية بالظبط**، يعني كل call site موجود بيفضل بيكمبايل من غير أي تعديل.

بعد الخطوة دي الست شاشات بتاعة المسار D تبقى قابلة للاختبار، وبتتنقل بنفس وصفة أي شاشة تانية.

---

## وصفة الشاشة الكبيرة صفر التغطية

الترتيب **معكوس** عن وصفة المرحلة الأولى: هناك كنا ننقل ونكتب اختبار بعدها؛ هنا الاختبار **قبل** أي تعديل، تنفيذًا للقاعدة رقم ٤ في قواعد السلامة.

**١. اختبار توصيفي — دورة كاملة لوحدها**
يوثّق سلوك الشاشة **الحالي**: إيه الـ endpoints اللي بتتنادى وبأي بارامترات، إيه اللي بيتعرض، إيه اللي بيحصل عند الخطأ. مش بنصلّح ولا بنحسّن هنا — بنثبّت الوضع القايم عشان نعرف لو كسرناه. **كوميت مستقل.**

**٢. تقسيم لمجالات، ونقل مجال واحد في المرة**
`admin_settings_page.dart` = ٤ دورات، مش دورة واحدة. الشاشة الواحدة = **٣–٥ كوميتات صغيرة**.

**٣. لكل مجال، الدورة دي:**
   - أضيف/أوسّع الـ Repository + الـ Provider **باختبارات وحدة الأول**
   - أغيّر نقاط الاستدعاء بتاعة المجال ده **بس** في الشاشة
   - أشغّل الاختبار التوصيفي — **لازم يعدّي زي ما هو بالظبط**
   - `flutter analyze` + `flutter test` → كوميت

**٤. نمط قابلية الاختبار (متّبع في كل الـ ٢٦ شاشة المنقولة)**
```dart
class XScreen extends StatefulWidget {
  final XProvider? xProvider;   // اختياري
  const XScreen({super.key, this.xProvider});
}
class _XScreenState extends State<XScreen> {
  late final XProvider _x = widget.xProvider ?? XProvider();
}
```
كل `const XScreen()` موجود بيفضل بيكمبايل من غير تعديل. ده اللي بيحقّق مبدأ "القديم يفضل شغّال".

**٥. تحقق الختام**
`grep` على الملف يتأكد صفر `_api.get|post|put|patch|delete|multipart*`.

---

## سياسة الـ bugs المكتشفة أثناء النقل

الاختبارات التوصيفية على الشاشات دي **هتكشف bugs قديمة** — ده حصل فعلًا: اختبار `reports_tab` كشف انهيار (`Bad state: No element`) لو `contracts_by_status` رجع فاضي، وهو bug موجود من قبل النقل ومالوش علاقة بيه.

**السياسة الافتراضية: يتسجّل كمهمة منفصلة ويكمل النقل.**
السبب: خلط "نقل بلا تغيير سلوك" مع "تصليح سلوك" في نفس الكوميت بيضيّع أهم ضمانة عندنا — إن الاختبار التوصيفي لو فضل أخضر يبقى مافيش حاجة اتكسرت. لو الاختبار الأخضر ممكن يبقى أخضر لأن السلوك اتغيّر للأحسن، الضمانة دي بتروح.

الاستثناء: bug بيمنع كتابة الاختبار التوصيفي نفسه — ساعتها يتصلّح في كوميت منفصل **قبل** النقل.

---

## الترتيب المقترح

| # | الشغل | ليه في المكان ده |
|---|---|---|
| ١ | **المسار A** (payments ×٢) | أرخص شغل وأسرع نتيجة ملموسة — السباكة جاهزة ١٠٠٪ |
| ٢ | **الخطوة صفر** (refactor الـ realtime) | مايعتمدش على حاجة، وبيفكّ ٦ شاشات (٤١ استدعاء) دفعة واحدة |
| ٣ | **المسار D** — الصغيرين الأول (`dashboard_page` · `am_workspace_page`) | استدعاء واحد لكل واحد، بيثبتوا إن الـ refactor نجح على أرخص مثال |
| ٤ | **المسار B** (contracts ×٤) | حجم متوسط، سباكة جاهزة، وفيه مكسب توحيد بعدين |
| ٥ | **المسار C** (`admin_settings` · `onboarding`) | أعقد سباكة ناقصة |
| ٦ | **المسار D** — الكبار (`chat_tab` · `chat_page` · `am_dashboard` · `client_dashboard`) | الأصعب، والشاتين فيهم توحيد ~٢٤٦٥ سطر مكرّرين |

---

## قواعد السلامة

1. **برانش لكل مسار**، مش لكل المشروع.
2. **ماتمسحش القديم قبل الجديد** — `ApiClient` يفضل زي ما هو طول الوقت.
3. **مفيش مسارين مفتوحين في نفس الوقت.**
4. **الشاشة اللي تغطيتها صفر ماتتلمسش قبل ما يتكتبلها اختبار توصيفي.**
5. **الـ CI هو الحكم** — `analyze` + `test` لازم يبقوا خُضر قبل أي دمج.
6. **`flutter test` وحده مش كفاية.** الـ CI بيفشل على أي `warning` من `analyze` — ومن دول `unused_import` في ملفات الاختبار، وده حصل مرتين فعلًا. أي import جديد في ملف اختبار لازم يتأكّد إنه مستخدم فعلًا مش بس مقبول منطقيًا.

---

## توقّع واقعي

المرحلة الأولى (١٨٠ → ٩٩ استدعاء، ٢٦ شاشة) اتعملت على مدى عدة جلسات بإيقاع "شاشة → تشغيل اختبارات → كوميت".

الباقي **إيقاعه أبطأ لكل ملف** لأن كل شاشة محتاجة اختبار توصيفي قبلها وبتتقسّم لعدة كوميتات. لكن الشغل **أقل تعقيدًا معماريًا** من المرحلة الأولى، لأن كل الـ Repositories والـ Models اتبنوا بالفعل — الباقي أغلبه ميكانيكي متكرر.

**ماينفعش يتعمل في جلسة واحدة.** الخطة متصممة إنها تتوقف عند أي كوميت والمشروع يفضل سليم وقابل للشحن.
