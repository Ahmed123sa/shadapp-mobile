# iOS App Store Release Checklist — ShadApp Client

Covers everything needed to ship `com.shad.shadapp` to the App Store.
Items marked **[done]** are already committed in the repo; **[you]** needs an
Apple Developer account and must be done by a human.

---

## 1. What was fixed in the repo

| Item | Before | Now |
|---|---|---|
| Bundle identifier | `com.example.shadappClient` | `com.shad.shadapp` |
| `GoogleService-Info.plist` | on disk, **not in the Xcode project** | added to the Runner target's Resources |
| Push entitlement | none | `Runner.entitlements` (dev) / `RunnerRelease.entitlements` (prod) |
| App icons | had an alpha channel | flattened, no alpha |
| Signing identity | `iPhone Developer` (retired) | `Apple Development`, automatic signing |
| Export compliance | unanswered on every upload | `ITSAppUsesNonExemptEncryption = false` |
| Background push | not declared | `UIBackgroundModes = remote-notification, fetch` |
| Display name | `Shadapp Client` | `ShadApp` (matches the Play Store listing) |
| Podfile platform | commented out | `platform :ios, '13.0'` |
| Crashlytics dSYMs | never uploaded | `[Firebase] Upload Crashlytics dSYMs` build phase |

Two of these were hard blockers:

- **`com.example.*` bundle IDs are rejected at upload** (ITMS-90046 / invalid
  bundle ID), and `com.example.shadappClient` did not match the `com.shad.shadapp`
  app registered in the Firebase project — push would never have worked.
- **`GoogleService-Info.plist` was not bundled into the app.** It existed at
  `ios/Runner/GoogleService-Info.plist` but had no Xcode file reference, so
  `Firebase.initializeApp()` would have crashed on launch on a real device.
  This is the kind of thing that passes in the simulator and fails in review.

The alpha channel on the icons would have produced an `ITMS-90717` rejection
email after upload. The alpha was fully opaque, so flattening changed nothing
visually.

---

## 2. One-time Apple setup **[you]**

1. **Apple Developer Program** membership ($99/yr) — <https://developer.apple.com/programs/>.
2. **App ID**: Certificates, Identifiers & Profiles → Identifiers → `+` →
   App IDs → App. Bundle ID `com.shad.shadapp` (explicit).
   Enable capability: **Push Notifications**.
3. **APNs key** (needed for Firebase push): Keys → `+` → Apple Push Notifications
   service (APNs) → download the `.p8` **once** (it cannot be re-downloaded).
   Note the **Key ID** and your **Team ID**.
4. **Firebase**: Project Settings → Cloud Messaging → iOS app `com.shad.shadapp`
   → upload the `.p8` with its Key ID and Team ID.
   Without this step push silently fails on iOS even though it works on Android.
5. **App Store Connect**: <https://appstoreconnect.apple.com> → Apps → `+` →
   New App. Platform iOS, bundle ID `com.shad.shadapp`, SKU e.g. `shadapp-client`.

### Set the signing team in Xcode

```
open ios/Runner.xcworkspace
```
Runner target → Signing & Capabilities → check *Automatically manage signing* →
pick your Team. Do this for **Debug, Release and Profile** tabs.

This writes `DEVELOPMENT_TEAM` into `project.pbxproj` — it is the only build
setting still missing, and it is deliberately not committed because it is
account-specific. Confirm **Push Notifications** shows up under Capabilities
(it will, from the entitlements files).

---

## 3. Build and upload

```bash
flutter clean
flutter pub get
cd ios && pod install && cd ..
flutter build ipa
```

**Do not skip `flutter clean`, and do not archive straight from Xcode after a
Simulator run.** Flutter (3.41) caches release builds without tracking the
native-asset frameworks in `build/native_assets/ios/`, so a cached release build
can embed the Simulator `objective_c.framework` left by the last `flutter run`.
App Store Connect rejects that with "unsupported architectures [x86_64]" /
"Missing 64-bit support". `ios/scripts/check_device_frameworks.sh` (run from the
Thin Binary phase) now fails the build with an error if this happens.

The IPA lands at `build/ios/ipa/*.ipa`. Upload with either:

- **Xcode**: `open build/ios/archive/Runner.xcarchive` → Distribute App →
  App Store Connect.
