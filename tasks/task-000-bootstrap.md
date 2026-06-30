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

## 3. Cloudflare Worker

- [ ] Rename worker in `backend/wrangler.toml` (`name`, analytics dataset)
- [ ] `cd backend && npm install`
- [ ] `npx wrangler secret put XAI_API_KEY`
- [ ] `npm run deploy`
- [ ] Note the deployed URL for `APP_API_BASE`

---

## 4. Customize app logic

- [ ] Replace `lib/src/pages/home_page.dart` with your real UX
- [ ] Replace or extend `lib/src/state/session_controller.dart`
- [ ] Tune `backend/src/prompts.ts` for your domain
- [ ] Update `harness/feedforward.md` with your product spec
- [ ] Add `tasks/task-001-<feature>.md` for your first real task

---

## 5. RevenueCat + stores (when ready)

- [ ] Create RevenueCat project + entitlement + products
- [ ] App Store Connect + Google Play Console listings
- [ ] Wire real paywall (kit `PaywallScreen` or custom shop page)

---

## 6. Codemagic

- [ ] Copy `codemagic.yaml` env groups from Joppling as reference
- [ ] Create groups: `github_credentials`, `<app>_runtime`, `app_secrets`
- [ ] Set `APP_API_BASE`, `APP_RC_KEY_IOS`, `APP_RC_KEY_ANDROID`
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
