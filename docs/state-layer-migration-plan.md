# خطة بناء طبقة الحالة (State Layer) — تطبيق الموبايل

> **آخر تحديث:** أغسطس ٢٠٢٦ — **النقل خلص بالكامل.**
> كل المسارات (A · الخطوة صفر · B · C · D) وكل الشاشات المؤجّلة اتنقلت.
> `features/` فيها **صفر** `_api.get|post|put|patch|delete|multipart*` (اتأكد بـ grep على الشجرة كلها).
>
> الملف ده دلوقتي بيوثّق تلات حاجات: **(١)** الوضع النهائي بعد النقل، **(٢)** الوصفات والقواعد اللي اتّبعناها ولازم تفضل متّبعة في أي شغل جاي، **(٣)** **خطة المرحلة التالية** — النتايج المستخرجة من مراجعة ما بعد النقل، وهي شغل حقيقي لسه مطلوب.

---

## المبدأ الحاكم (ما اتغيّرش ومايتغيّرش)

> في أي لحظة، الكود القديم يفضل شغّال لحد ما البديل الجديد يثبت إنه شغّال. مانمسحش حاجة قبل ما نتأكد.

**المعيار النهائي (اتحقق):** `features/` مايبقاش فيها ولا `_api.get(...)`.

*استثناء واحد مقصود ومتّبع في كل الشاشات*: القراءات غير المؤثّرة من `ApiClient` — `resolveFileUrl()`، `workspaceId`، `role`، `userId` — بتفضل استدعاء مباشر. دي مش استدعاءات شبكة، دي قراءة حالة جلسة محليّة، ونقلها لطبقة Repository هيبقى تعقيد بلا فايدة.

---

## البنية النهائية (اتنفّذت بالكامل)

```
lib/
  models/            ← ٥ موديلات
    client.dart  manager.dart  app_notification.dart  meeting.dart  approval.dart
  data/              ← ١٦ Repository — كل استدعاءات الـ API مجمّعة حسب المجال
    client_  manager_  notification_  file_  approval_  meeting_  contract_
    payment_  settings_  system_settings_  dashboard_  chat_  sub_user_
    signature_  audit_log_  report_repository.dart
  providers/         ← ١٧ Provider
  features/          ← الواجهات: صفر استدعاء API مباشر
  core/
    api_client.dart  ← زي ما هو، بس مايتنادىش من الواجهات
```

## الأرقام النهائية

| البند | بداية الخطة | آخر تحديث وسط الطريق | **دلوقتي** |
|---|---|---|---|
| استدعاءات `_api.*` مباشرة في `features/` | ~١٨٠ | ٩٩ | **٠** |
| ملفات واجهة فيها استدعاء مباشر | ~٤٠ | ١٤ | **٠** |
| Repositories | ٠ | ١٥ | **١٦** |
| Providers | ٠ | — | **١٧** |
| Models | ٠ | ٥ | **٥** |
| ملفات اختبار | ٩ | ٣٦ | **٩٢** |
| عدد الاختبارات | — | — | **٤٦١** |
| `flutter analyze` | ٤٩ تحذير | ٠ | **٠** |

كل المسارات الأربعة خلصت: **A** (payments ×٢) · **الخطوة صفر** (refactor الـ realtime: `ReverbService.forTesting` + `enablePolling` + `enableFcm`) · **B** (contracts ×٤) · **C** (`admin_settings_page` · `client_onboarding_screen`) · **D** (chat ×٢ + dashboards ×٤).

---

## المرحلة التالية — نتايج مراجعة ما بعد النقل

النقل نجح في هدفه، بس المراجعة اللي بعده كشفت حاجات **النقل نفسه مالوش ذنب فيها** (أغلبها موجود من قبله)، واتنين منهم مش تجميليين. مرتّبين بالأولوية:

### P0 — لازم قبل أي إصدار

> **الاتنين دول اتصلّحوا وانتحقّوا.** `flutter analyze`: صفر مشاكل. `flutter test`: ٤٦٢/٤٦٢ ناجح (كان ٤٦١ — زادت واحدة توثّق سلوك P0-1 الجديد صراحةً في `meetings_page_test.dart`). مستني الكوميت بس.

