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
| `my_app_monthly:monthly` | Android monthly id after Play import |
| `my-app-api` | `<app>-api` (Worker name) |
| `APP_XAI_*` (Worker / Doppler) | `<APP>_XAI_*` |
| `APP_RC_KEY_*` / `APP_API_BASE` | `<APP>_RC_KEY_*` / `<APP>_API_BASE` |

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
Key rule: **Doppler is the secrets SoT**; **one app = one Doppler project**, everything
prefixed `<APP>_*`. Never put xAI keys in the Flutter app.

- [ ] xAI key named `<app>`; Doppler project `<app>` with `<APP>_XAI_API_KEY` / `<APP>_XAI_MODEL`
- [ ] Create worker service tokens (`<app>-worker-dev` / `<app>-worker-prd`); optional
      `<app>-codemagic-ci` for Codemagic
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

Follow **`harness/store-launch-checklist.md`** (short path) and
**`harness/infrastructure-setup.md` steps 5–8** (detail + gotchas).

**Doppler is the secrets SoT** — store `goog_…` / `appl_…` there; Codemagic consumes
them (preferred) or mirrors them once from Doppler. Never invent a second SoT.

- [ ] Freeze product IDs in `lib/src/config/app_config.dart` before dashboards
      (`<app>_pro` / `_unlock` / `_monthly`; Android monthly → `<app>_monthly:monthly`)
- [ ] Play: internal track + products + license tester
- [ ] RevenueCat: Play app → import → entitlement + offering `default` → `goog_…` in Doppler
- [ ] ASC: IAPs (description ≤ 45 chars) + review screenshots via
      `scripts/export-iap-review-screenshot.py`
- [ ] RevenueCat: App Store app + shared IAP `.p8` → `appl_…` in Doppler (key is
      **only** in RevenueCat, never ASC)
- [ ] Wire a real shop (prefer custom plan cards; kit `PaywallScreen` alone shows
      raw store titles)
- [ ] Confirm shop: privacy + iOS EULA links + subscription disclosure (3.1.2(c));
      Android omits Apple EULA (template already platform-resolves terms)
- [ ] Confirm shop names only the current store (guideline 2.3.10)
- [ ] ASC listing: privacy policy + EULA fields; no price text on promo images (2.3.2)

---

## 6. Codemagic

Follow **`harness/infrastructure-setup.md` step 4**. Prefer **Doppler → Codemagic**
(`DOPPLER_TOKEN` + `<APP>_API_BASE`). Fallback: app-prefixed env groups that mirror
Doppler. Group names must match `codemagic.yaml` exactly. Start builds from the
**codemagic.yaml** tab, not the Workflow Editor.

- [ ] Rename groups + variables in `codemagic.yaml` to `<app>_*` / `<APP>_*`
- [ ] Preferred: put RC keys + signing + GitHub PAT in Doppler `ci`/`prd`; Codemagic
      holds only `DOPPLER_TOKEN` (+ `<APP>_API_BASE`)
- [ ] Fallback: create `<app>_github` / `<app>_runtime` / `<app>_secrets` and paste
      values **from Doppler** (after switching to yaml mode — switching can wipe vars)
- [ ] Run Android + iOS smoke workflows; after RC keys exist, rebuild store tracks

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
