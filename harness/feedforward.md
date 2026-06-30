# Harness Feedforward — u-things-app-template

This is the **canonical harness** for new U-Things native apps. When you copy
this template to create a new app, customize `harness/feedforward.md` with your
product spec (see `tasks/task-000-bootstrap.md`).

---

## 1. Project Objective

```text
Bootstrap a new U-Things app: native Flutter (Android + iOS), common_app_kit for
cross-cutting concerns, Cloudflare Worker for server-side AI, Codemagic CI, and
u-things-web pages for marketing + privacy.
```

---

## 2. Architecture (all U-Things apps)

```text
- Native Flutter app (Dart), Android + iOS only. No web build.
- common_app_kit (pinned git tag): licensing/nag/paywall, LocalStore, tone/safety, UI helpers.
- go_router for navigation.
- backend/: Cloudflare Worker — xAI proxy + anonymous analytics.
- Secrets: XAI_API_KEY in Cloudflare Workers secrets (wrangler secret put).
- No Doppler in the default template (optional upgrade for multi-service setups).
- Marketing + privacy: u-things-web repo (separate).
- CI: Codemagic (cloud iOS + Android builds).
```

---

## 3. Safety (non-negotiable)

```text
- Input: validateTaskInput() from common_app_kit BEFORE any AI call (client).
- Output: isSafePracticalStep / isSafeCompassionateMessage on client; tone.ts mirror on Worker.
- Any change to tone_policy.dart → update tests + consider mirroring in backend/src/tone.ts.
- AI prompts are app-specific (backend/src/prompts.ts) but must stay compassionate and safe.
- Anonymous analytics only: event name + coarse platform. No task text, no PII.
```

---

## 4. Configuration

```text
Dart-defines (injected at build time via Codemagic or flutter run):
- APP_API_BASE       — Worker URL (empty = local fallback, analytics no-op)
- APP_RC_KEY_IOS     — RevenueCat Apple public key (empty = honor-system nag only)
- APP_RC_KEY_ANDROID — RevenueCat Google public key

Customize in lib/src/config/app_config.dart:
- kAppName, LicenseConfig, product IDs, nag copy, theme
```

---

## 5. Forbidden Actions

```text
- Do not ship xAI keys in the mobile app.
- Do not add real billing enforcement that gates features (WinRAR-style nag only until approved).
- Do not persist user content/PII in LocalStore.
- Do not add per-user behavioral tracking.
```

---

## 6. Verification

```text
- flutter analyze
- flutter test
- cd backend && npm run typecheck (when backend changes)
```
