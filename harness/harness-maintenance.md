# Harness maintenance — keep the path short

The harness is a living runbook. Whenever setup is painful, slow, or hits a dead
end, **update the harness in the same change** (or immediately after), not later.

---

## When to update

Update `harness/` (and the relevant `tasks/` file) when you discover any of:

```text
- A faster click-path or CLI sequence than what the docs describe
- A dead end (wrong smoke payload, wiped Codemagic vars, shared secrets, etc.)
- A naming inconsistency that will confuse the next app
- A tool UI change (Play, ASC, Doppler, Codemagic, Cloudflare)
- A secret that must stay per-app and was at risk of being reused
- A Windows / PowerShell gotcha that burned time
```

Do **not** leave “we’ll document this next time” as the outcome of a successful setup.

---

## What to update

| Discovery | Prefer editing |
|---|---|
| Infra / secrets / CI / Worker | `harness/infrastructure-setup.md` |
| Play / ASC / RevenueCat catalog | `harness/store-launch-checklist.md` |
| Product rules / dart-defines | `harness/feedforward.md` |
| Agent behavior / priorities | `AGENTS.md` |
| App-specific checklist | `tasks/task-*.md` |

Keep gotchas next to the step they belong to. Prefer one short “Gotcha” callout over a
long narrative.

---

## Naming (canonical for every new app)

One Doppler project per app. **Every app secret is `<APP>_`-prefixed.** Do not invent
short aliases for new apps.

| Kind | Canonical name | Notes |
|---|---|---|
| xAI API key | `<APP>_XAI_API_KEY` | New key in console.x.ai labeled `<app>`. Never share across apps. |
| xAI model | `<APP>_XAI_MODEL` | e.g. `grok-4.3` |
| xAI reasoning effort | `<APP>_XAI_REASONING_EFFORT` | `none` / `low` / `medium` / `high`. Default `low`. |
| xAI temperature | `<APP>_XAI_TEMPERATURE` | `0` to `2`. Default `0.7`. |
| xAI API base URL | `<APP>_XAI_BASE_URL` | e.g. `https://eu-west-1.api.x.ai/v1`. Not `<APP>_API_BASE`. |
| Worker URL (CI / dart-define) | `<APP>_API_BASE` | Not a Doppler secret; Codemagic runtime group |
| GitHub PAT for private kit | `<APP>_GITHUB_TOKEN` | Doppler `ci` |
| Android keystore (base64) | `<APP>_CM_KEYSTORE` | Plus `_PASSWORD`, `_KEY_ALIAS`, `_KEY_PASSWORD` |
| RevenueCat SDK keys | `<APP>_RC_KEY_ANDROID` / `_IOS` | `goog_…` / `appl_…` |

**Forbidden for new apps:** bare `XAI`, `VITE_XAI_*`, or copying another app’s key into
a new Doppler project. Legacy aliases may exist in older apps; Workers may accept them
as fallback only. New bootstrap must use the canonical names above.

**Isolation check (optional, hashes only, never print keys):**

```powershell
# Compare sha256 prefixes across apps; all must differ.
# Example keys: TWIFFEL_XAI_API_KEY / STIKKTELLER_XAI_API_KEY / …
```

If two apps hash equal, rotate the new app’s key immediately and fix Doppler.

---

## Agent duty

Agents following `AGENTS.md` must:

1. Prefer the harness path over improvising a second SoT or naming scheme.
2. When they find a better path or a dead end, patch the harness docs before closing
   the task (unless the user forbids doc changes).
3. Call out remaining human dashboard steps in the final report, with links to the
   updated harness section.
4. If the lesson was learned in a **product app** (Twiffel, Stikkteller, …), also
   sync the same harness updates back into **u-things-app-template** so the next
   bootstrap inherits them.
