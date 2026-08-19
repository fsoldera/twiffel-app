# Store + RevenueCat launch checklist

Painful once → copy-paste next time. Lessons from Stikkteller (second template app).
Use with `harness/infrastructure-setup.md`. Replace `<app>` / `<APP>` as usual.

**Secret rule:** immutable secrets live in **Doppler** (source of truth). Codemagic
and the Worker **consume** Doppler — do not hand-paste the same RC keys into
Codemagic on every app if they already exist in Doppler.

**Naming:** use `<APP>_XAI_API_KEY` / `<APP>_RC_KEY_*` (never bare `XAI` or another
app’s key). See `harness/harness-maintenance.md`. When you find a faster store path
or a dead end, update this checklist in the same pass.

---

## 0. Reuse (do not recreate)

| Asset | Where | Notes |
|---|---|---|
| Play service account `revenuecat-play@…` | Google Cloud `u-things-500622` | Invite as Play user per new app |
| ASC **In-App Purchase** key (`.p8` + Issuer ID + Key ID) | ASC → Users and Access → Integrations → In-App Purchase | Account-wide; reuse in RC |
| ASC **App Store Connect API** key | Same Integrations page | Reuse for Codemagic (`<app>_asc` name OK) |
| Doppler project pattern | One project per app | SoT for XAI + RC keys (+ optional signing) |
| Product ID scheme | `app_config.dart` | `<app>_pro` / `<app>_unlock` / `<app>_monthly` |
| Offering | RC | `default` with `$rc_lifetime` + `$rc_monthly` |

---

## 1. Freeze IDs in code first

Before dashboards, set in `lib/src/config/app_config.dart`:

| Object | ID |
|---|---|
| Entitlement | `<app>_pro` |
| Lifetime | `<app>_unlock` |
| Monthly | `<app>_monthly` |
| Android monthly (after Play import) | `<app>_monthly:monthly` |

Prefer a Joppling-style shop (plan cards + clean CTAs). Kit `PaywallScreen` alone
shows raw store titles (`… (com.uthings.…)`).

Terms: Apple EULA on iOS only; omit Apple EULA link on Android.

---

## 2. Doppler (secrets SoT)

In Doppler project `<app>` (`dev` + `prd`, and optionally `ci`):

| Secret | When |
|---|---|
| `<APP>_XAI_API_KEY` / `<APP>_XAI_MODEL` / `<APP>_XAI_BASE_URL` / `<APP>_XAI_REASONING_EFFORT` / `<APP>_XAI_TEMPERATURE` | Step 1–2 of infrastructure-setup |
| `<APP>_RC_KEY_ANDROID` (`goog_…`) | After RC Play app exists |
| `<APP>_RC_KEY_IOS` (`appl_…`) | After RC App Store app exists |
| Optional: keystore passwords / base64 | If you want signing out of Codemagic UI |

Worker already reads XAI via Doppler. Codemagic should read RC (+ signing) via
Doppler too — see infrastructure-setup step 4.

---

## 3. Google Play

1. Internal track `.aab` live; you’re a **license tester**.
2. One-time: id `<app>_unlock`, purchase option `default`, activate + price.
3. Subscription: id `<app>_monthly`, base plan `monthly`, auto-renew, activate + price.
4. Listing 512 icon is **listing-only** (not fixed by AAB update).
5. Internal “`(unreviewed)` + robot + package name” is normal until listing review.

**Gotcha:** uninstalling the debug APK does **not** reset first-launch onboarding if
Android Auto Backup restores SharedPreferences. The app sets `android:allowBackup="false"`.
To replay onboarding on a device that still has the old APK, run
`adb shell pm clear com.uthings.twiffel` and launch again. Do not uninstall/reinstall
until that build is installed.

---

## 4. RevenueCat — Play

1. Apps → Play Store + shared service account JSON.
2. Play **Products** may be empty while Test Store has placeholders — expected.
3. **Import** Play products.
4. Monthly id becomes `<app>_monthly:monthly` — match that in `app_config.dart` on Android.
5. Entitlement + offering `default` → attach **Play** products (not only Test Store).
6. Copy **`goog_…`** from Apps → Play Store → Show key → **store in Doppler**
   (`<APP>_RC_KEY_ANDROID`). Never use Test Store `test_…` for Play installs.
7. New Codemagic Android build (must see Doppler / env pick up `goog_…`).

---

## 5. App Store Connect

1. Non-consumable `<app>_unlock`; subscription `<app>_monthly` (1 month).
2. Localization description **≤ 45 characters**.
3. Group display name = short brand, not the product description.
4. Review screenshot required — exact iPhone size (`1242×2688` or `1284×2778`).
   Use `scripts/export-iap-review-screenshot.py`.
5. First IAP ships with a new app version (ASC banner) — expected.
6. Seller “personal name”: Individual account; brand needs Organization + D-U-N-S.

---

## 6. RevenueCat — App Store

1. Apps → Add App Store + shared IAP `.p8` credentials.
2. **`appl_…` is only in RevenueCat** (Apps → App Store app → Show key), never in ASC.
3. Store `appl_…` in Doppler as `<APP>_RC_KEY_IOS`.
4. Import products; attach entitlement; offering must show **App Store** rows
   (names like `… Lifetime` / `… Monthly`, not only Test Store `Lifetime` / `Monthly`).
5. New signed iOS build → Internal TestFlight.

---

## 7. Codemagic / TestFlight gotchas

| Symptom | Meaning |
|---|---|
| Asked for encryption / export compliance on every upload | Missing `ITSAppUsesNonExemptEncryption` = `false` in `ios/Runner/Info.plist` (exempt HTTPS-only apps) |
| IPA + Publishing green; distribution `422` on beta review | External beta metadata — **internal TF still OK** |
| Shop placeholder | RC key not in this binary / offering missing store products |
| Wrong API key on Play | `test_…` baked instead of `goog_…` |

---

## 8. Done when

- [ ] Doppler holds XAI + `goog_…` + `appl_…`
- [ ] Codemagic builds inject RC keys from Doppler (not hand-duplicated)
- [ ] Play internal: real prices + purchase as license tester
- [ ] TestFlight: real prices + sandbox purchase
- [ ] RC offering `default` has Play + App Store on both packages
