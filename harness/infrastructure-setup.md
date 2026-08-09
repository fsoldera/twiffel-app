# Infrastructure Setup Runbook — new U-Things app

Step-by-step guide to wire a new app into all external tools. Hard-won lessons from
Stikkteller + Twiffel — follow the order and the gotchas. Infra should take under an
hour, plus the store catalog pass in `harness/store-launch-checklist.md`.

When you find a faster path or a dead end, update this file (see
`harness/harness-maintenance.md`).

Replace `<APP>` with the uppercase app name (e.g. `TWIFFEL`) and `<app>` with the
lowercase name (e.g. `twiffel`) everywhere below.

**Golden rule: one app = one set of secrets.** Never share app keys between apps
(they outlive each other and rotating one must not break another). Every secret and
variable is prefixed with the app name: `<APP>_*`.

**Canonical secret names (new apps):**

| Secret | Required in |
|---|---|
| `<APP>_XAI_API_KEY` | Doppler `dev` + `prd` |
| `<APP>_XAI_MODEL` | Doppler `dev` + `prd` (e.g. `grok-3-mini`) |
| `<APP>_GITHUB_TOKEN` | Doppler `ci` |
| `<APP>_CM_KEYSTORE` (+ password / alias / key password) | Doppler `ci` |
| `<APP>_RC_KEY_ANDROID` / `<APP>_RC_KEY_IOS` | Doppler `ci` (+ `prd` if you like) after RC |

Do **not** create bare `XAI`, `VITE_XAI_*`, or copy another app’s key. Older apps may
still have legacy names; Workers may accept them as fallback only. Bootstrap the next
app with the table above.

**Secret source of truth = Doppler.** Put immutable secrets in Doppler first. The
Worker and Codemagic **consume** Doppler. Do not hand-duplicate RC keys into
Codemagic if they already live in Doppler.

The only allowed **shared** pieces (not per-app secrets) are:

- Google Cloud service account `revenuecat-play@…` (invite per new Play app)
- ASC **In-App Purchase** `.p8` + Issuer ID + Key ID (account-wide, reuse in RC)
- ASC **App Store Connect API** key (Codemagic integration; name `<app>_asc` OK)
- Personal logins / dashboard access

---

## Setup order (dependencies flow downward)

```text
1. xAI            → API key exists
2. Doppler        → SoT for XAI + (later) RC keys + optional signing
3. Cloudflare     → Worker deployed, reads Doppler   → gives <APP>_API_BASE URL
4. Codemagic      → thin CI: PAT + Doppler token (or mirrored groups)
5. Android keystore → signed .aab
6. Google Play    → app created, internal test track + products
7. RevenueCat     → catalog + goog_ key → store goog_ in Doppler → Play billing
8. App Store Connect → IAPs + <app>_asc → appl_ in Doppler → TestFlight
```

Each step only needs outputs from the steps above it. Do them in order.
For the store/RC click-path and gotchas, also use `harness/store-launch-checklist.md`.

---

## Step 1 — xAI (console.x.ai)

1. Create a **new API key** named after the app (`<app>`). Do not reuse another
   app's key. Never paste Joppling / Stikkteller / Twiffel keys into a new project.
2. Note the model (default: `grok-3-mini`).
3. Keep both in a password manager until step 2.

> **Never** put the xAI key in the Flutter app, Codemagic dart-defines, or git.
> Only Doppler → Worker.

> **Gotcha — isolation:** after Doppler step 2, optionally hash-compare the new
> `<APP>_XAI_API_KEY` against other apps’ keys (print hashes only). If equal, rotate.

---

## Step 2 — Doppler (dashboard.doppler.com) — secrets SoT

1. **Create a project named after the app** (`<app>`) — do not add configs to
   another app's project.
2. Use `dev` and `prd`. **Also create environment + config `ci`** for Codemagic
   (CLI: `doppler environments create ci ci --project <app>`). Do not skip `ci` and
   then discover empty secrets mid-build.
3. Add secrets:

   | Secret | Configs | When |
   |---|---|---|
   | `<APP>_XAI_API_KEY` | `dev`, `prd` | now |
   | `<APP>_XAI_MODEL` | `dev`, `prd` | now (`grok-3-mini`) |
   | `<APP>_GITHUB_TOKEN` | `ci` | before first Codemagic build |
   | `<APP>_CM_KEYSTORE*` | `ci` | after step 5 |
   | `<APP>_RC_KEY_ANDROID` / `_IOS` | `ci` | after steps 7–8 (ok empty for first binary) |

