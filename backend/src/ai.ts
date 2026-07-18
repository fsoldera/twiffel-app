import {
  BAILOUT_SYSTEM_PROMPT,
  BREAKDOWN_SYSTEM_PROMPT,
  COMPLETION_SYSTEM_PROMPT,
} from "./prompts";
import { isSafeCompassionateMessage, isSafePracticalStep } from "./tone";

export type MessageKind = "completion" | "bailout";

export interface Env {
  ANALYTICS?: AnalyticsEngineDataset;
  DOPPLER_SERVICE_TOKEN?: string;
  DOPPLER_API_BASE_URL?: string;
  DOPPLER_CACHE_TTL_MS?: string;
  DOPPLER_PROJECT?: string;
  DOPPLER_CONFIG?: string;
  /** TODO(template): rename APP_ → <APP>_ during bootstrap. */
  APP_XAI_API_KEY?: string;
  APP_XAI_MODEL?: string;
  /** Direct override / legacy fallback (prefer Doppler + APP_XAI_*). */
  XAI_API_KEY?: string;
  XAI_MODEL?: string;
}

const DEFAULT_DOPPLER_API_BASE_URL = "https://api.doppler.com/v3";
const DEFAULT_DOPPLER_CACHE_TTL_MS = 300000;

let dopplerCache: { expiresAt: number; secrets: Record<string, string> } | null = null;

const SAFE_FALLBACK_STEPS = [
  "Stand up and move to the place where you can begin.",
  "Prepare one item or tool you need for the task.",
  "Do one concrete action right now for 30 seconds.",
] as const;

const STATIC_FALLBACK_MESSAGE =
  "You are doing great — take it one small step at a time. Come back whenever you are ready.";

function normalizeTask(task: string): string {
  const trimmed = task.trim();
  return trimmed.length === 0 ? "your task" : trimmed;
}

function cleanStepText(step: string): string {
  return step.replace(/^\s*(?:[-*]|\d+[.)])\s*/, "").trim();
}

function normalizeToThreeFromText(content: string): string[] {
  const normalized = content.trim();
  if (!normalized) return [];
  try {
    const parsed = JSON.parse(normalized);
    if (Array.isArray(parsed)) {
      return parsed.map((i) => cleanStepText(String(i))).filter((i) => i.length > 0);
    }
  } catch {
    // fall through
  }
  return normalized.split("\n").map(cleanStepText).filter((l) => l.length > 0);
}

function toExactlyThreeSafeSteps(steps: string[]): string[] {
  const cleaned = steps
    .map((s) => s.trim())
    .filter((s) => s.length > 0)
    .filter(isSafePracticalStep);
  if (cleaned.length >= 3) return cleaned.slice(0, 3);
  const padded = [...cleaned];
  for (let i = cleaned.length; i < 3; i += 1) padded.push(SAFE_FALLBACK_STEPS[i]);
  return padded.slice(0, 3);
}

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

async function resolveXaiConfig(env: Env): Promise<{ apiKey?: string; model: string }> {
  try {
    const secrets = await fetchDopplerSecrets(env);
    const apiKey =
      secrets.APP_XAI_API_KEY ||
      env.APP_XAI_API_KEY ||
      secrets.XAI_API_KEY ||
      env.XAI_API_KEY;
    const model =
      secrets.APP_XAI_MODEL ||
      env.APP_XAI_MODEL ||
      secrets.XAI_MODEL ||
      env.XAI_MODEL ||
      "grok-3-mini";
    return { apiKey, model };
  } catch {
    return {
      apiKey: env.APP_XAI_API_KEY || env.XAI_API_KEY,
      model: env.APP_XAI_MODEL || env.XAI_MODEL || "grok-3-mini",
    };
  }
}

async function callXaiChat(
  messages: Array<{ role: "system" | "user"; content: string }>,
  env: Env,
): Promise<string> {
  const { apiKey, model } = await resolveXaiConfig(env);
  if (!apiKey) {
    throw new Error(
      "Missing xAI API key — set APP_XAI_API_KEY in Doppler (preferred) or as a Worker secret",
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

export async function generateThreeSteps(task: string, env: Env): Promise<string[]> {
  const normalizedTask = normalizeTask(task);
  try {
    const content = await callXaiChat(
      [
        { role: "system", content: `${BREAKDOWN_SYSTEM_PROMPT} Reply with JSON only.` },
        {
          role: "user",
          content: [
            `Task: "${normalizedTask}"`,
            "Return exactly 3 steps as a JSON array of strings.",
            "Each step must be a concrete practical action someone can do now.",
          ].join("\n"),
        },
      ],
      env,
    );
    return toExactlyThreeSafeSteps(normalizeToThreeFromText(content));
  } catch {
    return toExactlyThreeSafeSteps([]);
  }
}

export async function generateMessage(kind: MessageKind, task: string, env: Env): Promise<string> {
  const normalizedTask = normalizeTask(task);
  const systemPrompt = kind === "completion" ? COMPLETION_SYSTEM_PROMPT : BAILOUT_SYSTEM_PROMPT;
  const goalLine =
    kind === "completion"
      ? "Write one short congratulatory message."
      : "Write one short compassionate no-guilt message.";
  try {
    const content = await callXaiChat(
      [
        { role: "system", content: systemPrompt },
        {
          role: "user",
          content: [goalLine, "Keep it to 1 sentence.", "No emojis."].join("\n"),
        },
      ],
      env,
    );
    if (!isSafeCompassionateMessage(content, normalizedTask, { requireTaskMention: false })) {
      throw new Error("Message failed tone policy");
    }
    return content.trim();
  } catch {
    return STATIC_FALLBACK_MESSAGE;
  }
}
