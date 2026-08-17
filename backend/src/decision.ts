import { DECISION_ANALYSIS_SYSTEM_PROMPT, DECISION_VERDICT_SYSTEM_PROMPT } from "./prompts";
import { analysisResponseFormat, verdictRewriteResponseFormat } from "./schema";
import {
  computeScore,
  scoreSummaryLines,
  verifiedCalculation,
  verdictAgreesWithScore,
  type AnalysisScore,
} from "./score";
import { isSafeContent, validateAllInputs, type TaskInputValidation } from "./tone";
import { callXaiChat, type Env } from "./ai";

export interface DecisionRequest {
  optionA: string;
  optionB: string;
  obstacle: string;
  timing: string;
}

/** How many pros/cons per option we ask the model for and keep. */
export const ANALYSIS_POINTS_TARGET = 5;

/** How many verdict bullet sentences we ask for and keep. */
export const VERDICT_SENTENCES_TARGET = 5;

export interface AnalysisPoint {
  tagline: string;
  description: string;
  weight: number;
}

export interface DecisionAnalysis {
  mode: "comparison";
  optionA: string;
  optionB: string;
  optionAPros: AnalysisPoint[];
  optionACons: AnalysisPoint[];
  optionBPros: AnalysisPoint[];
  optionBCons: AnalysisPoint[];
  /** Exactly VERDICT_SENTENCES_TARGET bullet sentences for the client. */
  verdict: string[];
  /** Verified sums from the list weights, not the model's raw arithmetic. */
  calculation?: Record<string, unknown>;
}

function parseWeight(raw: unknown): number | null {
  if (typeof raw === "number" && Number.isFinite(raw)) {
    return Math.min(100, Math.max(1, Math.round(raw)));
  }
  if (typeof raw === "string") {
    const parsed = Number.parseInt(raw.trim(), 10);
    if (Number.isFinite(parsed)) return Math.min(100, Math.max(1, parsed));
  }
  return null;
}

function cleanPoint(raw: unknown): AnalysisPoint | null {
  if (!raw || typeof raw !== "object") return null;
  const obj = raw as Record<string, unknown>;
  const taglineRaw =
    [obj.tagline, obj.title, obj.heading, obj.label].find((value) => typeof value === "string") ?? "";
  const descriptionRaw =
    [obj.description, obj.detail, obj.text, obj.body, obj.content].find(
      (value) => typeof value === "string",
    ) ?? "";
  const tagline = typeof taglineRaw === "string" ? taglineRaw.trim() : "";
  const description = typeof descriptionRaw === "string" ? descriptionRaw.trim() : "";
  const weight = parseWeight(obj.weight ?? obj.score);
  if (!tagline || !description || weight == null) return null;
  return {
    tagline: tagline.length > 80 ? tagline.slice(0, 80).trim() : tagline,
    description: description.length > 400 ? description.slice(0, 400).trim() : description,
    weight,
  };
}

function cleanPoints(raw: unknown, max = ANALYSIS_POINTS_TARGET): AnalysisPoint[] {
  if (!Array.isArray(raw)) return [];
  const points = raw
    .map(cleanPoint)
    .filter((p): p is AnalysisPoint => p != null)
    .sort((a, b) => b.weight - a.weight);
  return points.slice(0, max);
}

function requirePoints(raw: unknown): AnalysisPoint[] | null {
  const points = cleanPoints(raw);
  if (points.length !== ANALYSIS_POINTS_TARGET) return null;
  return points;
}

function withVerifiedCalculation(analysis: DecisionAnalysis): DecisionAnalysis {
  analysis.calculation = verifiedCalculation(computeScore(analysis));
  return analysis;
}

function formatPointLines(points: AnalysisPoint[]): string {
  return points.map((point) => `- ${point.tagline} (${point.weight}): ${point.description}`).join("\n");
}