4. Create **service tokens** (shown once — copy immediately):
   - `<app>-worker-dev` (config `dev`) — local Worker / `.dev.vars`
   - `<app>-worker-prd` or `<app>-api-prd` (config `prd`) — deployed Worker
   - `<app>-codemagic-ci` (config `ci`) — Codemagic `DOPPLER_TOKEN` only

> **Gotcha — where are service tokens?** Not on the Secrets page. Left sidebar →
> **Tokens**, or open a config → **Access** tab. Tokens start with `dp.st.`.

> **Gotcha — Cloudflare tokens in Doppler:** not needed. `CLOUDFLARE_API_TOKEN` /
> `CLOUDFLARE_ACCOUNT_ID` are deploy-time credentials, only useful if CI deploys the
> Worker. Local `wrangler login` covers manual deploys.

> **Gotcha — Windows secret pipe:** PowerShell piping into `wrangler secret put` is
> fragile. Prefer:
> `cmd /c "doppler configs tokens create --name <app>-api-prd --project <app> --config prd --plain | npx wrangler secret put DOPPLER_SERVICE_TOKEN"`

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
# Put prd service token (Windows-safe):
cmd /c "doppler configs tokens create --name <app>-api-prd --project <app> --config prd --plain | npx wrangler secret put DOPPLER_SERVICE_TOKEN"
```

Save the printed URL — it becomes `<APP>_API_BASE`
(e.g. `https://<app>-api.franco-soldera.workers.dev`).

Smoke test — prefer **`Invoke-RestMethod`** on Windows (PowerShell’s `curl` alias
breaks JSON). Prefer **`/api/steps`** first: it proves Doppler → xAI end-to-end.
`/api/message` can return a static fallback when tone policy rejects the model
output even if Doppler is wired.

```powershell
Invoke-RestMethod -Method Post `
  -Uri "https://<app>-api.franco-soldera.workers.dev/api/steps" `
  -ContentType "application/json" `
  -Body '{"task":"water the plants"}'
```

Expect a JSON `steps` array with concrete actions. For `/api/message`, kinds are
app-specific (Twiffel: `completion` / `bailout`, not a generic `day_complete`).

`{"error":"Invalid request"}` usually means the JSON body did not parse (quoting),
not a server failure. `{"error":"Invalid kind"}` means the wrong `kind` string.

Local dev: copy `backend/.dev.vars.example` → `.dev.vars`, use the **dev** token.

---

## Step 4 — Codemagic (free personal plan)

**Preferred (Twiffel path):** Doppler holds secrets; Codemagic holds only a thin set:

| Group | Variable | Secret? | Value |
|---|---|---|---|
| `<app>_ci` | `DOPPLER_TOKEN` | yes | service token `<app>-codemagic-ci` |
| `<app>_ci` | `DOPPLER_PROJECT` | no | `<app>` |
| `<app>_ci` | `DOPPLER_CONFIG` | no | `ci` |
| `<app>_runtime` | `<APP>_API_BASE` | no | Worker URL from step 3 |

YAML loads Doppler into `CM_ENV` so builds see `<APP>_RC_KEY_*`, `<APP>_GITHUB_TOKEN`,
keystore vars. Group names in Codemagic must match `codemagic.yaml` **exactly**.
List only the groups you actually create (unknown groups fail the build).

**Fallback (Stikkteller-style mirror):** if you prefer not to wire Doppler into CI yet,
put the same values in Codemagic groups (still **copy from Doppler**, do not invent a
second SoT):

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
   | `<app>_secrets` | `<APP>_RC_KEY_ANDROID` | yes | `goog_…` from Doppler / step 7 |
   | `<app>_secrets` | `<APP>_RC_KEY_IOS` | yes | `appl_…` from Doppler / step 8 |

> **Gotcha — variables wiped:** switching the app from Workflow Editor to
> codemagic.yaml mode can erase already-entered variables. Re-add them after
> switching, not before.

> **Gotcha — starting builds:** always start builds from the **codemagic.yaml** tab
> and pick the named workflow (e.g. *\<App\> iOS (smoke)*). The blue
> "Start new build" button may offer only "Default Workflow" (Workflow Editor) —
> that is not your YAML.

> **Gotcha — Doppler step &lt;1s then GitHub PAT missing:** the old soft-skip treated
> unset `DOPPLER_TOKEN` as success. Open the “Load secrets from Doppler” log: it must
> say secrets were written to `CM_ENV` and install the Doppler CLI (usually &gt;1s).
> Confirm group `<app>_ci` is listed under the workflow and `DOPPLER_TOKEN` is the
> **current** `<app>-codemagic-ci` service token (tokens are shown once; recreate if
> unsure). Doppler `ci` must contain `<APP>_GITHUB_TOKEN`.

> **Gotcha — `Unable to find gpg binary` on Codemagic:** Doppler’s `install.sh`
> requires GnuPG. On Mac builders, install via Homebrew (`brew install gnupg` then
> `brew install dopplerhq/cli/doppler`). If install fails, every `doppler secrets get`
> looks like a “missing” secret even when Doppler `ci` is populated.

> **Gotcha — missing Podfile:** if `pod install` fails with *"No `Podfile` found"*,
> the repo lacks `ios/Podfile` — copy the standard Flutter one from this template.

Verify: run **iOS (smoke)** — it proves the PAT, pub get, and CocoaPods work.

---

## Step 5 — Android upload keystore

One keystore **per app**, generated locally, never committed:

```powershell
# Use THE SAME password for -storepass and -keypass.
# Recent keytool defaults to PKCS12, which ignores a different -keypass
# ("Different store and key passwords not supported for PKCS12 KeyStores").
# If Doppler has a different KEY password, Gradle fails with
# "Given final block not properly padded".
keytool -genkeypair -v `
  -keystore <app>-upload.jks `
  -alias <app>-upload `
  -keyalg RSA -keysize 2048 -validity 10000 `
  -storepass <SAME_PW> -keypass <SAME_PW> `
  -dname "CN=<App>, OU=U-Things, O=Franco Soldera, C=DK"

[Convert]::ToBase64String([IO.File]::ReadAllBytes("<app>-upload.jks")) | Set-Clipboard
```