**١. [تم] `workspaceIdSafe` بيرجّع workspace رقم ١ لما ميعرفش** — `core/api_client.dart:34`

```dart
int get workspaceIdSafe => workspaceId ?? 1;
```

مستخدم في **١١ مكان، منهم عمليات كتابة**: إرسال رسالة، رفع ملف، `markRead`
(`chat_page.dart:190, 217, 250` · `client_dashboard_screen.dart:281` · `meetings_page.dart:43`).
لو `workspaceId` كان null — تثبيت جديد قبل ما `/clients/:id` يرجع، أو بعد `clearToken`، أو عميل لسه مالوش workspace — التطبيق هيقرا **ويكتب** في مساحة عميل تاني.

*التخفيف الحالي*: middleware عزل الـ workspace في الباك اند المفروض يرفض بـ 403. بس ده اعتماد كامل على إن الحارس الخلفي صح ١٠٠٪، والافتراض نفسه غلط: "مفيش workspace" اتحوّل لـ "workspace حد تاني" بدل حالة فاضية واضحة، والمستخدم بيشوف خطأ مبهم بدل رسالة مفهومة.

**الحل المطبّق**: اتشال `workspaceIdSafe` خالص من `api_client.dart`. الأربع ملفات المتأثرة (`chat_page.dart` × ٨ مواضع، `client_dashboard_screen.dart`، `meetings_page.dart`) كل واحد ياخد guard صريح على `workspaceId == null` — نفس النمط الموجود بالظبط في `am/workspace/chat_tab.dart`'s `_wsId` getter (اللي كان أصلًا بيعمل الصح ده، وده اللي أكّد إن النمط مجرّب ومضمون).

**٢. [تم] أربع نسخ من `safeList` بسلوك مختلف**

| الملف | سلوكه مع `{data: [...]}` |
|---|---|
| `core/api_client.dart:361` (النسخة الصح) | بيفكّها ويرجّع الليست |
| `features/onboarding/client_onboarding_screen.dart:1055` | `[]` |
| `features/dashboard/client_dashboard_screen.dart:572` | `[]` |
| `features/am/workspace/payments_tab.dart:741` | `[]` |

التلات ملفات دول **بيعملوا import لـ `api_client.dart`** وبيعرّفوا دالة top-level بنفس الاسم في نفس الملف — ودارت بتختار المحلية من غير أي تحذير من `analyze`. فلو الباك اند عمل pagination لـ `workspace.contracts` أو `workspace.payments` في أي وقت، الشاشات دي هتعرض "مفيش عقود/دفعات" والـ Repositories هتشتغل صح — bug صامت مستني ظرفه.

**الحل المطبّق**: اتشالت التلات نسخ المحلية (`api_client.dart` كان أصلًا متعمل له import في التلاتة، فمفيش import جديد لازم). فضلًا عن كده، `payments_tab.dart`'s نسخة كانت **كود ميت بالكامل** — متعرّفة ومحدش بينده عليها في الملف كله — فشيلها كان تنظيف بلا أي تغيير سلوك.

### P1 — ديون معمارية

**٣. الـ ١٧ provider في `main.dart` ميّتين** — `main.dart:121-135`

مسجّلين في `MultiProvider` لكن **مفيش ولا `context.read<>`/`watch<>`/`Consumer<>` واحد ليهم** في التطبيق كله (`LocaleProvider` هو الوحيد اللي بيتقرا فعلًا، في ٤ أماكن). الشاشات بتبني نسخها بنفسها عبر `widget.xProvider ?? XProvider()`. النتيجة: نسختين من كل provider في الذاكرة، وحقن تبعية مزدوج ومربك.

**قرار مطلوب** (مش واضح لوحده — يتقرر قبل التنفيذ): يا إما نشيل الـ `MultiProvider` ونعتبر النمط الحالي هو المقصود، يا إما نخلي الشاشات تقرا من الـ tree ونسيب الـ constructor param كـ override للاختبار بس. التاني أنضف بس أكبر.

**٤. الـ Providers `ChangeNotifier` بس محدش بيسمع**

