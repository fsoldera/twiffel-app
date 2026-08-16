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
  tagline: string;
  description: string;
  weight: number;
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
  if (analysis.mode === "single") {
    return ["Pros:", formatPointLines(analysis.pros), "", "Cons:", formatPointLines(analysis.cons)].join(
      "\n",
    );
  }
  return [
    `Option A (${analysis.optionA ?? "Option A"}) pros:`,
    formatPointLines(analysis.optionAPros),
    `Option A cons:`,
    formatPointLines(analysis.optionACons),
    `Option B (${analysis.optionB ?? "Option B"}) pros:`,
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

function fallbackSingle(req: DecisionRequest): DecisionAnalysis {
  const target = (req.target || "this decision").trim();
  const timing = req.timing.toLowerCase();
  return withVerifiedCalculation({
    mode: "single",
    target,
    pros: [
      point("Clearer direction", `Naming "${target}" makes the choice concrete enough to evaluate honestly.`, 88),
      point(
        "Timeline awareness",
        `Wanting this ${timing} helps you weigh urgency against waiting costs.`,
        64,
      ),
      point(
        "Obstacle is named",
        `Focusing on "${req.obstacle}" keeps the analysis practical instead of vague worry.`,
        92,
      ),
      point("Values come into view", `Working through "${target}" surfaces what you care about protecting most.`, 71),
      point("Decision becomes testable", "You can define a small next check instead of staying in mental loops.", 55),
    ],
    cons: [
      point(
        "Real trade-offs remain",
        `Moving ahead on "${target}" still means accepting costs, effort, or uncertainty.`,
        80,
      ),
      point("Waiting has a cost too", "Delaying can feel safer, but it may quietly spend time, energy, or opportunity.", 68),
      point("Ambiguity can return", "Without a next checkpoint, the same doubts are likely to resurface.", 52),
      point("Obstacle may intensify", `If "${req.obstacle}" is ignored, pressure can grow even while you wait.`, 90),
      point("Perfect certainty is unlikely", "You may never feel 100% ready, so waiting for that signal can stall you.", 47),
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
  });
}

function fallbackComparison(req: DecisionRequest): DecisionAnalysis {
  const optionA = (req.optionA || "Option A").trim();
  const optionB = (req.optionB || "Option B").trim();
  return withVerifiedCalculation({
    mode: "comparison",
    optionA,
    optionB,
    pros: [],
    cons: [],
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

    if (req.mode === "single") {
      const pros = requirePoints(pickList(parsed, ["pros"]));
      const cons = requirePoints(pickList(parsed, ["cons"]));
      if (!pros || !cons) return null;
      return withVerifiedCalculation({
        mode: "single",
        target: req.target?.trim(),
        pros,
        cons,
        optionAPros: [],
        optionACons: [],
        optionBPros: [],
        optionBCons: [],
        verdict,
      });
    }

    const optionAPros = requirePoints(pickList(parsed, ["optionAPros", "option_a_pros"]));
    const optionACons = requirePoints(pickList(parsed, ["optionACons", "option_a_cons"]));
    const optionBPros = requirePoints(pickList(parsed, ["optionBPros", "option_b_pros"]));
    const optionBCons = requirePoints(pickList(parsed, ["optionBCons", "option_b_cons"]));
    if (!optionAPros || !optionACons || !optionBPros || !optionBCons) return null;
    return withVerifiedCalculation({
      mode: "comparison",
      optionA: req.optionA?.trim(),
      optionB: req.optionB?.trim(),
      pros: [],
      cons: [],
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

function buildUserPrompt(req: DecisionRequest): string {
  const n = ANALYSIS_POINTS_TARGET;
  if (req.mode === "single") {
    return [
      `Mode: single (do or buy)`,
      `Decision target: "${req.target?.trim()}"`,
      `Most important point to consider (main criterion): "${req.obstacle.trim()}"`,
      `Preferred timing (background only): "${req.timing.trim()}"`,
      "",
      "Evaluation:",
      "Judge the decision mainly through the most important point to consider.",
      "That point is the tie-breaker. Timing must not be the main reason for the lean.",
      "",
      "Lists:",
      `Return JSON keys pros and cons. Each key is an array of exactly ${n} objects.`,
      "Each object MUST be exactly {tagline, description, weight}. No other keys.",
      'Example: {"tagline":"Lower upkeep","description":"This option costs less to keep up each month.","weight":72}',
      "tagline: 2 to 6 common words, no number prefix.",
      "description: one short sentence ending with a period, specific to this decision and the most important point.",
      "weight: integer 1 to 100. Vary the weights. Higher means the point should count more.",
      "At least one pro and one con must speak directly to the most important point.",
      "Do not echo the preferred timing in every description; omit timing from lists unless one point is truly about the deadline.",
      "Keep list copy factual and balanced, not witty.",
      "",
      "Calculation (required, fill this after the lists):",
      "Return calculation as {proSum, conSum, net, lean}.",
      "proSum is the sum of the 5 pro weights. conSum is the sum of the 5 con weights. net is proSum minus conSum.",
      'lean is "go" if net is clearly positive, "wait" if net is clearly negative, "too_close" if the gap is small.',
      "",
      "Verdict (required, write this last):",
      `Return verdict as a JSON array of exactly ${VERDICT_SENTENCES_TARGET} strings (one sentence each).`,
      "Count the array items before answering; it must be exactly 5.",
      "The 5 sentences must match calculation.lean.",
      "Each sentence must use a concrete point from the lists you just wrote, especially the highest weights.",
      "Do not write generic lines that ignore those points.",
      "The lean must rest on the most important point to consider. Say how the decision fits that point.",
      "Verdict tone: nice, balanced, lightly witty, simple words; no vulgarity or shame.",
      "Timing may appear once in the verdict if useful, but not as the main reason.",
    ].join("\n");
  }
  return [
    `Mode: comparison (this or that)`,
    `Option A: "${req.optionA?.trim()}"`,
    `Option B: "${req.optionB?.trim()}"`,
    `Most important point to consider (main criterion): "${req.obstacle.trim()}"`,
    `Preferred timing (background only): "${req.timing.trim()}"`,
    "",
    "Evaluation:",
    "Judge both options mainly through the most important point to consider.",
    "That point is the tie-breaker. Say which option fits it better, and why.",
    "Timing must not be the main reason for the lean.",
    "",
    "Lists:",
    `Return JSON keys optionAPros, optionACons, optionBPros, optionBCons. Each key is an array of exactly ${n} objects.`,
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

async function rewriteVerdictToMatchScore(
  req: DecisionRequest,
  analysis: DecisionAnalysis,
  score: AnalysisScore,
  env: Env,
): Promise<string[] | null> {
  const loser = score.leansPrimary ? score.secondaryLabel : score.primaryLabel;
  const content = await callXaiChat(
    [
      { role: "system", content: DECISION_VERDICT_SYSTEM_PROMPT },
      {
        role: "user",
        content: [
          "Rewrite only the summary verdict.",
          "Keep the lists locked. Use those facts. Do not invent new points.",
          req.mode === "single"
            ? `Decision: "${req.target?.trim() ?? ""}"`
            : `Option A: "${req.optionA?.trim() ?? ""}"\nOption B: "${req.optionB?.trim() ?? ""}"`,
          `Most important point to consider: "${req.obstacle.trim()}"`,
          "",
          "Locked lists:",
          formatLockedLists(analysis),
          "",
          "Verified calculation, do not contradict:",
          ...scoreSummaryLines(score),
          `Do not say ${loser} is the better choice.`,
          "Do not write a score number in the sentences.",
          "Each sentence must use a concrete point from the locked lists, especially the highest weights.",
          `Return verdict as a JSON array of exactly ${VERDICT_SENTENCES_TARGET} strings.`,
        ].join("\n"),
      },
    ],
    env,
    verdictRewriteResponseFormat(),
  );
  const payload = extractJsonPayload(content);
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
    parsed.verdict = await alignVerdictWithScore(req, parsed, env);
    withVerifiedCalculation(parsed);
    console.log(JSON.stringify({ event: "analyze_ok", verdicts: parsed.verdict.length }));
    return parsed;
  } catch (error) {
    const reason = error instanceof Error ? error.message : "unknown";
    console.log(JSON.stringify({ event: "analyze_fallback", reason }));
    return localFallback;
  }
}
