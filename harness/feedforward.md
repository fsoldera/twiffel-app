# Harness Feedforward — twiffel-app

Product harness for **Twiffel** (bootstrapped from u-things-app-template).

---

## 1. Project Objective

```text
Ship Twiffel: native Flutter (Android + iOS), common_app_kit for cross-cutting
concerns, Cloudflare Worker (twiffel-api) for server-side AI, Codemagic CI, and
u-things-web pages for marketing + privacy.
```

---

## 2. Architecture (all U-Things apps)

```text
- Native Flutter app (Dart), Android + iOS only. No web build.
- common_app_kit (pinned git tag): licensing/nag/paywall, LocalStore, tone/safety, UI helpers.
- go_router for navigation.
- backend/: Cloudflare Worker — xAI proxy + anonymous analytics.
- Secrets SoT: Doppler (per-app project). Worker + Codemagic consume Doppler.
  Never put xAI keys in the mobile app. RC goog_/appl_ are public SDK keys but
  still live in Doppler and are injected at build time as dart-defines.
- Naming: every app secret is `<APP>_`-prefixed (`TWIFFEL_XAI_API_KEY`, not bare
  `XAI` for new apps). One app = one Doppler project = one xAI console key.
  See harness/harness-maintenance.md.
- Marketing + privacy: u-things-web repo (separate).
- CI: Codemagic (cloud iOS + Android builds).
- Store launch: harness/store-launch-checklist.md + infrastructure-setup.md.
- When setup lessons appear, update the harness immediately (harness-maintenance.md).
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
Dart-defines (injected at build time via Codemagic or flutter run).
One app = one set of secrets, nothing shared between apps:
- TWIFFEL_API_BASE       — Worker URL (empty = local fallback, analytics no-op)
- TWIFFEL_RC_KEY_IOS     — RevenueCat Apple public key (empty = honor-system nag only)
- TWIFFEL_RC_KEY_ANDROID — RevenueCat Google public key

Customize in lib/src/config/app_config.dart:
- kAppName, LicenseConfig, product IDs, nag copy, theme
- Android monthly id is productId:basePlanId; iOS keeps bare monthly id
- Terms: Apple EULA on iOS only; empty on Android

Full external-tool setup (xAI, Doppler, Cloudflare, Codemagic, Play, RevenueCat):
harness/infrastructure-setup.md
Store + RC launch order / gotchas:
harness/store-launch-checklist.md
```

---

## 5. App Store / Play compliance (any purchase flow)

```text
- No cross-store references in the binary: the shop/paywall must name only the
  store running the app (no "Google Play" text on iOS, no "App Store" on
  Android). Derive it at runtime (see ShopPage._storeName or the kit's
  platformStoreName()). — App Store guideline 2.3.10.
- The purchase flow must show functional Privacy Policy and Terms of Use (EULA)
  links, plus (for subscriptions) title, length, price, and an auto-renewal
  disclosure. URLs live in lib/src/config/app_config.dart
  (kPrivacyPolicyUrl / kTermsOfUseUrl). — App Store guideline 3.1.2(c).
- url_launcher opens those links; Android needs the https VIEW <queries> intent
  in AndroidManifest.xml for them to open on Android 11+.
- Store metadata (App Store Connect / Play Console) must also carry a privacy
  policy link and (for subscriptions) the EULA link — this is a listing step in
  task-000, not a code change.
- Promoted in-app purchase / win-back images must not contain price text.
```

---

## 6. Forbidden Actions

```text
- Do not ship xAI keys in the mobile app.
- Do not add real billing enforcement that gates features (WinRAR-style nag only until approved).
- Do not persist user content/PII in LocalStore.
- Do not add per-user behavioral tracking.
- Do not hard-code a store name or reference a store other than the current
  platform's in the app binary.
- Do not use "--" or "—" as punctuation in generated prose; use a comma ","
  (see harness/writing-style.md).
```

---

## 7. Verification

```text
- flutter analyze
- flutter test
- cd backend && npm run typecheck (when backend changes)
```
