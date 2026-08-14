# Task 001 — First iOS/Android signed builds

Wire Codemagic + Doppler so Twiffel produces a Play-uploadable `.aab` and a
TestFlight IPA. RevenueCat keys can stay empty for the first binaries (honor/nag).

Use with `harness/infrastructure-setup.md` and `harness/store-launch-checklist.md`.

---

## Goal

```text
- Doppler is secrets SoT (project twiffel).
- Codemagic holds only twiffel_ci + twiffel_runtime (+ ASC integration).
- Android workflow builds a signed release .aab.
- iOS signed workflow submits to Internal TestFlight.
- twiffel-api Worker is deployed and TWIFFEL_API_BASE points at it.
```

---

## Repo (agent)

- [x] Harden root `.gitignore` for keystores / `.env` / Apple keys / Play JSON
- [x] Release signing via `android/key.properties` in `android/app/build.gradle.kts`
- [x] `codemagic.yaml`: Doppler-first groups, keystore decode, `ios-signed` + TestFlight
- [x] This task file

---

## Phase 0 — Doppler (human)

Project `twiffel`, configs `dev` / `prd` / `ci`:

| Secret | Config | Notes |
|---|---|---|
| `TWIFFEL_XAI_API_KEY` | `dev`, `prd` | Canonical. Twiffel currently also has legacy bare `XAI` (Worker accepts both). Next apps: prefixed only. |
| `TWIFFEL_XAI_MODEL` | `dev`, `prd` | e.g. `grok-4.3` |
| `TWIFFEL_XAI_REASONING_EFFORT` | `dev`, `prd` | `none` / `low` / `medium` / `high` (default `low`) |
| `TWIFFEL_XAI_TEMPERATURE` | `dev`, `prd` | `0` to `2` (default `0.7`) |
| `TWIFFEL_XAI_BASE_URL` | `dev`, `prd` | `https://eu-west-1.api.x.ai/v1` |
| `TWIFFEL_GITHUB_TOKEN` | `ci` | GitHub PAT with access to `common-app-kit` |
| `TWIFFEL_CM_KEYSTORE` | `ci` | base64 of `twiffel-upload.jks` |
| `TWIFFEL_CM_KEYSTORE_PASSWORD` | `ci` | |
| `TWIFFEL_CM_KEY_ALIAS` | `ci` | `twiffel-upload` |
| `TWIFFEL_CM_KEY_PASSWORD` | `ci` | |
| `TWIFFEL_RC_KEY_ANDROID` | `ci` | later (`goog_…`) |
| `TWIFFEL_RC_KEY_IOS` | `ci` | later (`appl_…`) |

Service tokens:

- `twiffel-api-prd` (config `prd`) → Cloudflare Worker secret `DOPPLER_SERVICE_TOKEN` (already set)
- `twiffel-codemagic-ci` (config `ci`) → Codemagic `DOPPLER_TOKEN` in group `twiffel_ci`

Create / rotate the Codemagic token (shown once):

```powershell
doppler configs tokens create --name twiffel-codemagic-ci --project twiffel --config ci --plain
```

Also set in Codemagic group `twiffel_ci` (non-secret):

- `DOPPLER_PROJECT` = `twiffel`
- `DOPPLER_CONFIG` = `ci`

Doppler `ci` is empty until you add `TWIFFEL_GITHUB_TOKEN` + `TWIFFEL_CM_KEYSTORE*` (and later RC keys).

---

## Phase 1 — Worker deploy

```powershell
cd backend
npm install
npm run deploy
# Prefer: doppler configs tokens create --name twiffel-api-prd --project twiffel --config prd --plain
# then pipe into:
#   cmd /c "doppler ... --plain | npx wrangler secret put DOPPLER_SERVICE_TOKEN"
```

Live URL: `https://twiffel-api.franco-soldera.workers.dev`

Status: Worker deployed; `DOPPLER_SERVICE_TOKEN` set; Doppler `prd` has `XAI`.

