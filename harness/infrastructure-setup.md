# Infrastructure Setup Runbook — new U-Things app

Step-by-step guide to wire a new app into all external tools. Written after doing it
the hard way for Stikkteller — follow the order and the gotchas and it should take
under an hour.

Replace `<APP>` with the uppercase app name (e.g. `STIKKTELLER`) and `<app>` with the
lowercase name (e.g. `stikkteller`) everywhere below.

**Golden rule: one app = one set of secrets.** Never share keys between apps
(they outlive each other and rotating one must not break another). Every secret and
variable is prefixed with the app name: `<APP>_*`. The only allowed shared pieces are
the Google Cloud **service account** (per developer account, not per app) and your
personal logins.

---

## Setup order (dependencies flow downward)

```text
1. xAI            → API key exists
2. Doppler        → key stored + service tokens
3. Cloudflare     → Worker deployed, reads Doppler   → gives <APP>_API_BASE URL
4. Codemagic      → GitHub PAT + API base            → CI builds pass
5. Android keystore → signed .aab
6. Google Play    → app created, internal test track
7. RevenueCat     → catalog + goog_ key              → billing works in Play builds
8. App Store Connect → <app>_asc integration         → TestFlight (when iOS ships)
```

Each step only needs outputs from the steps above it. Do them in order.

---

## Step 1 — xAI (console.x.ai)

1. Create a **new API key** named after the app (`<app>`). Do not reuse another
   app's key.
2. Note the model (default: `grok-3-mini`).
3. Keep both in a password manager until step 2.

---

## Step 2 — Doppler (dashboard.doppler.com)

1. **Create a project named after the app** (`<app>`) — do not add configs to
   another app's project.
2. Use the default `dev` and `prd` configs. Add to **both**:

   | Secret | Value |
   |---|---|
   | `<APP>_XAI_API_KEY` | key from step 1 |
   | `<APP>_XAI_MODEL` | `grok-3-mini` |

3. Create **service tokens** — one per config:
   - `<app>-worker-dev` (config `dev`)
   - `<app>-worker-prd` (config `prd`)

> **Gotcha — where are service tokens?** Not on the Secrets page. Left sidebar →
> **Tokens**, or open a config → **Access** tab. Tokens start with `dp.st.`.

> **Gotcha — Cloudflare tokens in Doppler:** not needed. `CLOUDFLARE_API_TOKEN` /
> `CLOUDFLARE_ACCOUNT_ID` are deploy-time credentials, only useful if CI deploys the
> Worker. Local `wrangler login` covers manual deploys.

---

## Step 3 — Cloudflare Worker

Repo config (adjust when bootstrapping):

- `backend/wrangler.toml`: `name = "<app>-api"`, dataset `<app>_events`, `[vars]` with
  `DOPPLER_PROJECT = "<app>"`, `DOPPLER_CONFIG = "prd"`, `<APP>_XAI_MODEL`.
- `backend/src/ai.ts`: rename the env/secret keys to `<APP>_XAI_API_KEY` /
  `<APP>_XAI_MODEL` (resolved from Doppler first, direct Worker env as fallback).

Deploy:

```powershell
cd backend
npm install
npx wrangler login
npm run deploy
npx wrangler secret put DOPPLER_SERVICE_TOKEN   # paste the *prd* token
```

Save the printed URL — it becomes `<APP>_API_BASE`
(e.g. `https://<app>-api.<subdomain>.workers.dev`).

Smoke test (note: **PowerShell's `curl` alias breaks JSON quoting** — use `curl.exe`
with backslash-escaped quotes, or `Invoke-RestMethod`):

```powershell
curl.exe -X POST "https://<app>-api.<subdomain>.workers.dev/api/message" -H "Content-Type: application/json" -d "{\"task\":\"\",\"kind\":\"day_complete\"}"
```

Expect a JSON `message`. `{"error":"Invalid request"}` means the JSON body didn't
parse (quoting problem), not a server failure.

Local dev: copy `backend/.dev.vars.example` → `.dev.vars`, use the **dev** token.