function formatLockedLists(analysis: DecisionAnalysis): string {
  return [
    `Option A (${analysis.optionA}) pros:`,
    formatPointLines(analysis.optionAPros),
    `Option A cons:`,
    formatPointLines(analysis.optionACons),
    `Option B (${analysis.optionB}) pros:`,
    formatPointLines(analysis.optionBPros),
    `Option B cons:`,
    formatPointLines(analysis.optionBCons),
  ].join("\n");
}

function point(tagline: string, description: string, weight: number): AnalysisPoint {
  return { tagline, description, weight };
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

function fallbackComparison(req: DecisionRequest): DecisionAnalysis {
  const optionA = req.optionA.trim();
  const optionB = req.optionB.trim();
  return withVerifiedCalculation({
    mode: "comparison",
    optionA,
    optionB,
    optionAPros: [
      point("Forward movement", `"${optionA}" is the more change-oriented path if you want momentum.`, 78),
      point("Matches stated desire", "It may better reflect what you already feel drawn toward.", 66),
      point("Forces clarity", "Choosing it creates a concrete plan you can test against reality.", 70),
      point("Learning speed", "You get faster feedback on whether this path fits your real constraints.", 58),
      point("Motivational lift", "Acting on the option you lean toward can reduce rumination.", 49),
    ],
    optionACons: [
      point("Higher friction", `Obstacle "${req.obstacle}" may hit this option harder at first.`, 90),
      point("Commitment pressure", "It can feel harder to reverse if the early weeks are rocky.", 62),
      point("Upfront cost", "Time, money, or effort may spike before benefits appear.", 71),
      point("Transition stress", "Changing lanes often adds temporary chaos even when the destination is good.", 55),
      point("Over-optimism risk", "Excitement can underweight practical blockers you already named.", 60),
    ],
    optionBPros: [
      point("Continuity", `"${optionB}" preserves stability while you gather more information.`, 74),
      point("Lower immediate stress", "It may reduce short-term pressure around your main obstacle.", 82),
      point("Room to prepare", "You can strengthen finances, timing, or confidence before a bigger move.", 61),
      point("Familiar systems", "Existing routines and tools already support this path.", 53),
      point("Reversible by default", "Staying closer to the status quo usually keeps more exit options open.", 57),
    ],
    optionBCons: [
      point("Delayed progress", "Staying put can quietly extend the indecision window.", 69),
      point(
        "Opportunity cost",
        `If timing is "${req.timing}", waiting may conflict with your preferred window.`,
        48,
      ),
      point("Habit lock-in", "The status quo can become harder to leave the longer it continues.", 56),
      point("Quiet regret risk", "You may later wish you had tested the other path sooner.", 51),
      point("Obstacle persists", `Avoiding change does not dissolve "${req.obstacle}" by itself.`, 88),
    ],
    verdict: [
      `Given obstacle "${req.obstacle}" and timing "${req.timing}", weigh "${optionA}" against "${optionB}" with a clear lean.`,
      `"${optionA}" wins if the upside clearly outruns the friction you already named.`,
      `"${optionB}" wins if stability and lower stress matter more in this window.`,
      "Use the obstacle as the tie-breaker instead of chasing a perfect feeling.",
      "If neither option clears the obstacle soon enough, waiting is the wiser call.",
    ],
  });
}

export function parseAnalysisJson(content: string, req: DecisionRequest): DecisionAnalysis | null {
  const payload = extractJsonPayload(content);
  if (!payload) return null;
  try {
    const parsed = JSON.parse(payload) as Record<string, unknown>;
    const verdict = normalizeVerdict(parsed.verdict);
    if (verdict.length === 0) return null;

    const optionAPros = requirePoints(pickList(parsed, ["optionAPros", "option_a_pros"]));
    const optionACons = requirePoints(pickList(parsed, ["optionACons", "option_a_cons"]));
    const optionBPros = requirePoints(pickList(parsed, ["optionBPros", "option_b_pros"]));
    const optionBCons = requirePoints(pickList(parsed, ["optionBCons", "option_b_cons"]));
    if (!optionAPros || !optionACons || !optionBPros || !optionBCons) return null;
    return withVerifiedCalculation({
      mode: "comparison",
      optionA: req.optionA.trim(),
      optionB: req.optionB.trim(),
      optionAPros,
      optionACons,
      optionBPros,
      optionBCons,
      verdict,
    });
  } catch {
    return null;
  }
}

/** Byte-stable user prefix. Unique decision fields follow in a second user message. */
const DECISION_ANALYSIS_USER_STATIC = [
  "Mode: comparison (this or that)",
  "",
  "Evaluation:",
  "Judge both options mainly through the most important point to consider.",
  "That point is the tie-breaker. Say which option fits it better, and why.",
  "Timing must not be the main reason for the lean.",
  "",
  "Lists:",
  `Return JSON keys optionAPros, optionACons, optionBPros, optionBCons. Each key is an array of exactly ${ANALYSIS_POINTS_TARGET} objects.`,
  "Each object MUST be exactly {tagline, description, weight}. No other keys.",
  'Example: {"tagline":"Lower upkeep","description":"This option costs less to keep up each month.","weight":72}',
  "tagline: 2 to 6 common words, no number prefix.",
  "description: one short sentence ending with a period, specific to these options and the most important point.",
  "weight: integer 1 to 100. Vary the weights. Higher means the point should count more.",
  "At least one point on each option must speak directly to the most important point.",
  "Do not echo the preferred timing in every description; omit timing from lists unless one point is truly about the deadline.",
  "Keep list copy factual and balanced, not witty.",
  "",
  "Calculation (required, fill this after the lists):",
  "Return calculation as {optionAProSum, optionAConSum, optionANet, optionBProSum, optionBConSum, optionBNet, lean}.",
  "Each net is that option's pro sum minus con sum.",
  'lean is "a" if option A net is higher, "b" if option B net is higher, "too_close" if the nets are close.',
  "",
  "Verdict (required, write this last):",
  `Return verdict as a JSON array of exactly ${VERDICT_SENTENCES_TARGET} strings (one sentence each).`,
  "Count the array items before answering; it must be exactly 5.",
  "The 5 sentences must match calculation.lean. Do not pick the lower net.",
  "Each sentence must use a concrete point from the lists you just wrote, especially the highest weights.",
  "Do not write generic lines that ignore those points.",
  "The lean must rest on the most important point to consider.",
  "Verdict tone: nice, balanced, lightly witty, simple words; no vulgarity or shame.",
  "Timing may appear once in the verdict if useful, but not as the main reason.",
].join("\n");

const DECISION_VERDICT_REWRITE_USER_STATIC = [
  "Rewrite only the summary verdict.",
  "Keep the lists locked. Use those facts. Do not invent new points.",
  "Do not write a score number in the sentences.",
  "Each sentence must use a concrete point from the locked lists, especially the highest weights.",
  `Return verdict as a JSON array of exactly ${VERDICT_SENTENCES_TARGET} strings.`,
].join("\n");

function buildUserDecisionFields(req: DecisionRequest): string {
  return [
    `Option A: "${req.optionA.trim()}"`,
    `Option B: "${req.optionB.trim()}"`,
    `Most important point to consider (main criterion): "${req.obstacle.trim()}"`,
    `Preferred timing (background only): "${req.timing.trim()}"`,
  ].join("\n");
}

export function validateDecisionRequest(payload: unknown): DecisionRequest | null {
  if (!payload || typeof payload !== "object") return null;
  const p = payload as Record<string, unknown>;
  if (p.mode != null && p.mode !== "comparison") return null;
  const obstacle = typeof p.obstacle === "string" ? p.obstacle.trim() : "";
  const timing = typeof p.timing === "string" ? p.timing.trim() : "";
  const optionA = typeof p.optionA === "string" ? p.optionA.trim() : "";
  const optionB = typeof p.optionB === "string" ? p.optionB.trim() : "";
  if (!obstacle || !timing || !optionA || !optionB) return null;
  return { optionA, optionB, obstacle, timing };
}

/** Content-safety on every user free-text field before any model call. */
export function validateDecisionInputs(req: DecisionRequest): TaskInputValidation {
  return validateAllInputs([req.optionA, req.optionB, req.obstacle, req.timing]);
}

async function rewriteVerdictToMatchScore(
  req: DecisionRequest,
  analysis: DecisionAnalysis,
  score: AnalysisScore,
  env: Env,
): Promise<string[] | null> {
  const loser = score.leansPrimary ? score.secondaryLabel : score.primaryLabel;
  const result = await callXaiChat(
    [
      { role: "system", content: DECISION_VERDICT_SYSTEM_PROMPT },
      { role: "user", content: DECISION_VERDICT_REWRITE_USER_STATIC },
      {
        role: "user",
        content: [
          `Option A: "${req.optionA.trim()}"`,
          `Option B: "${req.optionB.trim()}"`,
          `Most important point to consider: "${req.obstacle.trim()}"`,
          "",
          "Locked lists:",
          formatLockedLists(analysis),
          "",
          "Verified calculation, do not contradict:",
          ...scoreSummaryLines(score),
          `Do not say ${loser} is the better choice.`,
        ].join("\n"),
      },
    ],
    env,
    verdictRewriteResponseFormat(),
  );
  console.log(
    JSON.stringify({
      event: "analyze_verdict_rewrite_xai",
      prompt_tokens: result.promptTokens,
      cached_tokens: result.cachedTokens,
    }),
  );
  const payload = extractJsonPayload(result.content);
  if (!payload) return null;
  const parsed = JSON.parse(payload) as Record<string, unknown>;
  const verdict = normalizeVerdict(parsed.verdict).filter((line) => isSafeContent(line));
  return verdict.length > 0 ? verdict : null;
}

async function alignVerdictWithScore(
  req: DecisionRequest,
  analysis: DecisionAnalysis,
  env: Env,
): Promise<string[]> {
  const score = computeScore(analysis);
  if (verdictAgreesWithScore(analysis.verdict, score)) {
    return analysis.verdict;
  }
  try {
    const rewritten = await rewriteVerdictToMatchScore(req, analysis, score, env);
    if (rewritten && verdictAgreesWithScore(rewritten, score)) {
      console.log(JSON.stringify({ event: "analyze_verdict_rewrite" }));
      return rewritten;
    }
  } catch (error) {
    const reason = error instanceof Error ? error.message : "unknown";
    console.log(JSON.stringify({ event: "analyze_verdict_rewrite_failed", reason }));
  }
  console.log(JSON.stringify({ event: "analyze_verdict_keep_model" }));
  return analysis.verdict;
}

export async function generateDecisionAnalysis(
  req: DecisionRequest,
  env: Env,
): Promise<DecisionAnalysis> {
  const localFallback = fallbackComparison(req);
  try {
    const result = await callXaiChat(
      [
        { role: "system", content: DECISION_ANALYSIS_SYSTEM_PROMPT },
        { role: "user", content: DECISION_ANALYSIS_USER_STATIC },
        { role: "user", content: buildUserDecisionFields(req) },
      ],
      env,
      analysisResponseFormat(),
    );
    const parsed = parseAnalysisJson(result.content, req);
    if (!parsed) {
      console.log(JSON.stringify({ event: "analyze_fallback", reason: "parse" }));
      return localFallback;
    }
    const safeVerdict = parsed.verdict.filter((line) => isSafeContent(line));
    parsed.verdict =
      safeVerdict.length > 0
        ? safeVerdict.slice(0, VERDICT_SENTENCES_TARGET)
        : localFallback.verdict;
    parsed.verdict = await alignVerdictWithScore(req, parsed, env);
    withVerifiedCalculation(parsed);
    console.log(
      JSON.stringify({
        event: "analyze_ok",
        verdicts: parsed.verdict.length,
        prompt_tokens: result.promptTokens,
        cached_tokens: result.cachedTokens,
      }),
    );
    return parsed;
  } catch (error) {
    const reason = error instanceof Error ? error.message : "unknown";
    console.log(JSON.stringify({ event: "analyze_fallback", reason }));
    return localFallback;
  }
}