Paste the base64 + passwords into Doppler `ci` as `<APP>_CM_KEYSTORE*` (preferred)
and/or the `<app>_secrets` group (step 4 fallback). Back up the `.jks` and passwords
in a password manager. Ensure root `.gitignore` covers `*.jks` / `*.keystore` at
repo root (not only under `android/`).

Codemagic Android workflow should decode the keystore and write `android/key.properties`;
`android/app/build.gradle.kts` must use that file for release (debug fallback when
absent, so local `flutter run --release` still works).

> **Gotcha — regeneration:** free to regenerate with new passwords **until the first
> `.aab` is uploaded to Play**. After that the upload key is pinned (reset requires a
> slow Google support flow).

> **Gotcha — Gradle `final block not properly padded`:** wrong store/key password, or
> corrupted base64 in Doppler (line wraps / spaces). Most common: PKCS12 keystore
> where `-keypass` was ignored, so Doppler `*_KEY_PASSWORD` ≠ store password. Set
> both Doppler passwords to the **same** value. Re-encode as one line, verify with
> `keytool -list`, then rebuild. Codemagic should `keytool -list` right after decode.

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
6. Add yourself as a **license tester** (Settings → License testing) so purchases
   are free / sandbox-like for billing tests.
7. Create products (IDs must match `app_config.dart`):
   - One-time: `<app>_unlock`, purchase option `default`, activate + price.
   - Subscription: `<app>_monthly`, base plan id `monthly`, auto-renew, activate + price.

> **Gotcha — nothing "arrives":** Play sends **no email** and the app is **not
> searchable** in the store. The opt-in link is the only entry point: open it on an
> Android phone signed into the tester Gmail → *Become a tester* → install.

> **Gotcha — dashboard blockers:** privacy policy URL, content rating, target
> audience, and app access declarations can block the test link even after rollout.
> Clear the dashboard tasks if the link claims the app is unavailable.

> **Gotcha — listing icon:** the 512×512 store icon is listing metadata. Shipping a
> new `.aab` does **not** fix a missing/robot listing icon.

> **Gotcha — `(unreviewed)` + robot + package name:** normal on internal testing
> until the store listing is reviewed. Does not block internal install or IAP tests.

---

## Step 7 — RevenueCat

### Catalog (identifiers are immutable — get them right the first time)

| Object | Identifier (must match `lib/src/config/app_config.dart`) |
|---|---|
| Entitlement | `<app>_pro` |
| One-time product | `<app>_unlock` |
| Monthly subscription | `<app>_monthly` |
| Offering | `default` (packages `$rc_lifetime`, `$rc_monthly`) |

Freeze IDs in `app_config.dart` **before** creating dashboard objects.

> **Gotcha — identifiers can never be edited**, only display names. A wrong ID means
> delete + recreate (safe while there are no transactions).

Skip the "Install the SDK" wizard code — `common_app_kit` already wraps
`purchases_flutter`; only the dashboard objects and API keys matter.

Prefer a custom shop (plan cards) over the kit `PaywallScreen` alone — the kit
shows raw store titles (`… (com.uthings.…)`).

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

### Import Play products + Android monthly id

1. Play **Products** may be empty while Test Store still has placeholders — expected.
2. **Import** from Play. Monthly becomes `<app>_monthly:monthly`
   (`productId:basePlanId`).