---

## Step 4 — Codemagic (free personal plan)

The free plan has **no team-level variable groups**. Everything lives on
**Applications → \<app\> → Environment variables**, where the *Select group* field
creates groups on first use.

1. Connect the GitHub repo as a new Codemagic application.
2. Switch the app to **codemagic.yaml** mode (a `codemagic.yaml` tab appears once
   the file exists on the default branch).
3. Add variables in these groups (groups must match the `groups:` lists in
   `codemagic.yaml` **exactly**, or builds fail with
   *"references to unknown variable group(s)"*):

   | Group | Variable | Secret? | Value |
   |---|---|---|---|
   | `<app>_github` | `<APP>_GITHUB_TOKEN` | yes | GitHub PAT, `repo` scope, access to `common-app-kit` |
   | `<app>_runtime` | `<APP>_API_BASE` | no | Worker URL from step 3 |
   | `<app>_secrets` | `<APP>_CM_KEYSTORE` | yes | base64 of `.jks` (step 5) |
   | `<app>_secrets` | `<APP>_CM_KEYSTORE_PASSWORD` | yes | |
   | `<app>_secrets` | `<APP>_CM_KEY_ALIAS` | no | `<app>-upload` |
   | `<app>_secrets` | `<APP>_CM_KEY_PASSWORD` | yes | |
   | `<app>_secrets` | `<APP>_RC_KEY_ANDROID` | yes | `goog_…` (step 7) |
   | `<app>_secrets` | `<APP>_RC_KEY_IOS` | yes | `appl_…` (step 8 era) |

> **Gotcha — variables wiped:** switching the app from Workflow Editor to
> codemagic.yaml mode can erase already-entered variables. Re-add them after
> switching, not before.

> **Gotcha — starting builds:** always start builds from the **codemagic.yaml** tab
> and pick the named workflow (e.g. *\<App\> iOS (smoke)*). The blue
> "Start new build" button may offer only "Default Workflow" (Workflow Editor) —
> that is not your YAML.

> **Gotcha — missing Podfile:** if `pod install` fails with *"No `Podfile` found"*,
> the repo lacks `ios/Podfile` — copy the standard Flutter one from this template.

Verify: run **iOS (smoke)** — it proves the PAT, pub get, and CocoaPods work.

---

## Step 5 — Android upload keystore

One keystore **per app**, generated locally, never committed:

```powershell
keytool -genkeypair -v `
  -keystore <app>-upload.jks `
  -alias <app>-upload `
  -keyalg RSA -keysize 2048 -validity 10000 `
  -storepass <STORE_PW> -keypass <KEY_PW> `
  -dname "CN=<App>, OU=U-Things, O=Franco Soldera, C=DK"

[Convert]::ToBase64String([IO.File]::ReadAllBytes("<app>-upload.jks")) | Set-Clipboard
```

Paste the base64 + passwords into the `<app>_secrets` group (step 4 table).
Back up the `.jks` and passwords in a password manager.

> **Gotcha — regeneration:** free to regenerate with new passwords **until the first
> `.aab` is uploaded to Play**. After that the upload key is pinned (reset requires a
> slow Google support flow).

---

## Step 6 — Google Play Console

1. **Create app**: package name **must** equal `applicationId` in
   `android/app/build.gradle.kts` (`com.uthings.<app>`). It is permanent.
2. Build in Codemagic (**Android** workflow) → download the `.aab` artifact.
3. **Test og udgiv → Intern test → Opret udgivelse** → *upload* the `.aab`
   (the "add from library" dialog is empty until a first upload exists).
4. Roll out the release (status must say *available to internal testers*, not draft).
5. **Testers tab**: add your Gmail to a tester list, save, then copy the
   **opt-in link** (`https://play.google.com/apps/test/<package>/...`).

> **Gotcha — nothing "arrives":** Play sends **no email** and the app is **not
> searchable** in the store. The opt-in link is the only entry point: open it on an
> Android phone signed into the tester Gmail → *Become a tester* → install.