`notifyListeners()` بتتنده، لكن الشاشات بتنسخ الحالة في متغيرات محلية وتعمل `setState`
(`approvals_page.dart:51` · `sa_team_page.dart:54` · `reports_tab.dart:92` · `calendar_tab.dart:59`…).
يعني الطبقة نُصّها متحققة: مكسب الاختبارية والتنظيم موجود، ومكسب الـ reactive state لأ. مش خطأ يكسر حاجة — بس `ChangeNotifier` هنا زينة، ولو مش هنستعملها يبقى الأصدق نشيلها.

**مرتبطة بالبند ٣** — يتحلّوا مع بعض في قرار واحد.

**٥. [تم — بالحد الآمن] `chat_page.dart` و `chat_tab.dart` ~٢٥٠٠ سطر شبه متطابقين**

٢٨ من ٣٢ دالة بنفس الأسامي والمنطق (`_send` · `_saveEdit` · `_sendWithAttachment` · `_buildTextBubble` · `_buildFileAttachment` · `_dateSeparator` · `_onPaymentBannerTap` …). ده اللي الخطة الأصلية سمّته "مكسب التوحيد" وأجّلته عن قصد لبعد النقل.

الاتنين متغطّيين باختبارات (`chat_page_test.dart` · `chat_tab_test.dart`)، فالتوحيد عملية آمنة وقابلة للتحقق. اتعمل ملف مشترك جديد `lib/features/chat/chat_shared.dart`، وكل استخراج بيتحقق بـ `flutter analyze` + `flutter test` (462/462) لوحده قبل الكوميت.

*Phase 1 [تم] — الطبقة المتطابقة حرفيًا (دوال صرفة/widgets بلا l10n):* `chatInitials` · `chatIsOnline` · `chatFormatTime` · `chatDateKey` · `chatSenderAvatar` · `chatMeetingBubble` · `chatHeaderIconBtn`.

*Phase 2 [تم] — الطبقة شبه المتطابقة (نفس المنطق، فرق l10n/ألوان/دور بسيط فقط):* اتعمل `chatUpcomingMeetingBanner` · `chatFileAttachment` · `chatCertificateDownloadButton` · `chatSend`/`chatSaveEdit` (فرق `requiresAction` اتحول لـ callback كسول `consumeRequiresAction` عشان يتنفذ في نفس ترتيب الأصل بالظبط) · `chatOnMessageReceived`/`chatOnMessageUpdated` (بيقرو `state.mounted` حيّة، والـ callbacks بتاعة تعديل `_messages` بتفضل بتقفل على الحقل الحقيقي مش نسخة قديمة منه).

*اتفحص واتقرر يفضل منفصل (مش تكاسل — فحص فعلي أثبت فرق سلوك حقيقي)*: `_buildTextBubble`/`_textBubble`. بعد قراءة الجسمين بالكامل تأكد إن فيهم أكتر من نقطة اختلاف حقيقية مش مجرد l10n: **(أ)** بلوك الـ reply preview — `chat_page` بيلوّن الخلفية والنص حسب `isClient` (أبيض/أسود حسب مين بعت)، `chat_tab` بيستخدم لون واحد ثابت مهما كان المرسل. **(ب)** بلوك الوقت/read-receipt — `chat_page` بيعرضه لأي مرسل مع علامة القراءة لو `isClient`، `chat_tab` بيقسمه لبلوكين مختلفين (`!isClient` يشوف علامة القراءة، `isClient` يشوف الوقت بس من غير علامة) لأن تعريف "أنا" بيتقلب بين الشاشتين. **(ج)** بلوك `isPending` — في `chat_page` فيه زرارين فعليين (Request Edit / Approve) بينداهم `_respondToMessage`، في `chat_tab` نفس البلوك مجرد label "في انتظار موافقة العميل" من غير أي زرار، لأن الاتجاه معكوس (العميل بيرد، المدير بس بيستنى). توحيد الدالة دي كانت هتحتاج عدد كبير من الباراميترز/الـ callbacks لدرجة إنها تبقى بنفس تعقيد الاحتفاظ بنسختين — والمخاطرة (خصوصًا نقطة "مين أنا" في القراءة) أعلى من الفايدة. اتسيبت زي ما هي، ونفس القرار لـ `_buildContractBubble`/`_contractBubble` (فرق حقيقي: `chat_page` بيمرر `onApprove`/`onGoToPayments` لـ `ChatContractCard`، `chat_tab` لأ).

