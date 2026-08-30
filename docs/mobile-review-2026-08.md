# تقييم تطبيق الموبايل — أغسطس ٢٠٢٦ (بعد إغلاق بند ٨)

> مراجعة جديدة بعين مراجع خارجي، بعد ما خطة `state-layer-migration-plan.md` اتقفلت بالكامل.
> كل نتيجة هنا **اتفحصت في الكود** ومعاها رقم السطر — مفيش تخمين.

---

## الحُكم العام

الكود **في حالة كويسة جدًا** مقارنة بنقطة البداية. البنية اتعملت صح، والانضباط اللي اتّبع (تحقق قبل كل كوميت) باين في التفاصيل. الملاحظات اللي تحت مش تراجع — دي حاجات **مالهاش علاقة بالهجرة**، أغلبها موجود من قبلها والمراجعات السابقة ماوصلتلهاش لأنها كانت مركّزة على طبقة الـ API.

| المؤشر | القيمة |
|---|---|
| `flutter analyze` | **صفر** مشاكل |
| `flutter test` | **٤٦٣/٤٦٣** |
| استدعاءات API مباشرة في `features/` | **صفر** |
| أكبر ملف مكتوب بإيد | `admin_settings_page.dart` ٧٢٥ سطر |
| ملفات فوق ٨٠٠ سطر | **صفر** |
| ملفات اختبار | ٩٤ |
| `catch` فاضية | **٢** (كانت ~٤٠) |
| التوكن | `FlutterSecureStorage` ✅ (مش SharedPreferences) |

---

## P0 — لازم قبل الإصدار الجاي

### ١. مفيش أي redirect في الـ router — لا لانتهاء الجلسة ولا لحماية المسارات

`core/router.dart` فيه **صفر** `redirect:`. و`main.dart:88-95` بيحسب `initialLocation` **مرة واحدة بس** عند الإقلاع البارد.

النتيجة المباشرة — `api_client.dart:337-340`:

```dart
if (response.statusCode == 401) {
  await clearToken();          // ← التوكن اتمسح
  throw AuthException(...);    // ← وبس. محدش بيوديه /login
}
```

لما الجلسة تنتهي والسيرفر يرجّع 401: التوكن بيتمسح، الاستثناء بيترمي، كل شاشة بتلقفه وتعرض snackbar أو تسجّله في اللوج — **والمستخدم بيفضل قاعد على نفس الشاشة**. كل طلب بعد كده بيفشل، الداتا بتفضل قديمة على الشاشة، ومفيش أي إشارة إنه مطلوب يسجّل دخول تاني. التطبيق بيبقى في حالة "زومبي" لحد ما يقفله ويفتحه.

كمان: مفيش guard على المسارات. `/am/settings` و`/am/audit-logs` مفتوحين لأي deep link مهما كان الدور أو حالة الدخول. **مش تسريب بيانات** — الباك اند بيرفض بـ 403 (ده شغل P0-1 اللي اتعمل) — بس المستخدم بيشوف شاشة مكسورة بدل ما يترد لمكانه الصح.

**الحل**: `redirect:` واحد في `createRouter` يقرا `api.getToken()`/`api.role` ويحوّل، + طريقة تخلّي `AuthException` تفضي الـ stack لـ `/login`.

### ٢. الـ sub_user بيتوجّه لواجهة الـ AM لما يدوس على إشعار

`main.dart:139-153`:

```dart
final role = await ApiClient().getRole();
if (role == 'client') {                          // ← 'sub_user' مش هنا
  router.go('/dashboard?tab=...');
  return;
}
if (workspaceId != null) {
  router.go('/am/workspace/$workspaceId?tab=...'); // ← الـ sub_user بيقع هنا
}
```

بس `main.dart:93` نفسه، **على بُعد ٥٠ سطر**، بيعمل الصح:

```dart
initialLocation = (role == 'client' || role == 'sub_user') ? '/dashboard' : '/am/dashboard';
```