> **Gotcha — dashboard blockers:** privacy policy URL, content rating, target
> audience, and app access declarations can block the test link even after rollout.
> Clear the dashboard tasks if the link claims the app is unavailable.

---

## Step 7 — RevenueCat

### Catalog (identifiers are immutable — get them right the first time)

| Object | Identifier (must match `lib/src/config/app_config.dart`) |
|---|---|
| Entitlement | `<app>_pro` |
| One-time product | `<app>_unlock` |
| Monthly subscription | `<app>_monthly` |
| Offering | `default` (packages `$rc_lifetime`, `$rc_monthly`) |

> **Gotcha — identifiers can never be edited**, only display names. A wrong ID means
> delete + recreate (safe while there are no transactions).

Skip the "Install the SDK" wizard code — `common_app_kit` already wraps
`purchases_flutter`; only the dashboard objects and API keys matter.

### Play Store app + service credentials

1. **Apps → New → Play Store**: package `com.uthings.<app>`, upload the
   **service account JSON** (see below).
2. Google Cloud (project `u-things-500622`) — enable **both** APIs:
   - *Google Play Android Developer API*
   - *Cloud Pub/Sub API* (RevenueCat shows a red banner until enabled)
3. Service account `revenuecat-play@u-things-500622.iam.gserviceaccount.com` is
   **shared across all U-Things apps** — reuse the existing JSON key (or mint a new
   key on its *Keys* tab; no new service account needed).

> **Gotcha — the Play Console "API access" page no longer exists** (removed by
> Google). Grant access by *inviting the service account as a user*:
> **Brugere og tilladelser → Inviter nye brugere** → paste the service-account
> email → account permissions: *view app info*, *view financial data*,
> *manage orders and subscriptions* → invite. It turns **Active immediately**
> (service accounts don't accept invitations). Allow ~15 min to propagate.

### API keys

**API keys** page → per-app **SDK** keys (never the secret keys):

- Test Store key `test_…` → only for sideloaded/dev builds.
- Play Store key `goog_…` → required for **any build installed from Google Play**.

> **Gotcha — "Wrong API key" on launch** of a Play-installed build means a `test_`
> key was baked in. Put the `goog_…` key in `<APP>_RC_KEY_ANDROID`, rebuild,
> upload a new `.aab`.

Until keys are set, the app runs in honor/nag-only mode — fine for early testing.

---

## Step 8 — App Store Connect / TestFlight (when iOS ships)

1. App Store Connect: create the app for bundle `com.uthings.<app>`.
2. Codemagic → Integrations → App Store Connect API key, named `<app>_asc`
   (matches `integrations.app_store_connect` in `codemagic.yaml`).
3. Run the **iOS (signed)** workflow — it fetches/creates signing files and submits
   to TestFlight.
4. RevenueCat: add the App Store app, copy the `appl_…` key into
   `<APP>_RC_KEY_IOS`.

---

## Final secret map (who holds what)

| Tool | Names |
|---|---|
| xAI | key labeled `<app>` |
| Doppler project `<app>` | `<APP>_XAI_API_KEY`, `<APP>_XAI_MODEL`; tokens `<app>-worker-dev/prd` |
| Cloudflare Worker `<app>-api` | secret `DOPPLER_SERVICE_TOKEN`; vars `DOPPLER_PROJECT`, `DOPPLER_CONFIG` |
| Codemagic groups `<app>_github/runtime/secrets` | `<APP>_GITHUB_TOKEN`, `<APP>_API_BASE`, `<APP>_CM_*`, `<APP>_RC_KEY_*` |
| Google Cloud `u-things-500622` | service account `revenuecat-play` (+ JSON key) — shared |
| Google Play | package `com.uthings.<app>`; `revenuecat-play` invited as user |
| RevenueCat project `<app>` | `<app>_pro/_unlock/_monthly`, offering `default`, SDK keys `test_/goog_/appl_` |
| Local backup (password manager) | `.jks` + passwords, all of the above |
