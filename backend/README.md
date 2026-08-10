# twiffel-api (Cloudflare Worker)

Server-side AI proxy + anonymous analytics for Twiffel.

**Secrets SoT is Doppler.** Canonical secret name: `TWIFFEL_XAI_API_KEY` (legacy bare
`XAI` still accepted). The Worker reads it via a Doppler service token. Never put
xAI keys in the mobile app.

## Endpoints

| Method | Path | Body | Response |
|---|---|---|---|
| POST | `/api/analyze` | decision payload (`mode`, options/target, `obstacle`, `timing`) | `{ "analysis": … }` |
| POST | `/api/track` | `{ "event": string, "platform": "android"\|"ios"\|"other" }` | `204` |

## Local development

```bash
npm install
cp .dev.vars.example .dev.vars   # Doppler service token for config `dev`
npm run dev
```

## Deploy

```bash
npm run deploy
# Windows-safe put:
# cmd /c "doppler configs tokens create --name twiffel-api-prd --project twiffel --config prd --plain | npx wrangler secret put DOPPLER_SERVICE_TOKEN"
```

`wrangler.toml` already sets `DOPPLER_PROJECT` / `DOPPLER_CONFIG` / `TWIFFEL_XAI_MODEL`.

Point the Flutter app at the deployed URL:

```bash
flutter run --dart-define=TWIFFEL_API_BASE=https://twiffel-api.franco-soldera.workers.dev
```

## Safety

- Input validation (required): `validateTaskInput` on the Flutter client **and** again
  on the Worker before any xAI call (`validateDecisionInputs`). Client alone is not enough.
- Verdict output: content-safety only via Worker `isSafeContent` (not compassionate-tone checks).
- When you change `tone_policy.dart` content-safety patterns, mirror them in `tone.ts`.