- **Transporter** app (App Store, free) — drag the `.ipa` in.
- **CLI**: copy `ios/ExportOptions.plist.template` to `ios/ExportOptions.plist`,
  fill in `YOUR_TEAM_ID`, then
  `flutter build ipa --export-options-plist=ios/ExportOptions.plist` and
  `xcrun altool --upload-app -f build/ios/ipa/*.ipa -u <apple-id> -p <app-specific-password>`.

Version numbers come from `pubspec.yaml` (`version: 1.0.0+2` → `CFBundleShortVersionString`
1.0.0, `CFBundleVersion` 2). **Every upload needs a higher build number**, even
for the same version string — bump the `+N`.

---

## 4. App Store Connect listing **[you]**

Reuse the copy in [`docs/play-store-listing.txt`](play-store-listing.txt); the
App Store fields differ slightly:

| Field | Limit | Source |
|---|---|---|
| App name | 30 | `ShadApp` |
| Subtitle | 30 | shorten the Play "short description" |
| Promotional text | 170 | optional, editable without review |
| Description | 4000 | Play full description works as-is |
| Keywords | 100 total, comma-separated | no spaces after commas |
| Support URL | required | must be a live page |
| Privacy Policy URL | required | host [`docs/privacy-policy.html`](privacy-policy.html) publicly first |

**Screenshots** — required sizes (App Store is stricter than Play):
- 6.9" iPhone (1320×2868 or 2868×1320) — **required**
- 6.5" iPhone (1284×2778 / 1242×2688) — **required**
- 13" iPad (2064×2752) — **required only if** you keep iPad support

The app is currently built for iPhone **and** iPad (`TARGETED_DEVICE_FAMILY = "1,2"`).
If you do not want to produce iPad screenshots and test iPad layouts, set that to
`"1"` in Xcode (Runner → General → Supported Destinations) before submitting.

### App Privacy questionnaire

Based on what the code actually collects, declare at minimum:
- **Contact info** (name, email) — linked to identity, app functionality
- **User content** (messages, documents, signatures) — linked, app functionality
- **Location** (coarse/precise) — linked, app functionality *(check-in feature)*
- **Identifiers** (FCM token) — linked, app functionality
- **Diagnostics** (crash data via Crashlytics) — not linked, analytics

---

## 5. Review notes — read this before submitting

**The app is login-only; there is no in-app sign-up.** A reviewer who cannot get
past the login screen rejects under Guideline 2.1 within a day. In App Store
Connect → App Review Information you **must**:

1. Tick *Sign-in required*.
2. Provide a **working demo account** (username + password) on a seeded
   environment with a populated workspace — chat messages, a contract, a meeting,
   a payment — so the reviewer can see the features the listing describes.
3. In Notes, explain the model: clients are onboarded by their account manager,
   so accounts are provisioned by the business rather than self-registered.

Other likely review questions:

- **Account deletion** (Guideline 5.1.1(v)) applies to apps that support account
  *creation*. This app does not, so it is defensible — but be ready to say so in
  Notes, and point to the support contact for deletion requests. If Apple pushes
  back, the fix is an in-app "delete my account" action in Settings.
- **Location**: `NSLocationWhenInUseUsageDescription` is set and the check-in
  flow is clearly tied to it. Make sure the demo account can reach that screen.
- **Payments**: the app handles contract/invoice payments between a business and
  its client. That is a "physical goods and services" case, exempt from In-App
  Purchase under Guideline 3.1.3(e) / 3.1.5(a). Say this explicitly in Notes —
  reviewers frequently flag any payment UI as missing IAP.
- **Zoom join links** open in Safari via `LaunchMode.externalApplication`, which
  is fine; no `LSApplicationQueriesSchemes` entry is needed for https links.

---

## 6. Pre-submission smoke test on a real device

The simulator does not exercise push, and push is the thing most likely to be
broken. On a physical iPhone with a release/TestFlight build:

- [ ] App launches (proves `GoogleService-Info.plist` is bundled)
- [ ] Notification permission prompt appears
- [ ] A test push from Firebase Console arrives in foreground **and** background
- [ ] Tapping a push opens the right screen
- [ ] Camera and photo picker both work
- [ ] Location check-in works
- [ ] File download / document open works
- [ ] Icon renders on the home screen with no black or transparent corners

Ship to **TestFlight internal testing** first — it runs the same upload
validation as a real submission but has no review queue, so bundle-level
problems surface in minutes rather than days.
