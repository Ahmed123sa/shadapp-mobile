# مراجعة تكامل Zoom + الشغل الجديد عبر الطبقات الثلاث

> مراجعة للشغل الجديد: تكامل Zoom (باك اند)، صفحة الفاينانس، وإعداد `show_contract_dates`.
> كل نتيجة اتفحصت في الكود ومعاها رقم السطر.

---

## P0 — ثغرة في webhook الـ Zoom: يقبل أي طلب لو المفتاح فاضي

`ZoomService::verifyWebhookSignature` (`app/Services/ZoomService.php:129-138`):

```php
public function verifyWebhookSignature(string $payload, string $signature): bool
{
    $secret = config('services.zoom.webhook_secret');
    if (!$secret) {
        return true;          // ← أي طلب يعدّي
    }
    $expected = hash_hmac('sha256', $payload, $secret);
    return hash_equals($expected, $signature);
}
```

والمسار مفتوح بدون auth بالتصميم (`routes/api.php:44-45`):

```php
// Zoom Webhook (no auth — verified by signature)
Route::post('/webhooks/zoom', [ZoomWebhookController::class, 'handle']);
```

**و`.env.example:87` بيشحن `ZOOM_WEBHOOK_SECRET_TOKEN=` فاضي.** يعني الحالة الافتراضية لأي نشر جديد هي الحالة المفتوحة بالظبط.

أسوأ: `ZoomService::isConfigured()` (سطر ١٣-١٦) بيتحقق من `client_id` بس، مش من `webhook_secret`. فالتوليفة "اجتماعات Zoom شغالة + الويبهوك مفتوح للجميع" مش بس ممكنة — دي أكتر توليفة محتملة عمليًا.

### اللي ينفع حد يعمله من غير أي مصادقة

| الحدث | التأثير |
|---|---|
| `meeting.ended` | يقفل أي اجتماع (`status = completed`) بمعرفة `zoom_meeting_id` |
| `meeting.participant_joined` | يحقن حضور وهميين — `name`/`email` جايين من الـ payload مباشرة (`ZoomWebhookController:79-83`) |
| `recording.completed` | **يكتب أي URL في `recording_url`** (سطر ١٢٣-١٣٣) |

الأخير هو الأخطر: الـ URL ده بيتعرض للمستخدمين كـ"تسجيل الاجتماع" ويدوسوا عليه. ده متجه تصيّد جاهز داخل منتجك، بهوية موثوقة.

### والأسوأ: التحقق غلط أصلًا، فمفيش إعداد يشتغل صح

Zoom بيبعت:

```
x-zm-signature: v0={hash}
x-zm-request-timestamp: {timestamp}
```

والـ hash محسوب على الرسالة `v0:{timestamp}:{body}` — **مش على الـ body لوحده**.

الكود بيقارن `hash_hmac('sha256', $body, $secret)` بالهيدر الخام. يعني:

- **المفتاح فاضي** → كل حاجة تعدّي (مفتوح للجميع)
- **المفتاح متظبط** → ولا ويبهوك حقيقي هيعدّي، كله 401 (التكامل مكسور)

مفيش حالة وسط. مفيش كمان أي فحص لـ `x-zm-request-timestamp` (فحصت: صفر نتائج في `app/`)، يعني حتى لو التوقيع اتظبط، الطلب المُلتقط يتعاد استخدامه للأبد.

### التستات بتثبّت الثغرة بدل ما تكشفها

`tests/Feature/ZoomWebhookTest.php` — أربع تستات بتعمل:

```php
config(['services.zoom.webhook_secret' => '']);
$this->postJson('/api/webhooks/zoom', $payload)->assertOk();   // بدون أي توقيع
```

ودي بتأكد إن الأثر الجانبي حصل. يعني الحالة المفتوحة متسجّلة كسلوك مقصود.

وفيه `test_invalid_signature_rejected_when_secret_configured` — ده **دليل إن اللي كتب كان مفكّر في الأمان**. بس هو بيختبر الرفض بتوقيع غلط بس. **التست اللي مكتبش هو "توقيع صحيح يتقبل"** — وده بالظبط التست اللي كان هيجبرك تبني توقيع Zoom حقيقي، وساعتها كنت هتكتشف فرق الصيغة فورًا.

### الإصلاح

```php
public function verifyWebhookSignature(string $payload, string $signature, string $timestamp): bool
{
    $secret = config('services.zoom.webhook_secret');
    if (!$secret) {
        Log::error('Zoom: webhook secret not configured — rejecting webhook');
        return false;                          // fail-closed
    }
    $message  = "v0:{$timestamp}:{$payload}";
    $expected = 'v0=' . hash_hmac('sha256', $message, $secret);
    return hash_equals($expected, $signature);
}
```

مع فحص عمر الـ timestamp (Zoom بيوصي بـ ٥ دقايق)، وتست واحد إضافي يبني توقيع صحيح ويتأكد إنه بيعدّي.

---

## P2 — ملاحظات أصغر على الـ webhook

**١. `handleParticipantJoined` بيضيف من غير حد أقصى** (سطر ٧٨-٨٥): `$attendees[] = ...` من غير dedup. مشارك بيخرج ويدخل ١٠٠ مرة = ١٠٠ صف. ومع كون المسار مفتوح دلوقتي، ده يخلي عمود الـ JSON قابل للتضخيم بلا حدود.

