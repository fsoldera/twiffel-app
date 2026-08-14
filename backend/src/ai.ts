export interface Env {
  ANALYTICS?: AnalyticsEngineDataset;
  DOPPLER_SERVICE_TOKEN?: string;
  DOPPLER_API_BASE_URL?: string;
  DOPPLER_CACHE_TTL_MS?: string;
  DOPPLER_PROJECT?: string;
  DOPPLER_CONFIG?: string;
  TWIFFEL_XAI_API_KEY?: string;
  TWIFFEL_XAI_MODEL?: string;
  TWIFFEL_XAI_REASONING_EFFORT?: string;
  TWIFFEL_XAI_TEMPERATURE?: string;
  TWIFFEL_XAI_BASE_URL?: string;
  /** Direct override / legacy fallback (prefer Doppler). */
  XAI_API_KEY?: string;
  XAI_MODEL?: string;
  /** Doppler secret name used in twiffel/prd. */
  XAI?: string;
}

const DEFAULT_DOPPLER_API_BASE_URL = "https://api.doppler.com/v3";
const DEFAULT_DOPPLER_CACHE_TTL_MS = 300000;
const DOPPLER_TIMEOUT_MS = 8000;
/** Wall-clock wait for xAI. HTTP Workers have no duration cap while the client stays connected. */
const XAI_TIMEOUT_MS = 60000;

async function fetchWithTimeout(
  url: string,
  init: RequestInit,
  timeoutMs: number,
): Promise<Response> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, { ...init, signal: controller.signal });
  } finally {
    clearTimeout(timer);
  }
}

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

  const response = await fetchWithTimeout(
    url,
    {
      method: "GET",
      headers: {
        Authorization: `Bearer ${env.DOPPLER_SERVICE_TOKEN}`,
        Accept: "application/json",
      },
    },
    DOPPLER_TIMEOUT_MS,
  );
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

const REASONING_EFFORTS = ["none", "low", "medium", "high"] as const;
type ReasoningEffort = (typeof REASONING_EFFORTS)[number];
const DEFAULT_REASONING_EFFORT: ReasoningEffort = "medium";
const DEFAULT_TEMPERATURE = 0.7;
const DEFAULT_XAI_BASE_URL = "https://eu-west-1.api.x.ai/v1";

function parseXaiBaseUrl(raw: string | undefined): string {
  const fallback = DEFAULT_XAI_BASE_URL;
  if (!raw?.trim()) return fallback;
  let value = raw.trim().replace(/\/+$/, "");
  if (!/^https?:\/\//i.test(value)) value = `https://${value}`;
  try {
    const url = new URL(value);
    if (url.protocol !== "https:") return fallback;
    if (url.pathname === "" || url.pathname === "/") url.pathname = "/v1";
    return `${url.origin}${url.pathname.replace(/\/+$/, "")}`;
  } catch {
    return fallback;
  }
}

function envLookup(env: Env, key: string): string | undefined {
  const value = (env as unknown as Record<string, unknown>)[key];
  return typeof value === "string" && value.length > 0 ? value : undefined;
}

function parseReasoningEffort(raw: string | undefined): ReasoningEffort {
  const value = raw?.trim().toLowerCase();
  if (value && (REASONING_EFFORTS as readonly string[]).includes(value)) {
    return value as ReasoningEffort;
  }
  return DEFAULT_REASONING_EFFORT;
}

function parseTemperature(raw: string | undefined): number {
  if (!raw) return DEFAULT_TEMPERATURE;
  const n = Number.parseFloat(raw);
  if (!Number.isFinite(n) || n < 0 || n > 2) return DEFAULT_TEMPERATURE;
  return n;
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

interface XaiConfig {
  apiKey?: string;
  model: string;
  baseUrl: string;
  reasoningEffort: ReasoningEffort;
  temperature: number;
}

async function resolveXaiConfig(env: Env): Promise<XaiConfig> {
  let secrets: Record<string, string> = {};
  try {
    secrets = await fetchDopplerSecrets(env);
  } catch {
    secrets = {};
  }
  return {
    apiKey: pickSecret(secrets, env, ["TWIFFEL_XAI_API_KEY", "XAI_API_KEY", "XAI"]),
    model: pickSecret(secrets, env, ["TWIFFEL_XAI_MODEL", "XAI_MODEL"]) || "grok-4.3",
    baseUrl: parseXaiBaseUrl(pickSecret(secrets, env, ["TWIFFEL_XAI_BASE_URL"])),
    reasoningEffort: parseReasoningEffort(
      pickSecret(secrets, env, ["TWIFFEL_XAI_REASONING_EFFORT"]),
    ),
    temperature: parseTemperature(pickSecret(secrets, env, ["TWIFFEL_XAI_TEMPERATURE"])),
  };
}

export async function callXaiChat(
  messages: Array<{ role: "system" | "user"; content: string }>,
  env: Env,
  responseFormat: Record<string, unknown>,
): Promise<string> {
  const { apiKey, model, baseUrl, reasoningEffort, temperature } = await resolveXaiConfig(env);
  if (!apiKey) {
    throw new Error(
      "Missing xAI API key, set TWIFFEL_XAI_API_KEY in Doppler (preferred) or as a Worker secret",
    );
  }

  const response = await fetchWithTimeout(
    `${baseUrl}/chat/completions`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${apiKey}` },
      body: JSON.stringify({
        model,
        temperature,
        reasoning_effort: reasoningEffort,
        messages,
        response_format: responseFormat,
      }),
    },
    XAI_TIMEOUT_MS,
  );
  if (!response.ok) {
    const errBody = (await response.text()).slice(0, 300);
    throw new Error(`xAI request failed with status ${response.status}: ${errBody}`);
  }

  const payload = (await response.json()) as {
    choices?: Array<{ message?: { content?: string } }>;
  };
  const content = payload.choices?.[0]?.message?.content?.trim();
  if (!content) throw new Error("xAI response did not contain message content");
  return content;
}
