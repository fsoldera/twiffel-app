# u-things-app-template

**GitHub template** for new [U-Things](https://u-things.com) native apps.

Copy this repo to start a new Flutter app with the standard U-Things stack:

- **Flutter** (Android + iOS only — no web build)
- **[common_app_kit](https://github.com/fsoldera/common-app-kit)** — licensing, nag, tone/safety, storage
- **Cloudflare Worker** — server-side xAI proxy + anonymous analytics
- **Harness Engineering** — agent feedforward, sensors, tasks
- **Codemagic** — cloud builds (no Mac required)

Reference implementation: [joppling-app](https://github.com/fsoldera/joppling-app).

---

## Quick start

### 1. Create from template

GitHub → **Use this template** → create `<your-app>-app`.

Follow **`tasks/task-000-bootstrap.md`** for the full checklist.

### 2. Run locally

```bash
flutter pub get
flutter analyze
flutter test

# Optional: point at a deployed Worker
flutter run --dart-define=APP_API_BASE=https://my-app-api.<subdomain>.workers.dev
```

Without `APP_API_BASE`, the template uses **local fallback** steps and honor-system licensing.

### 3. Backend

```bash
cd backend
npm install
cp .dev.vars.example .dev.vars   # Doppler service token for config `dev`
npm run dev

# Deploy
npm run deploy
npx wrangler secret put DOPPLER_SERVICE_TOKEN   # prd service token
```

**Secrets SoT is Doppler** (per-app project): xAI keys for the Worker, and later
RevenueCat `goog_…` / `appl_…` for Codemagic builds. The Worker reads Doppler via
`DOPPLER_SERVICE_TOKEN`. See `harness/infrastructure-setup.md` and
`harness/store-launch-checklist.md`.

---

## Project layout

```text
lib/src/
  config/app_config.dart    ← customize name, licensing, dart-defines
  pages/                    ← replace home/shop with your UX
  services/                 ← AiClient, Analytics
  state/                    ← example SessionController
backend/                    ← Cloudflare Worker (rename before deploy)
harness/                    ← canonical agent harness
  infrastructure-setup.md   ← xAI → Doppler → Worker → Codemagic → stores
  store-launch-checklist.md ← Play / RC / ASC gotchas (Stikkteller lessons)
tasks/task-000-bootstrap.md ← new-app checklist
scripts/export-iap-review-screenshot.py ← ASC IAP review image sizes
codemagic.yaml              ← CI (Doppler preferred; env groups as fallback)
```

---

## Dart-defines

| Define | Purpose |
|---|---|
| `APP_API_BASE` | Worker URL for AI + analytics |
| `APP_RC_KEY_IOS` | RevenueCat Apple public key |
| `APP_RC_KEY_ANDROID` | RevenueCat Google public key |

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
| `joppling-app` | First shipped app (reference, do not fork for new apps — use this template) |

---

## Agents

See `AGENTS.md` and `harness/feedforward.md` before making changes.