**٢. `handleParticipantLeft` بيطابق بالإيميل بس** (سطر ١٠١): Zoom بيسيب `email` فاضي للمشاركين غير المسجّلين. ساعتها `null === null` بتطابق **أول** حاضر بإيميل فاضي — اللي ممكن يكون شخص تاني خالص، فوقت الحضور يتسجّل على الغلط.

---

## اللي اشتغل كويس فعلًا

**`PaymentController::allPayments`** (`app/Domains/Payment/PaymentController.php:32-84`) — ده أنضف كود جديد في الدفعة:

```php
$this->authorize('viewAny', Payment::class);
if ($user->isAccountManager()) {
    $clientIds = $user->managedClients()->pluck('id');
    $query->whereIn('client_id', $clientIds);      // عزل المستأجرين محفوظ
}
```

policy authorization + scoping صريح للـ AM + `(clone $query)` عشان الإحصائيات تتحسب على نفس الفلاتر. الفلاتر كلها عبر Eloquent binding.

*ملاحظة نطاق (مش خطأ):* البحث بيستخدم `like "%{$search}%"` — آمن من الحقن، بس الـ wildcard في الأول بيمنع استخدام الفهرس. هيبان لما جدول الدفعات يكبر.

**`ZoomService` نفسه** — كل استدعاء بيتحقق من `$response->failed()` ويسجّل السياق (status + body) قبل ما يرمي. و`Cache::remember('zoom_access_token', 3300, ...)` بـ ٥٥ دقيقة لتوكن عمره ساعة — هامش صح. و`updateMeeting` بيرجّع `?? []` عشان رد 204 الفاضي، ومعاه تست مخصوص لده.

**`SettingsController::update`** — `isSuperAdmin()` + whitelist للمفاتيح (`in:corporate_tax_percentage,show_contract_dates`). حد مايقدرش يحقن مفتاح عشوائي.

**`test/helpers/mock_http_client.dart`** (موبايل) — التعليقات فيه بتوثّق معرفة اتدفع تمنها: إن `mocktail` بيرمي `MissingStubError` مش زي Mockito، وإن `http.Response` بيقع على latin1 ويكسر مع النصوص العربية.

---

## `show_contract_dates`: نفس المنطق ٤ مرات بـ ٣ صيغ

| المكان | الكود |
|---|---|
| موبايل `contract_builder.dart:117` | `val.toString() == '1' \|\| val.toString().toLowerCase() == 'true'` |
| داشبورد `ContractBuilder.tsx:22` | `cd === '1' \|\| cd === 1 \|\| cd === true \|\| cd === 'true'` |
| داشبورد `ContractsTab.tsx:52` | نفس اللي فوق |
| داشبورد `settings/page.tsx:82` | نفس اللي فوق |

الموبايل بيقبل `'TRUE'`، الداشبورد لأ (`===` حساس للحالة). مش فارقة دلوقتي لأن الباك اند بيخزّن `'1'`/`'0'` — بس دي ٤ أماكن لازم تفضل متزامنة، وصفر تستات على أي واحدة.

وكل الأربعة بيبلعوا الفشل (`.catch(() => {})` / `catch (_) {}`). لو `/settings` فشل، التواريخ بتظهر بصمت.

**الأنضف:** دالة واحدة في كل طبقة — `bool asFlag(dynamic)` في الموبايل، `parseFlag()` في `lib/` بالداشبورد.

---

## الموبايل: `contract_builder.dart` رجّع نمطين اتشالوا

هو الملف **الوحيد** في المشروع اللي فيه:

- **سطر ١١٠**: `await _api.get('/settings')` — أول استدعاء API مباشر يرجع لـ `features/` بعد ما المهمة #208 قفلت ده. و`SystemSettingsRepository::fetchSettings()` موجود بنفس السطر بالحرف.
- **سطر ١٢٢**: `} catch (_) {}` — آخر واحدة فاضية في `lib/` كله، بعد ما شلنا آخر اتنين في P2 #6.

---

## كومنت بقى مضلِّل

`routes/api.php:195`:

```php
// System Settings (SA only — controller checks isSuperAdmin)
Route::get('/settings', [SettingsController::class, 'index']);
```

`index()` مافيهاش أي فحص دور — و**ده صح**، لأن كل AM محتاج يقرا `show_contract_dates` دلوقتي. المشكلة إن الكومنت بيقول العكس، فأول واحد يقراه هيفتكر فيه ثغرة ويضيف guard يكسر الفيتشر.

---

## الترتيب المقترح

| # | الشغل | الحجم | ليه هنا |
|---|---|---|---|
| ١ | توقيع الويبهوك: fail-closed + الصيغة الصح + timestamp | متوسط | ثغرة مفتوحة، والحالة الافتراضية للنشر |
| ٢ | تعديل تستات الويبهوك عشان تعكس السلوك الجديد | صغير | التستات دلوقتي بتثبّت الثغرة |
| ٣ | موبايل: `SystemSettingsProvider` + `AppLog.error` | صغير | يرجّع القاعدتين المكسورتين |
| ٤ | توحيد parsing الـ flag + تست | صغير | ٤ نسخ، صفر تغطية |
| ٥ | dedup الحضور + المطابقة بالإيميل | صغير | بعد تأمين الويبهوك |
| ٦ | تصحيح كومنت `routes/api.php:195` | دقيقة | يمنع "إصلاح" يكسر الفيتشر |
