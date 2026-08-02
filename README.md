# twiffel-app

**Twiffel** — a [U-Things](https://u-things.com) native app.

Stack:

- **Flutter** (Android + iOS only — no web build)
- **[common_app_kit](https://github.com/fsoldera/common-app-kit)** — licensing, nag, tone/safety, storage
- **Cloudflare Worker** (`twiffel-api`) — server-side xAI proxy + anonymous analytics
- **Harness Engineering** — agent feedforward, sensors, tasks
- **Codemagic** — cloud builds (no Mac required)

Bootstrapped from [u-things-app-template](https://github.com/fsoldera/u-things-app-template).

---

## Quick start

### 1. Run locally

```bash
flutter pub get
flutter analyze
flutter test

# Point at Worker (never put xAI keys in the Flutter app)
flutter run --dart-define=TWIFFEL_API_BASE=http://10.0.2.2:8787   # Android emulator -> local Worker
# flutter run --dart-define=TWIFFEL_API_BASE=https://twiffel-api.<subdomain>.workers.dev
```

Without `TWIFFEL_API_BASE`, the app uses **local fallback** analysis (no remote AI).

### 2. Backend

```bash
cd backend
npm install
# Load xAI from Doppler into gitignored .dev.vars (secret name: XAI, config: prd)
powershell -File scripts/write-dev-vars-from-doppler.ps1
npm run dev

# Deploy
npm run deploy
npx wrangler secret put DOPPLER_SERVICE_TOKEN   # prd service token (prod Worker fetches Doppler)
```

**Secrets SoT is Doppler** (project `twiffel`): the Worker resolves `XAI` (or
`TWIFFEL_XAI_API_KEY`) at runtime. Flutter only gets `TWIFFEL_API_BASE`. See
`harness/infrastructure-setup.md` and `harness/store-launch-checklist.md`.

---

## Project layout

```text
lib/src/
  config/app_config.dart    ← name, licensing, dart-defines
  pages/                    ← home/shop UX
  services/                 ← AiClient, Analytics
  state/                    ← SessionController
backend/                    ← Cloudflare Worker (twiffel-api)
harness/                    ← agent harness
tasks/task-000-bootstrap.md ← original template checklist (reference)
codemagic.yaml              ← CI (Doppler preferred; env groups as fallback)
```

---

## Dart-defines

| Define | Purpose |
|---|---|
| `TWIFFEL_API_BASE` | Worker URL for AI + analytics |
| `TWIFFEL_RC_KEY_IOS` | RevenueCat Apple public key |
| `TWIFFEL_RC_KEY_ANDROID` | RevenueCat Google public key |

---

## Identifiers

| Kind | Value |
|---|---|
| Display name | Twiffel |
| Dart package | `twiffel_app` |
| Bundle / application ID | `com.uthings.twiffel` |
| Worker | `twiffel-api` |
| Doppler project | `twiffel` |

---

## Safety

- **Input/output AI safety** lives in `common_app_kit` (`tone_policy.dart`) — canonical for all apps.
- Client validates before/after AI calls; Worker mirrors output checks in `backend/src/tone.ts`.
- When you extend patterns in the kit, update tests and mirror on the server.

---

## Related repos

| Repo | Role |
|---|---|
| `common-app-kit` | Shared Flutter library |
| `u-things-web` | Marketing + privacy pages |
| `u-things-app-template` | Template this app was created from |

---

## Agents

See `AGENTS.md` and `harness/feedforward.md` before making changes.