Smoke (PowerShell — prefer `Invoke-RestMethod`):

```powershell
Invoke-RestMethod -Method Post `
  -Uri "https://twiffel-api.franco-soldera.workers.dev/api/analyze" `
  -ContentType "application/json" `
  -Body '{"mode":"comparison","optionA":"keep the bike","optionB":"buy a car","obstacle":"Cost / money","timing":"In the next few months"}'
```

Put that URL in Codemagic group `twiffel_runtime` as `TWIFFEL_API_BASE`.

---

## Phase 3 — Android upload keystore (human, once)

Never commit the `.jks`. Generate at repo root (gitignored):

```powershell
# PKCS12: use the SAME password for store and key (-keypass is ignored if different).
keytool -genkeypair -v `
  -keystore twiffel-upload.jks `
  -alias twiffel-upload `
  -keyalg RSA -keysize 2048 -validity 10000 `
  -storepass <SAME_PW> -keypass <SAME_PW> `
  -dname "CN=Twiffel, OU=U-Things, O=Franco Soldera, C=DK"

[Convert]::ToBase64String([IO.File]::ReadAllBytes("twiffel-upload.jks")) | Set-Clipboard
```

Paste base64 + passwords into Doppler `ci` as `TWIFFEL_CM_*`. Back up `.jks` + passwords
in a password manager. Do not regenerate after the first Play `.aab` upload.

---

## Phase 3 — Codemagic dashboard (human)

1. Connect GitHub repo `twiffel-app` as a Codemagic application.
2. Switch the app to **codemagic.yaml** mode (variables can wipe when switching).
3. Environment variable groups (names must match YAML exactly):

   | Group | Variable | Secret? |
   |---|---|---|
   | `twiffel_ci` | `DOPPLER_TOKEN` | yes |
   | `twiffel_ci` | `DOPPLER_PROJECT` = `twiffel` | no |
   | `twiffel_ci` | `DOPPLER_CONFIG` = `ci` | no |
   | `twiffel_runtime` | `TWIFFEL_API_BASE` | no |

4. Integrations → App Store Connect API key named **`twiffel_asc`**.
5. Start builds from the **codemagic.yaml** tab:
   - **Twiffel iOS (smoke)** first (proves PAT + pods)
   - **Twiffel Android** (signed `.aab`)
   - **Twiffel iOS (signed)** (TestFlight)

---

## Phase 4 — Store shells (human)

### Google Play

1. Create app with package `com.uthings.twiffel` (permanent).
2. Upload Codemagic `.aab` → Internal testing → roll out.
3. Add your Gmail as tester; copy opt-in link (no store search / no email).
4. Settings → License testing → add yourself.
5. Clear dashboard blockers (privacy URL, content rating, target audience, app access).

### App Store Connect

1. Create app for bundle `com.uthings.twiffel`.
2. Run **Twiffel iOS (signed)** → Internal TestFlight.
3. External beta `422` on `betaAppReviewSubmissions` can still leave Internal Testing OK.

---

## Phase 5 — RevenueCat (after binaries)

IDs already frozen in `lib/src/config/app_config.dart`:

- Entitlement `twiffel_pro`
- Lifetime `twiffel_unlock`
- Monthly `twiffel_monthly` (Android `twiffel_monthly:monthly`)

Follow `harness/store-launch-checklist.md`, store `goog_…` / `appl_…` in Doppler, rebuild.

---

## Sensors

```bash
flutter analyze
flutter test
cd backend && npm run typecheck
```

Codemagic workflows are the build sensors for signed artifacts.

---

## Done when

- [x] `twiffel-api` live; `/api/analyze` returns decision analysis (Doppler `XAI` wired)
- [ ] Codemagic Android produces a signed `.aab`
- [ ] Codemagic iOS signed lands Internal TestFlight
- [ ] Doppler `ci` holds GitHub PAT + keystore (+ later RC keys); Codemagic is thin
- [ ] No keystores or secrets committed
