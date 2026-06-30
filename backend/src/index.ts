import { generateMessage, generateThreeSteps, type Env } from "./ai";

const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

const KNOWN_EVENTS = new Set(["route_view", "generate_request", "buy_intent", "bail_out"]);
const KNOWN_PLATFORMS = new Set(["android", "ios", "other"]);

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
}

async function handleSteps(request: Request, env: Env): Promise<Response> {
  try {
    const payload = (await request.json()) as { task?: string };
    const task = typeof payload.task === "string" ? payload.task : "";
    return json({ steps: await generateThreeSteps(task, env) });
  } catch {
    return json({ error: "Invalid request" }, 400);
  }
}

async function handleMessage(request: Request, env: Env): Promise<Response> {
  try {
    const payload = (await request.json()) as { kind?: "completion" | "bailout"; task?: string };
    const { kind } = payload;
    const task = typeof payload.task === "string" ? payload.task : "";
    if (kind !== "completion" && kind !== "bailout") {
      return json({ error: "Invalid kind" }, 400);
    }
    return json({ message: await generateMessage(kind, task, env) });
  } catch {
    return json({ error: "Invalid request" }, 400);
  }
}

async function handleTrack(request: Request, env: Env): Promise<Response> {
  try {
    const payload = (await request.json()) as { event?: unknown; platform?: unknown };
    if (typeof payload.event !== "string" || !KNOWN_EVENTS.has(payload.event)) {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }
    const event = payload.event;
    const platform =
      typeof payload.platform === "string" && KNOWN_PLATFORMS.has(payload.platform)
        ? payload.platform
        : "other";
    env.ANALYTICS?.writeDataPoint({
      blobs: [event, platform],
      doubles: [1],
      indexes: [event],
    });
  } catch {
    // Never fail because of analytics.
  }
  return new Response(null, { status: 204, headers: CORS_HEADERS });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }
    const { pathname } = new URL(request.url);
    if (request.method === "POST") {
      switch (pathname) {
        case "/api/steps":
          return handleSteps(request, env);
        case "/api/message":
          return handleMessage(request, env);
        case "/api/track":
          return handleTrack(request, env);
      }
    }
    return new Response("Not found", { status: 404, headers: CORS_HEADERS });
  },
};
