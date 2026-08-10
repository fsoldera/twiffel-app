export interface Env {
  ANALYTICS?: AnalyticsEngineDataset;
  DOPPLER_SERVICE_TOKEN?: string;
  DOPPLER_API_BASE_URL?: string;
  DOPPLER_CACHE_TTL_MS?: string;
  DOPPLER_PROJECT?: string;
  DOPPLER_CONFIG?: string;
  TWIFFEL_XAI_API_KEY?: string;
  TWIFFEL_XAI_MODEL?: string;
  /** Direct override / legacy fallback (prefer Doppler). */
  XAI_API_KEY?: string;
  XAI_MODEL?: string;
  /** Doppler secret name used in twiffel/prd. */
  XAI?: string;
}

const DEFAULT_DOPPLER_API_BASE_URL = "https://api.doppler.com/v3";
const DEFAULT_DOPPLER_CACHE_TTL_MS = 300000;

let dopplerCache: { expiresAt: number; secrets: Record<string, string> } | null = null;

function getDopplerCacheTtlMs(env: Env): number {
  const value = Number.parseInt(env.DOPPLER_CACHE_TTL_MS ?? "", 10);
  return Number.isFinite(value) && value > 0 ? value : DEFAULT_DOPPLER_CACHE_TTL_MS;
}

async function fetchDopplerSecrets(env: Env): Promise<Record<string, string>> {
  if (!env.DOPPLER_SERVICE_TOKEN) return {};
  const now = Date.now();
  if (dopplerCache && dopplerCache.expiresAt > now) return dopplerCache.secrets;

  const baseUrl = (env.DOPPLER_API_BASE_URL || DEFAULT_DOPPLER_API_BASE_URL).replace(/\/+$/, "");
  const params = new URLSearchParams({ format: "json" });
  if (env.DOPPLER_PROJECT) params.set("project", env.DOPPLER_PROJECT);
  if (env.DOPPLER_CONFIG) params.set("config", env.DOPPLER_CONFIG);
  const url = `${baseUrl}/configs/config/secrets/download?${params.toString()}`;

  const response = await fetch(url, {
    method: "GET",
    headers: {
      Authorization: `Bearer ${env.DOPPLER_SERVICE_TOKEN}`,
      Accept: "application/json",
    },
  });
  if (!response.ok) {
    throw new Error(`Doppler request failed with status ${response.status}`);
  }
  const payload = (await response.json()) as Record<string, unknown>;
  const secrets: Record<string, string> = {};
  for (const [key, value] of Object.entries(payload)) {
    if (typeof value === "string") secrets[key] = value;
  }
  dopplerCache = { secrets, expiresAt: now + getDopplerCacheTtlMs(env) };
  return secrets;
}

function envLookup(env: Env, key: string): string | undefined {
  switch (key) {
    case "TWIFFEL_XAI_API_KEY":
      return env.TWIFFEL_XAI_API_KEY;
    case "XAI_API_KEY":
      return env.XAI_API_KEY;
    case "XAI":
      return env.XAI;
    case "TWIFFEL_XAI_MODEL":
      return env.TWIFFEL_XAI_MODEL;
    case "XAI_MODEL":
      return env.XAI_MODEL;
    default:
      return undefined;
  }
}

function pickSecret(
  secrets: Record<string, string>,
  env: Env,
  keys: string[],
): string | undefined {
  for (const key of keys) {
    const fromDoppler = secrets[key];
    if (fromDoppler) return fromDoppler;
    const fromEnv = envLookup(env, key);
    if (fromEnv) return fromEnv;
  }
  return undefined;
}

async function resolveXaiConfig(env: Env): Promise<{ apiKey?: string; model: string }> {
  try {
    const secrets = await fetchDopplerSecrets(env);
    const apiKey = pickSecret(secrets, env, [
      "TWIFFEL_XAI_API_KEY",
      "XAI_API_KEY",
      "XAI",
    ]);
    const model =
      pickSecret(secrets, env, ["TWIFFEL_XAI_MODEL", "XAI_MODEL"]) || "grok-latest";
    return { apiKey, model };
  } catch {
    return {
      apiKey: pickSecret({}, env, ["TWIFFEL_XAI_API_KEY", "XAI_API_KEY", "XAI"]),
      model:
        pickSecret({}, env, ["TWIFFEL_XAI_MODEL", "XAI_MODEL"]) || "grok-latest",
    };
  }
}

export async function callXaiChat(
  messages: Array<{ role: "system" | "user"; content: string }>,
  env: Env,
): Promise<string> {
  const { apiKey, model } = await resolveXaiConfig(env);
  if (!apiKey) {
    throw new Error(
      "Missing xAI API key, set TWIFFEL_XAI_API_KEY in Doppler (preferred) or as a Worker secret",
    );
  }

  const response = await fetch("https://api.x.ai/v1/chat/completions", {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${apiKey}` },
    body: JSON.stringify({ model, temperature: 0.7, messages }),
  });
  if (!response.ok) throw new Error(`xAI request failed with status ${response.status}`);

  const payload = (await response.json()) as {
    choices?: Array<{ message?: { content?: string } }>;
  };
  const content = payload.choices?.[0]?.message?.content?.trim();
  if (!content) throw new Error("xAI response did not contain message content");
  return content;
}
