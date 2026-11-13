# Account deletion (App Store Guideline 5.1.1(v))

Apple rejected the build because the app shows a sign-up screen but had no
way to delete an account from inside the app.

The first fix (`caa5276`) was lost in the merge of upstream's Luxe redesign
(`e153b6f`): upstream never had the button, so both settings pages came back
without it, and Apple rejected the next build for the same reason. Upstream
still doesn't have it, so **check the deletion tests after every merge from
upstream** (see below).

## Where it is in the app

| Role                                  | Path                                                  |
| ------------------------------------- | ----------------------------------------------------- |
| Client (active workspace)             | Avatar → Settings → bottom of the page                |
| Client (still onboarding)             | Avatar → Settings → bottom of the page                |
| Sub-user                              | Avatar → Settings → bottom of the page                |
| Account manager / assistant / SA      | Avatar → Settings → bottom of the page                |
| Staff member / accountant             | Avatar → Settings (`/profile`) → bottom of the page   |

Flow: *Delete account* → confirmation dialog explaining what's deleted and
what's retained → password re-entry → *Delete permanently* → signed out,
back on the login screen with "Your account has been deleted."

Code: `lib/features/settings/delete_account_button.dart`,
`AuthProvider.deleteAccount()`.

Tests that fail if a screen loses the entry point, to run after a merge:

```bash
flutter test test/widget/settings_page_test.dart test/widget/admin_settings_page_test.dart test/widget/profile_page_test.dart test/widget/client_onboarding_screen_test.dart test/widget/delete_account_button_test.dart
```

## Backend contract

```
DELETE /api/auth/account          (auth:sanctum)
Content-Type: application/json
{ "password": "<current password>" }
```

The route is live in production (checked 2026-11-06: `GET /api/auth/account`
answers 405 with `Allow: DELETE`). Its behaviour for each role has not been
tested from the app yet.

One route for every account type: resolve the account from the token
(`$request->user()` is the `User`, `Client` or `SubUser` the token belongs to).
It has to stay open to every role, including those `restrict.roles` walls off
(accountant) — otherwise they see the button and get a 403.

| Outcome                    | Response                                                       |
| -------------------------- | -------------------------------------------------------------- |
| Deleted                    | `200` or `204`                                                 |
| Wrong / missing password   | `422` with `errors.password` — **never 401**                   |
| Not allowed for this account (e.g. the last super admin) | `403` with a `message` — shown to the user as-is |

A 401 must not be used for the wrong-password case: the app treats any 401 as
"session expired", clears the token and jumps to the login screen mid-dialog.

What the deletion has to do (matches section 11 of the privacy policy):

- Revoke **all** Sanctum tokens for the account and delete its FCM device
  tokens — the app does not call `/auth/logout` or
  `/notifications/unregister-token` afterwards.
- Delete the profile, credentials and avatar; remove or anonymize chat
  messages.
- **Client:** also delete or deactivate its sub-users (the dialog warns the
  owner that their team loses access).
- Keep contracts, signatures, payment records and audit entries only where the
  law requires it, detached from personal data where possible, then delete
  them after the retention period.
- Make the deletion a real deletion (or anonymization), not a deactivation
  flag that can be turned back on. Apple rejects "deactivate" as insufficient.

## App Review

Reply to the rejection with a screen recording **from a physical device**
showing: signing in with the demo account → Settings → *Delete account* →
password → confirmation → back on the login screen. Use a disposable copy of
the demo account for the recording, then re-seed the demo account so the
reviewer can still sign in.