و`sub_user` دور حقيقي بالكامل: بيتحط عند الدخول (`auth_provider.dart:110`)، ومتعامل معاه كعميل في كل مكان تاني (`login_page.dart:195` · `client_dashboard_screen.dart:121` · `settings_page.dart:33`)، والـ sub_users بيسجّلوا FCM tokens زي أي حد (`notification_service.dart:135` → مسار محمي بالـ auth العادي).

**النتيجة**: sub_user بيدوس على إشعار شات → بيتحط في `/am/workspace/...`. الباك اند هيرفض، فبيشوف شاشة AM فاضية/مكسورة بدل الشات بتاعه.

ده **بالظبط نفس شكل** الباج اللي اتلقى قبل كده في بند ٥ (`onContractStatusChanged` الناقص في `chat_page.dart`): فرع بيعدّ الأدوار وينسى واحد منهم.

**الحل**: `if (role == 'client' || role == 'sub_user')` — سطر واحد. والأهم: `_fcmTabIndex` و`_navigateFromNotification` دوال top-level خاصة في `main.dart` **ومالهاش ولا تست**. لازم تتنقل لملف قابل للاختبار.

---

## P1 — هشاشة حقيقية، مش بتضرب دلوقتي

### ٣. الرفع (multipart) بيتخطّى معالجة أخطاء الشبكة الموحّدة

`_send()` في `api_client.dart:205-217` اتعمل مخصوص عشان يحوّل فشل الشبكة لـ `ConnectionException` واضح. الأربع دوال العادية (`get`/`post`/`put`/`patch`/`delete`) كلها بتعدّي منه.

التلاتة بتوع الرفع **لأ** — `multipartPut:272` · `multipartPost:304` · `multipartPostMultiple:319`:

```dart
final streamed = await _httpClient.send(request).timeout(_timeout);
final response = await http.Response.fromStream(streamed);
return _handle(response);
```

يعني timeout أو انقطاع نت وسط رفع ملف بيطلع `TimeoutException`/`SocketException` خام، مش `ConnectionException`. أي كود بيلقف `ConnectionException` عشان يعرض "مفيش اتصال" **مش هيمسكه**. والرفع بالتحديد هو أكتر مكان الـ timeout بيحصل فيه.

زيادة على كده: نفس الـ ٣٠ ثانية بتتطبّق على رفع PDF/صورة على بيانات موبايل — ضيّقة.

### ٤. `payments_tab.dart` بيقرا نفس الحقل بأمان أقل من `payments_page.dart`

نفس الحقل (`tax_summary.grand_total`)، شاشتين، أسلوبين:

| | الكود | لو الحقل رجع String |
|---|---|---|
| `payments_page.dart:73` | `num.tryParse(...toString())` | ٠ (آمن) |
| `payments_tab.dart:83` | `(_taxSummary!['grand_total'] as num?)` | **TypeError** → شاشة حمرا |
| `payments_tab.dart:236` | `(_taxSummary!['tax_percentage'] ?? 0).toDouble()` | **NoSuchMethodError** |

الباك اند دلوقتي بيرجّعهم أرقام (`PaymentController.php:87-96` — الجمع بالـ `+` في PHP بيحوّل لرقم)، **فالباج مش شغّال حاليًا**. بس السطر ده بيقع جوّه getter بينداه الـ `build()` — أي تغيير في الـ serialization (Laravel API Resource، `decimal` cast، pagination) بيحوّله لكراش وقت البناء مش قيمة غلطانة.

الفرق نفسه هو الدليل: النسخة الدفاعية موجودة أصلًا في الشاشة التانية.

### ٥. `int.parse` في الـ router بيكسر على deep link مشوّه

`router.dart` مش متسق مع نفسه:

```dart
// السطر 34, 37, 38 — بيرمي FormatException جوّه الـ builder
ClientDetailPage(clientId: int.parse(state.pathParameters['id']!))

// السطر 40 — بيعمل الصح
final wsId = int.tryParse(state.pathParameters['id'] ?? '');
```

