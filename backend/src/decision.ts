import { DECISION_ANALYSIS_SYSTEM_PROMPT } from "./prompts";
import { analysisResponseFormat } from "./schema";
import { isSafeContent, validateAllInputs, type TaskInputValidation } from "./tone";
import { callXaiChat, type Env } from "./ai";

export type DecisionMode = "single" | "comparison";

/** How many pros/cons (or per-option points) we ask the model for and keep. */
export const ANALYSIS_POINTS_TARGET = 5;

/** How many verdict bullet sentences we ask for and keep. */
export const VERDICT_SENTENCES_TARGET = 5;

export interface DecisionRequest {
  mode: DecisionMode;
  /** Path A: the action being considered. */
  target?: string;
  /** Path B options. */
  optionA?: string;
  optionB?: string;
  obstacle: string;
  timing: string;
}

export interface AnalysisPoint {
  title: string;
  detail: string;
}

export interface DecisionAnalysis {
  mode: DecisionMode;
  target?: string;
  optionA?: string;
  optionB?: string;
  pros: AnalysisPoint[];
  cons: AnalysisPoint[];
  optionAPros: AnalysisPoint[];
  optionACons: AnalysisPoint[];
  optionBPros: AnalysisPoint[];
  optionBCons: AnalysisPoint[];
  /** Exactly VERDICT_SENTENCES_TARGET bullet sentences for the client. */
  verdict: string[];
}

function cleanPoint(raw: unknown): AnalysisPoint | null {
  if (!raw || typeof raw !== "object") return null;
  const obj = raw as { title?: unknown; heading?: unknown; label?: unknown; detail?: unknown; text?: unknown; body?: unknown; content?: unknown };
  const titleRaw =
    [obj.title, obj.heading, obj.label].find((value) => typeof value === "string") ?? "";
  const detailRaw =
    [obj.detail, obj.text, obj.body, obj.content].find((value) => typeof value === "string") ?? "";
  const title = typeof titleRaw === "string" ? titleRaw.trim() : "";
  const detail = typeof detailRaw === "string" ? detailRaw.trim() : "";
  if (!title || !detail) return null;
  return {
    title: title.length > 80 ? title.slice(0, 80).trim() : title,
    detail: detail.length > 400 ? detail.slice(0, 400).trim() : detail,
  };
}

function cleanPoints(raw: unknown, max = ANALYSIS_POINTS_TARGET): AnalysisPoint[] {
  if (!Array.isArray(raw)) return [];
  const points = raw.map(cleanPoint).filter((p): p is AnalysisPoint => p != null);
  return points.slice(0, max);
}

function point(title: string, detail: string): AnalysisPoint {
  return { title, detail };
}

function coerceVerdictItem(item: unknown): string | null {
  if (typeof item === "string") return item;
  if (item && typeof item === "object") {
    const obj = item as Record<string, unknown>;
    for (const key of ["text", "sentence", "content", "detail", "verdict"]) {
      if (typeof obj[key] === "string") return obj[key];
    }
  }
  return null;
}

/** Normalize model verdict (string or string[]) into bullet sentence strings. */
export function normalizeVerdict(
  raw: unknown,
  max = VERDICT_SENTENCES_TARGET,
): string[] {
  const fromParts = (parts: string[]): string[] =>
    parts
      .map((part) => part.trim())
      .filter((part) => part.length > 0)
      .slice(0, max)
      .map((part) => (/[.!?]$/.test(part) ? part : `${part}.`));

  if (Array.isArray(raw)) {
    const parts = raw.map(coerceVerdictItem).filter((item): item is string => item != null);
    return fromParts(parts);
  }
  if (typeof raw !== "string") return [];
  const trimmed = raw.trim();
  if (!trimmed) return [];
  if (trimmed.startsWith("[")) {
    try {
      return normalizeVerdict(JSON.parse(trimmed), max);
    } catch {
      // Fall through to sentence split.
    }
  }
  // Prefer explicit newlines when the model already separated bullets.
  if (/\n/.test(trimmed)) {
    return fromParts(trimmed.split(/\n+/));
  }
  const sentences = trimmed
    .split(/(?<=[.!?])\s+/)
    .map((part) => part.trim())
    .filter((part) => part.length > 0);
  return fromParts(sentences.length > 0 ? sentences : [trimmed]);
}