*مش هيتّحد أصلًا (فرق دور حقيقي، مش تكرار)*: منطق الموافقة بالكامل (`_approve`/`_respondToMessage`/`_showEditRequestDialog` في chat_page مقابل `_requireAction` في chat_tab)، الـ SA read-only gating، شكل الـ loading (spinner مقابل skeleton)، و`_workspaceActive` (مملوكة للشاشة في chat_page، مملوكة للأب في chat_tab).

**الخلاصة:** ٧ قطع مشتركة اتنقلت لـ `chat_shared.dart` (كل واحدة اتحققت بـ analyze+test لوحدها وكوميت منفصل)، والباقي فُحص وثبت إنه فرق دور حقيقي مش تكرار — البند ده مقفول دلوقتي.

*اكتشاف جانبي محتاج مهمة منفصلة (اتسجل، لسه ماتحلّش):* `chat_tab.dart` بيسمع `onContractStatusChanged` من الـ reverb، `chat_page.dart` لأ — يبان نقص حقيقي في شاشة العميل.

### P2 — تنضيف

**٦. [تم] `clearToken` بينسى `avatar_url`** — `core/api_client.dart:100-106`
اتضاف `await prefs.remove('avatar_url');` مع باقي المسحات. اتحقّق: مفيش تست بيتأكد من قائمة المفاتيح اللي بتتمسح تحديدًا.

**٧. [اتلغى] Controllers جوّه الـ dialogs مش بيتعملها `dispose`**
اتجرّب فيكس (dispose بعد ما `showDialog`/`showModalBottomSheet` يرجعوا، في `admin_settings_page.dart` وفي `client_onboarding_screen.dart` عبر `.whenComplete()`) — لكن التست كسر ٤ تستات (`A TextEditingController was used after being disposed` + أعطال cascading في framework assertions زي `_dependents.isEmpty`). السبب: الـ Future بتاع `showDialog`/`showModalBottomSheet` بيرجع قبل ما شجرة الـ widgets تخلص تتفكك فعليًا — لسه فيه frame أو أكتر بيعيدوا بناء الـ `TextField` وهو بيستخدم الـ controller اللي اتعمله dispose بالفعل. الفيكس اتعمله revert بالكامل، ورجعنا للسلوك الأصلي (تسريب بسيط ومحدود، مش خطر). لو حبينا نرجع للموضوع ده تاني، الطريقة الصح هي نلف الـ controllers جوّه `StatefulWidget` خاص بيه `dispose()` بتاعه، مش نرفعهم لمستوى الدالة اللي بتفتح الـ dialog.

**٨. ٨ ملفات فوق ٨٠٠ سطر**
`chat_tab` ١٢٦٥ · `chat_page` ١٢٥٥ · `am_dashboard_page` ١١٦١ · `client_onboarding_screen` ١٠٥٩ · `admin_settings_page` ٩٩١ · `reports_tab` ٩٣٤ · `payments_page` ٩٠٣ · `contracts_page` ٨٧٥.
البند ٥ لوحده بياكل أكبر اتنين.

### الترتيب المقترح للمرحلة التالية

| # | الشغل | ليه في المكان ده |
|---|---|---|
| ١ | البند ١ + ٢ (P0) | الاتنين معًا شغل قصير، والاتنين bugs حقيقية مش تحسينات |
| ٢ | البند ٦ + ٧ (P2 الرخيص) | سطور معدودة، تتلمّ في نفس الجلسة |
| ٣ | قرار البند ٣/٤ | محتاج قرار قبل كود — يتاخد مرة واحدة ويتطبّق على الكل |
| ٤ | البند ٥ (توحيد الشات) | أكبر مكسب، وبقى آمن لأن الاتنين متغطّيين |

---

## الوصفات والقواعد (اتّبعناها في كل شاشة — تفضل سارية)

### وصفة الشاشة الكبيرة صفر التغطية

**١. اختبار توصيفي قبل أي تعديل** — يوثّق السلوك **الحالي**: أي endpoints بتتنادى وبأي بارامترات، إيه اللي بيتعرض، إيه اللي بيحصل عند الخطأ. مش بنصلّح ولا بنحسّن هنا — بنثبّت الوضع القايم عشان نعرف لو كسرناه. **كوميت مستقل.**

