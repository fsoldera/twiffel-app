# my-app-api (Cloudflare Worker)

Server-side AI proxy + anonymous analytics for U-Things apps.

The xAI API key lives in Cloudflare Workers secrets — never in the mobile app.

## Endpoints

| Method | Path | Body | Response |
|---|---|---|---|
| POST | `/api/steps` | `{ "task": string }` | `{ "steps": string[3] }` |
| POST | `/api/message` | `{ "task": string, "kind": "completion" \| "bailout" }` | `{ "message": string }` |
| POST | `/api/track` | `{ "event": string, "platform": "android"\|"ios"\|"other" }` | `204` |

## Local development

```bash
npm install
cp .dev.vars.example .dev.vars   # fill in XAI_API_KEY
npm run dev
```

## Deploy

```bash
npm run deploy
npx wrangler secret put XAI_API_KEY
```

Point the Flutter app at the deployed URL:

```bash
flutter run --dart-define=APP_API_BASE=https://my-app-api.<subdomain>.workers.dev
```

## Safety

- Input validation: `common_app_kit` `validateTaskInput()` on the client (canonical).
- Output validation: kit validators on client + `backend/src/tone.ts` on server.
- When you change `tone_policy.dart`, mirror critical patterns in `tone.ts`.