/** Pull a JSON object out of fenced or prose-wrapped model output. */
export function extractJsonPayload(content: string): string | null {
  const trimmed = content.trim();
  const fence = trimmed.match(/```(?:json)?\s*([\s\S]*?)```/i);
  const body = (fence ? fence[1] : trimmed).trim();
  const start = body.indexOf("{");
  if (start < 0) return null;
  let depth = 0;
  let inString = false;
  let escape = false;
  for (let i = start; i < body.length; i++) {
    const ch = body[i];
    if (inString) {
      if (escape) {
        escape = false;
      } else if (ch === "\\") {
        escape = true;
      } else if (ch === '"') {
        inString = false;
      }
      continue;
    }
    if (ch === '"') {
      inString = true;
      continue;
    }
    if (ch === "{") depth++;
    if (ch === "}") {
      depth--;
      if (depth === 0) return body.slice(start, i + 1);
    }
  }
  return null;
}

function pickList(parsed: Record<string, unknown>, keys: string[]): unknown {
  for (const key of keys) {
    if (parsed[key] != null) return parsed[key];
  }
  return undefined;
}

function fallbackSingle(req: DecisionRequest): DecisionAnalysis {
  const target = (req.target || "this decision").trim();
  const timing = req.timing.toLowerCase();
  return {
    mode: "single",
    target,
    pros: [
      point("1. Clearer direction", `Naming "${target}" makes the choice concrete enough to evaluate honestly.`),
      point(
        "2. Timeline awareness",
        `Wanting this ${timing} helps you weigh urgency against waiting costs.`,
      ),
      point(
        "3. Obstacle is named",
        `Focusing on "${req.obstacle}" keeps the analysis practical instead of vague worry.`,
      ),
      point("4. Values come into view", `Working through "${target}" surfaces what you care about protecting most.`),
      point("5. Decision becomes testable", "You can define a small next check instead of staying in mental loops."),
    ],
    cons: [
      point(
        "1. Real trade-offs remain",
        `Moving ahead on "${target}" still means accepting costs, effort, or uncertainty.`,
      ),
      point("2. Waiting has a cost too", "Delaying can feel safer, but it may quietly spend time, energy, or opportunity."),
      point("3. Ambiguity can return", "Without a next checkpoint, the same doubts are likely to resurface."),
      point("4. Obstacle may intensify", `If "${req.obstacle}" is ignored, pressure can grow even while you wait.`),
      point("5. Perfect certainty is unlikely", "You may never feel 100% ready, so waiting for that signal can stall you."),
    ],
    optionAPros: [],
    optionACons: [],
    optionBPros: [],
    optionBCons: [],
    verdict: [
      `Based on your timing (${req.timing}) and main obstacle (${req.obstacle}), "${target}" deserves a clear lean.`,
      "The named obstacle is real, so treat it as the main constraint rather than a vague worry.",
      "A careful next step beats waiting for perfect certainty that may never arrive.",
      "Keep the move small enough to reverse if early feedback looks wrong.",
      "If the obstacle still blocks every path, waiting is wiser than forcing a leap.",
    ],
  };
}

