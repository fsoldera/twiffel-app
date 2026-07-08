# Task 000 — Bootstrap a new app from this template

Use this checklist when creating a new U-Things app from
**u-things-app-template** (GitHub → Use this template).

---

## 1. Create the repo

- [ ] GitHub → **Use this template** → name: `<app-name>-app`
- [ ] Clone locally and open in your IDE

---

## 2. Rename and customize Flutter

Search/replace across the repo (carefully — review each match):

| Placeholder | Replace with |
|---|---|
| `My App` / `kAppName` | Your display name |
| `uthings_app_template` | `my_app` (package name) |
| `com.uthings.uthings_app_template` | `com.uthings.myapp` (bundle ID) |
| `my_app_pro`, `my_app_unlock`, `my_app_monthly` | Your RevenueCat product IDs |
| `my-app-api` | `<app>-api` (Worker name) |

Files to edit first:

- [ ] `lib/src/config/app_config.dart` — name, licensing, products, nag copy, theme
- [ ] `pubspec.yaml` — `name`, `description`
- [ ] `android/app/build.gradle.kts` — `applicationId`, namespace
- [ ] `android/app/src/main/kotlin/.../MainActivity.kt` — package path
- [ ] `ios/Runner.xcodeproj` — bundle identifier (Xcode or Codemagic)
- [ ] Replace `assets/logo.png` with your brand mark

---

## 3. Cloudflare Worker + secrets chain

Follow **`harness/infrastructure-setup.md` steps 1–3** (xAI → Doppler → Worker).
Key rule: **one app = one set of secrets**, everything prefixed `<APP>_*`.

- [ ] xAI key named `<app>`; Doppler project `<app>` with `<APP>_XAI_API_KEY` / `<APP>_XAI_MODEL`
- [ ] Rename worker in `backend/wrangler.toml` (`name`, analytics dataset, `DOPPLER_PROJECT`)
- [ ] Rename env keys in `backend/src/ai.ts` to `<APP>_XAI_*` (resolved via Doppler)
- [ ] `cd backend && npm install && npm run deploy`
- [ ] `npx wrangler secret put DOPPLER_SERVICE_TOKEN` (prd token)
- [ ] Note the deployed URL for `<APP>_API_BASE`

---

## 4. Customize app logic

- [ ] Replace `lib/src/pages/home_page.dart` with your real UX
- [ ] Replace or extend `lib/src/state/session_controller.dart`
- [ ] Tune `backend/src/prompts.ts` for your domain
- [ ] Update `harness/feedforward.md` with your product spec
- [ ] Add `tasks/task-001-<feature>.md` for your first real task

---

## 5. RevenueCat + stores (when ready)

Follow **`harness/infrastructure-setup.md` steps 5–8** (keystore → Play → RevenueCat
→ App Store Connect). Watch the gotchas: identifiers are immutable, the Play Console
"API access" page no longer exists (invite the service account as a user), and Play
builds need the `goog_…` key — `test_…` gives "Wrong API key" on launch.

- [ ] Create RevenueCat project + entitlement + products (exact IDs from `app_config.dart`)
- [ ] App Store Connect + Google Play Console listings
- [ ] Wire real paywall (kit `PaywallScreen` or custom shop page)
- [ ] Set `kPrivacyPolicyUrl` / `kTermsOfUseUrl` in `lib/src/config/app_config.dart`
      and confirm the shop page shows both links + subscription disclosure
      (App Store guideline 3.1.2(c))
- [ ] Confirm the shop page names only the current store, never both
      (guideline 2.3.10)
- [ ] App Store Connect: add the privacy policy link (Privacy Policy field) and
      the EULA link (App Description or EULA field)
- [ ] Ensure any promoted IAP / win-back promotional images contain no price text
      (guideline 2.3.2)

---

## 6. Codemagic

Follow **`harness/infrastructure-setup.md` step 4**. Do **not** share env groups with
other apps — app-prefixed groups only, and group names must match `codemagic.yaml`
exactly. Start builds from the **codemagic.yaml** tab, not the Workflow Editor.

- [ ] Rename groups + variables in `codemagic.yaml` to `<app>_github`,
      `<app>_runtime`, `<app>_secrets` / `<APP>_*` vars
- [ ] Create those groups on the app's Environment variables page (after switching
      to codemagic.yaml mode — switching can wipe variables entered before)
- [ ] Set `<APP>_GITHUB_TOKEN`, `<APP>_API_BASE`, `<APP>_RC_KEY_IOS`,
      `<APP>_RC_KEY_ANDROID`, `<APP>_CM_KEYSTORE*`
- [ ] Run Android + iOS smoke workflows

---

## 7. u-things-web (separate repo)

- [ ] Add `src/pages/apps/<app>.astro`
- [ ] Add `src/pages/privacy/<app>.astro`
- [ ] Add `AppCard` on homepage
- [ ] Add logo to `public/`

---

## 8. Verify

```bash
flutter pub get
flutter analyze
flutter test
cd backend && npm run typecheck
```

---

## 9. Safety checklist

- [ ] All free-text input passes `validateTaskInput()` before AI calls
- [ ] AI output validated with kit helpers (+ Worker `tone.ts` if using backend AI)
- [ ] Analytics sends only allowlisted events, no task text
- [ ] Privacy policy published on u-things-web before store submission
- [ ] In-app Privacy Policy + Terms of Use (EULA) links open correctly on iOS
      and Android (guideline 3.1.2(c))
- [ ] No cross-store references in the binary (guideline 2.3.10)