`/am/clients/abc` من إشعار قديم أو لينك متكسر = شاشة حمرا بدل صفحة "مش موجود".

---

## P2 — تنضيف

### ٦. آخر `catch` فاضيتين في المشروع

`providers/notification_provider.dart:30` و`:46`:

```dart
} catch (_) {
} finally {
  _isLoading = false;
}
```

كل الـ providers التانية بتحفظ `_error = e.toString()`. دول بس بيبلعوا الخطأ من غير حتى `AppLog.error` — وده مخالف صريح للسبب المكتوب في `core/app_log.dart:6` نفسه.

### ٧. تسجيل الأخطاء متلخبط: `debugPrint` مقابل `AppLog`

٢٥ استخدام لـ `debugPrint` في ٩ ملفات، أكتفهم في الشات:

| الملف | العدد |
|---|---|
| `chat_page.dart` | ٨ |
| `chat_tab.dart` | ٦ |
| `payments_tab.dart` | ٤ |
| باقي ٦ ملفات | ٧ |

`debugPrint` **بيختفي تمامًا في الـ release** — يعني كل أخطاء الشات والدفعات دي مش بتوصل Crashlytics. `AppLog.error` هو المفروض، ومستخدم فعلًا في نفس الملفات دي في أماكن تانية (`chat_page.dart:194` مثلًا). ده تناقض جوّه الملف الواحد.

### ٨. فجوات تغطية

مالهاش أي تست:

- `main.dart` — `_fcmTabIndex` · `_navigateFromNotification` (**وهنا الباج رقم ٢ ساكن**)
- `core/router.dart`
- `core/notification_service.dart`
- `core/locale_provider.dart`
- `providers/system_settings_provider.dart` + `data/system_settings_repository.dart` (الوحيدين من غير تست في الطبقتين)

الملفات المستخرجة حديثًا في بند ٨ متغطية **غير مباشرة** عبر تستات الشاشات الأم (`chat_page_test` بيمرّ على `chat_page_widgets` وهكذا) — ده كافي لأن الاستخراج كان بالحفاظ على السلوك، مش سلوك جديد.

---

## الترتيب المقترح

| # | الشغل | الحجم | ليه هنا |
|---|---|---|---|
| ١ | **٢** (فرع الـ sub_user) | سطر واحد | باج مؤكد، إصلاح فوري، صفر مخاطرة |
| ٢ | **١** (redirect الجلسة) | متوسط | أكتر حاجة المستخدم هيحسّها |
| ٣ | **٥** (`int.tryParse` في الـ router) | ٣ سطور | نفس الجلسة |
| ٤ | **٦ + ٧** (اللوجينج) | تنضيف | يخلّي Crashlytics تشوف أخطاء الشات |
| ٥ | **٣** (`_send` للرفع) | صغير | يوحّد معالجة الشبكة |
| ٦ | **٤** (parsing الضرايب) | سطرين | تحصين استباقي |
| ٧ | **٨** (تستات `main.dart`) | متوسط | يمنع رجوع باج ٢ |

---

## اللي اشتغل كويس (يستاهل يتحفظ)

- **`ApiClient._handle`** — تفريق حقيقي بين 401/422/429/5xx مع استثناء لكل حالة. الكومنت على `RateLimitException` بيشرح ليه 429 اتفصل، وده النوع من التوثيق اللي بيمنع تراجع.
- **الحارس في `main.dart:26-37`** — بيرفض يبني release بيكلّم `localhost` أو `http://`. حماية بسيطة من كارثة.
- **حذف `workspaceIdSafe`** — استبدال fallback خطر (`?? 1`) بـ guard صريح كان القرار الصح.
- **الكومنتات التفسيرية** — الكود مليان تعليقات بتشرح **ليه** القرار اتاخد (مش إيه اللي بيحصل)، ومربوطة بأرقام بنود الخطة. ده أندر بكتير من الكود النضيف نفسه.