**٢. تقسيم لمجالات، ونقل مجال واحد في المرة** — الشاشة الواحدة = ٣–٥ كوميتات صغيرة، مش كوميت واحد.

**٣. لكل مجال، الدورة دي:**
- أضيف/أوسّع الـ Repository + الـ Provider باختبارات وحدة الأول
- أغيّر نقاط الاستدعاء بتاعة المجال ده **بس** في الشاشة
- أشغّل الاختبار التوصيفي — لازم يعدّي زي ما هو بالظبط
- `flutter analyze` + `flutter test` → كوميت

**٤. نمط قابلية الاختبار** (متّبع في كل الشاشات)
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

**٥. تحقق الختام** — `grep` على الملف يتأكد صفر `_api.get|post|put|patch|delete|multipart*`.

### مصايد اختبارات اتقابلنا معاها (موثّقة عشان متتكررش)

- **`SharedPreferences.setMockInitialValues({})` في `setUp`** — أي شاشة بتنده `ApiClient.setUserData()` هتعلّق `pumpAndSettle` للأبد من غيرها.
- **`ListView` عادي (مش `.builder`) مابيعملش inflate للعناصر البعيدة عن الشاشة** — الويدجت اللي تحت الـ 800×600 **مش موجودة في الشجرة أصلًا**، فـ `find` بيرجّع صفر مش فشل tap. الحل: helper `scrollTo` بيستعمل `scrollUntilVisible` قبل أي tap/assert. ولو الويدجت جوّه bottom sheet، الـ Scrollable بتاعه هو `find.byType(Scrollable).last` مش `.first`.
- **`find.byType(TextField).at(n)` هشّة بعد ما يدخل scroll** — استعمل `find.descendant(of: find.byType(AlertDialog), …)` أو `find.byWidgetPredicate` على `hintText`.
- **بيانات الاختبار ممكن تصطدم بنصوص الـ l10n** — عقد اسمه "Main Contract" اصطدم بـ `l10n.mainContract` وخلّى `findsOneWidget` يفشل. خلّي بيانات الاختبار مميزة.
- **`enableFcm: false` + `enablePolling: false` + `ReverbService.forTesting()`** لازمين لأي شاشة realtime.
- **`Uri.path` مابيشملش الـ query** — فـ branch واحد في الـ stub بيغطّي `/x` و`/x?all=1`.

### مش مغطّى بالاختبارات (فجوات معروفة ومقصودة)

`FilePicker.platform` و`ImagePicker` — platform channels حقيقية مالهاش mock تحت `flutter test` عادي. فكل أزرار رفع الملفات/الصور (الأفاتار، صورة التوقيع، مرفقات إثبات الدفع) مش متغطّية. موثّقة في هيدر كل ملف اختبار بيتأثر.

### سياسة الـ bugs المكتشفة أثناء الشغل

**الافتراضي: تتسجّل كمهمة منفصلة ويكمل النقل.** خلط "نقل بلا تغيير سلوك" مع "تصليح سلوك" في نفس الكوميت بيضيّع أهم ضمانة عندنا — إن الاختبار التوصيفي لو فضل أخضر يبقى مافيش حاجة اتكسرت.
*الاستثناء*: bug بيمنع كتابة الاختبار التوصيفي نفسه — يتصلّح في كوميت منفصل **قبل** النقل.

### قواعد السلامة

1. **برانش لكل مسار**، مش لكل المشروع.
2. **ماتمسحش القديم قبل الجديد.**
3. **مفيش مسارين مفتوحين في نفس الوقت.**
4. **الشاشة اللي تغطيتها صفر ماتتلمسش قبل ما يتكتبلها اختبار توصيفي.**
5. **الـ CI هو الحكم** — `analyze` + `test` لازم يبقوا خُضر قبل أي دمج.
6. **`flutter test` وحده مش كفاية.** الـ CI بيفشل على أي `warning` من `analyze` — ومن دول `unused_import` في ملفات الاختبار و`unused_field` لو ضفت seam ولسه ماستعملتوش. حصل فعلًا أكتر من مرة.