function fallbackComparison(req: DecisionRequest): DecisionAnalysis {
  const optionA = (req.optionA || "Option A").trim();
  const optionB = (req.optionB || "Option B").trim();
  return {
    mode: "comparison",
    optionA,
    optionB,
    pros: [],
    cons: [],
    optionAPros: [
      point("1. Forward movement", `"${optionA}" is the more change-oriented path if you want momentum.`),
      point("2. Matches stated desire", "It may better reflect what you already feel drawn toward."),
      point("3. Forces clarity", "Choosing it creates a concrete plan you can test against reality."),
      point("4. Learning speed", "You get faster feedback on whether this path fits your real constraints."),
      point("5. Motivational lift", "Acting on the option you lean toward can reduce rumination."),
    ],
    optionACons: [
      point("1. Higher friction", `Obstacle "${req.obstacle}" may hit this option harder at first.`),
      point("2. Commitment pressure", "It can feel harder to reverse if the early weeks are rocky."),
      point("3. Upfront cost", "Time, money, or effort may spike before benefits appear."),
      point("4. Transition stress", "Changing lanes often adds temporary chaos even when the destination is good."),
      point("5. Over-optimism risk", "Excitement can underweight practical blockers you already named."),
    ],
    optionBPros: [
      point("1. Continuity", `"${optionB}" preserves stability while you gather more information.`),
      point("2. Lower immediate stress", "It may reduce short-term pressure around your main obstacle."),
      point("3. Room to prepare", "You can strengthen finances, timing, or confidence before a bigger move."),
      point("4. Familiar systems", "Existing routines and tools already support this path."),
      point("5. Reversible by default", "Staying closer to the status quo usually keeps more exit options open."),
    ],
    optionBCons: [
      point("1. Delayed progress", "Staying put can quietly extend the indecision window."),
      point(
        "2. Opportunity cost",
        `If timing is "${req.timing}", waiting may conflict with your preferred window.`,
      ),
      point("3. Habit lock-in", "The status quo can become harder to leave the longer it continues."),
      point("4. Quiet regret risk", "You may later wish you had tested the other path sooner."),
      point("5. Obstacle persists", `Avoiding change does not dissolve "${req.obstacle}" by itself.`),
    ],
    verdict: [
      `Given obstacle "${req.obstacle}" and timing "${req.timing}", weigh "${optionA}" against "${optionB}" with a clear lean.`,
      `"${optionA}" wins if the upside clearly outruns the friction you already named.`,
      `"${optionB}" wins if stability and lower stress matter more in this window.`,
      "Use the obstacle as the tie-breaker instead of chasing a perfect feeling.",
      "If neither option clears the obstacle soon enough, waiting is the wiser call.",
    ],
  };
}

export function parseAnalysisJson(content: string, req: DecisionRequest): DecisionAnalysis | null {
  const payload = extractJsonPayload(content);
  if (!payload) return null;
  try {
    const parsed = JSON.parse(payload) as Record<string, unknown>;
    const verdict = normalizeVerdict(parsed.verdict);
    if (verdict.length === 0) return null;

    if (req.mode === "single") {
      return {
        mode: "single",
        target: req.target?.trim(),
        pros: cleanPoints(pickList(parsed, ["pros"])),
        cons: cleanPoints(pickList(parsed, ["cons"])),
        optionAPros: [],
        optionACons: [],
        optionBPros: [],
        optionBCons: [],
        verdict,
      };
    }

    return {
      mode: "comparison",
      optionA: req.optionA?.trim(),
      optionB: req.optionB?.trim(),
      pros: [],
      cons: [],
      optionAPros: cleanPoints(pickList(parsed, ["optionAPros", "option_a_pros"])),
      optionACons: cleanPoints(pickList(parsed, ["optionACons", "option_a_cons"])),
      optionBPros: cleanPoints(pickList(parsed, ["optionBPros", "option_b_pros"])),
      optionBCons: cleanPoints(pickList(parsed, ["optionBCons", "option_b_cons"])),
      verdict,
    };
  } catch {
    return null;
  }
}

