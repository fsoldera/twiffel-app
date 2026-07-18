# my-app-api (Cloudflare Worker)

Server-side AI proxy + anonymous analytics for U-Things apps.

**Secrets SoT is Doppler.** The Worker reads `APP_XAI_API_KEY` (rename to `<APP>_XAI_*`
during bootstrap) via a Doppler service token. Never put xAI keys in the mobile app.

## Endpoints

| Method | Path | Body | Response |
|---|---|---|---|
| POST | `/api/steps` | `{ "task": string }` | `{ "steps": string[3] }` |
| POST | `/api/message` | `{ "task": string, "kind": "completion" \| "bailout" }` | `{ "message": string }` |
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
npx wrangler secret put DOPPLER_SERVICE_TOKEN   # prd service token
```

`wrangler.toml` already sets `DOPPLER_PROJECT` / `DOPPLER_CONFIG` / `APP_XAI_MODEL`.

Point the Flutter app at the deployed URL:

```bash
flutter run --dart-define=APP_API_BASE=https://my-app-api.<subdomain>.workers.dev
```

## Safety

- Input validation: `common_app_kit` `validateTaskInput()` on the client (canonical).
- Output validation: kit validators on client + `backend/src/tone.ts` on server.
- When you change `tone_policy.dart`, mirror critical patterns in `tone.ts`.