3. Set Android monthly id in `app_config.dart` to that exact string (template already
   resolves platform monthly ids). Kit filters by exact `StoreProduct.identifier`.
4. Attach **Play** products to entitlement + offering `default` — not only Test Store
   rows named `Monthly` / `Lifetime`.

### API keys

**API keys** / Apps page → per-app **SDK** keys (never the secret keys):

| Key | Prefix | Use |
|---|---|---|
| Test Store | `test_…` | sideloaded / local only |
| Play Store | `goog_…` | any build installed from Google Play |
| App Store | `appl_…` | TestFlight / App Store (step 8) |

5. Copy `goog_…` → **Doppler** as `<APP>_RC_KEY_ANDROID` (then Codemagic via Doppler
   or a thin mirror). Rebuild the Android workflow.

> **Gotcha — "Wrong API key" on launch** of a Play-installed build means a `test_`
> key was baked in. Put the `goog_…` key in `<APP>_RC_KEY_ANDROID`, rebuild,
> upload a new `.aab`.

Until keys are set, the app runs in honor/nag-only mode — **fine for first Play /
TestFlight binaries**. Do not block signed CI on RevenueCat. Add `goog_` / `appl_`,
then rebuild.

---

## Step 8 — App Store Connect / TestFlight (when iOS ships)

1. App Store Connect: create the app for bundle `com.uthings.<app>`.
2. Create IAPs matching `app_config.dart`:
   - Non-consumable `<app>_unlock`
   - Auto-renewable `<app>_monthly` (1 month)
3. Localization **description ≤ 45 characters** (ASC hard limit).
4. Review screenshot required — exact iPhone sizes only
   (`1242×2688`, `1284×2778`, …). Use `scripts/export-iap-review-screenshot.py`.
5. First IAP often must ship with a **new app version** (ASC banner) — expected.
6. Codemagic → Integrations → App Store Connect API key, named `<app>_asc`
   (matches `integrations.app_store_connect` in `codemagic.yaml`).
7. Run the **iOS (signed)** workflow — it fetches/creates signing files and submits
   to TestFlight.
8. RevenueCat: Apps → App Store + shared IAP `.p8` credentials.
9. Copy **`appl_…` only from RevenueCat** (Apps → App Store app → Show key) —
   it never appears in ASC. Store in Doppler as `<APP>_RC_KEY_IOS`.
10. Import App Store products; offering `default` must show **App Store** product
    rows (e.g. `… Lifetime` / `… Monthly`), not only Test Store placeholders.
11. New signed iOS build with `appl_…` → Internal TestFlight → sandbox purchase.

> **Gotcha — Codemagic 422 on `betaAppReviewSubmissions`:** IPA + publishing can
> still succeed; external beta metadata is the failure. **Internal Testing** works.

> **Gotcha — `No matching profiles found` for a new bundle ID:** YAML
> `ios_signing.distribution_type` only finds profiles **already uploaded** in
> Codemagic. For a new app, use `app-store-connect fetch-signing-files <bundle> --type
> IOS_APP_STORE --create` (ASC API key must be Admin / App Manager). Register the
> Bundle ID in Apple Developer before the first signed build.

> **Gotcha — seller “personal name”:** Individual Apple Developer account shows your
> legal name as seller. Brand name needs Organization + D-U-N-S.

> **Gotcha — terms in app:** Apple EULA on iOS only; omit Apple EULA link on Android
> (template `app_config.dart` already does this).

---

## Final secret map (who holds what)

| Tool | Names |
|---|---|
| xAI | key labeled `<app>` |
| **Doppler project `<app>` (SoT)** | `<APP>_XAI_*`, `<APP>_RC_KEY_*`, optional `<APP>_GITHUB_TOKEN` / `<APP>_CM_*`; tokens `<app>-worker-dev/prd`, `<app>-codemagic-ci` |
| Cloudflare Worker `<app>-api` | secret `DOPPLER_SERVICE_TOKEN`; vars `DOPPLER_PROJECT`, `DOPPLER_CONFIG` |
| Codemagic | Prefer `DOPPLER_TOKEN` + `<APP>_API_BASE`; fallback groups `<app>_github/runtime/secrets` |
| Google Cloud `u-things-500622` | service account `revenuecat-play` (+ JSON key) — shared |
| Google Play | package `com.uthings.<app>`; `revenuecat-play` invited as user |
| RevenueCat project `<app>` | `<app>_pro/_unlock/_monthly`, offering `default`, SDK keys `test_/goog_/appl_` |
| ASC | IAP catalog + shared IAP `.p8` + ASC API key for Codemagic |
| Local backup (password manager) | `.jks` + passwords, all of the above |