function buildUserPrompt(req: DecisionRequest): string {
  const n = ANALYSIS_POINTS_TARGET;
  if (req.mode === "single") {
    return [
      `Mode: single (do or buy)`,
      `Decision target: "${req.target?.trim()}"`,
      `Main obstacle: "${req.obstacle.trim()}"`,
      `Preferred timing: "${req.timing.trim()}"`,
      "",
      "Lists:",
      `Return JSON keys pros and cons (each an array of exactly ${n} {title, detail}).`,
      'Titles should be short numbered labels like "1. Safety upgrade".',
      "Details must stay specific to this decision and obstacle.",
      "Do not echo the preferred timing in every detail; omit timing from lists unless one point is truly about the deadline.",
      "Keep list copy factual and balanced, not witty.",
      "",
      "Verdict (required, do not omit):",
      `Return verdict as a JSON array of exactly ${VERDICT_SENTENCES_TARGET} strings (one sentence each) with a lean (positive / cautious / wait).`,
      "Count the array items before answering; it must be exactly 5.",
      "Verdict tone: smart, nice, balanced, witty; no vulgarity or shame.",
      "Timing may appear once in the verdict if useful.",
    ].join("\n");
  }
  return [
    `Mode: comparison (this or that)`,
    `Option A: "${req.optionA?.trim()}"`,
    `Option B: "${req.optionB?.trim()}"`,
    `Main obstacle: "${req.obstacle.trim()}"`,
    `Preferred timing: "${req.timing.trim()}"`,
    "",
    "Lists:",
    `Return JSON keys optionAPros, optionACons, optionBPros, optionBCons (each an array of exactly ${n} {title, detail}).`,
    'Titles should be short numbered labels like "1. Lower maintenance".',
    "Details must stay specific to these options and the obstacle.",
    "Do not echo the preferred timing in every detail; omit timing from lists unless one point is truly about the deadline.",
    "Keep list copy factual and balanced, not witty.",
    "",
      "Verdict (required, do not omit):",
      `Return verdict as a JSON array of exactly ${VERDICT_SENTENCES_TARGET} strings (one sentence each) saying which option has a slight edge and why, or when waiting is wiser.`,
    "Count the array items before answering; it must be exactly 5.",
    "Verdict tone: smart, nice, balanced, witty; no vulgarity or shame.",
    "Timing may appear once in the verdict if useful.",
  ].join("\n");
}

export function validateDecisionRequest(payload: unknown): DecisionRequest | null {
  if (!payload || typeof payload !== "object") return null;
  const p = payload as Record<string, unknown>;
  const mode = p.mode === "single" || p.mode === "comparison" ? p.mode : null;
  const obstacle = typeof p.obstacle === "string" ? p.obstacle.trim() : "";
  const timing = typeof p.timing === "string" ? p.timing.trim() : "";
  if (!mode || !obstacle || !timing) return null;

  if (mode === "single") {
    const target = typeof p.target === "string" ? p.target.trim() : "";
    if (!target) return null;
    return { mode, target, obstacle, timing };
  }

  const optionA = typeof p.optionA === "string" ? p.optionA.trim() : "";
  const optionB = typeof p.optionB === "string" ? p.optionB.trim() : "";
  if (!optionA || !optionB) return null;
  return { mode, optionA, optionB, obstacle, timing };
}

/** Content-safety on every user free-text field before any model call. */
export function validateDecisionInputs(req: DecisionRequest): TaskInputValidation {
  const texts: string[] = [];
  if (req.mode === "single") {
    if (req.target) texts.push(req.target);
  } else {
    if (req.optionA) texts.push(req.optionA);
    if (req.optionB) texts.push(req.optionB);
  }
  texts.push(req.obstacle, req.timing);
  return validateAllInputs(texts);
}

export async function generateDecisionAnalysis(
  req: DecisionRequest,
  env: Env,
): Promise<DecisionAnalysis> {
  const localFallback = req.mode === "single" ? fallbackSingle(req) : fallbackComparison(req);
  try {
    const content = await callXaiChat(
      [
        { role: "system", content: DECISION_ANALYSIS_SYSTEM_PROMPT },
        { role: "user", content: buildUserPrompt(req) },
      ],
      env,
      analysisResponseFormat(req.mode),
    );
    const parsed = parseAnalysisJson(content, req);
    if (!parsed) {
      console.log(JSON.stringify({ event: "analyze_fallback", reason: "parse" }));
      return localFallback;
    }
    const safeVerdict = parsed.verdict.filter((line) => isSafeContent(line));
    parsed.verdict =
      safeVerdict.length > 0
        ? safeVerdict.slice(0, VERDICT_SENTENCES_TARGET)
        : localFallback.verdict;
    console.log(JSON.stringify({ event: "analyze_ok", verdicts: parsed.verdict.length }));
    return parsed;
  } catch (error) {
    const reason = error instanceof Error ? error.message : "unknown";
    console.log(JSON.stringify({ event: "analyze_fallback", reason }));
    return localFallback;
  }
}
