import { DECISION_ANALYSIS_SYSTEM_PROMPT } from "./prompts";
import { isSafeCompassionateMessage } from "./tone";
import { callXaiChat, type Env } from "./ai";

export type DecisionMode = "single" | "comparison";

/** How many pros/cons (or per-option points) we ask the model for and keep. */
export const ANALYSIS_POINTS_TARGET = 7;
/** Soft minimum before we discard a model response and use local fallback. */
export const ANALYSIS_POINTS_MIN = 5;

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
  verdict: string;
}

function cleanPoint(raw: unknown): AnalysisPoint | null {
  if (!raw || typeof raw !== "object") return null;
  const obj = raw as { title?: unknown; detail?: unknown };
  const title = typeof obj.title === "string" ? obj.title.trim() : "";
  const detail = typeof obj.detail === "string" ? obj.detail.trim() : "";
  if (!title || !detail) return null;
  if (title.length > 80 || detail.length > 220) return null;
  return { title, detail };
}

function cleanPoints(raw: unknown, max = ANALYSIS_POINTS_TARGET): AnalysisPoint[] {
  if (!Array.isArray(raw)) return [];
  const points = raw.map(cleanPoint).filter((p): p is AnalysisPoint => p != null);
  return points.slice(0, max);
}

function point(title: string, detail: string): AnalysisPoint {
  return { title, detail };
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
      point("6. Trade-offs get specific", "Pros and cons stop being abstract once the action and timing are named."),
      point("7. Agency stays with you", "The analysis supports your judgment rather than replacing it."),
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
      point("6. Emotional load", "Replaying the choice can drain focus that could go to a small experiment."),
      point("7. Status quo drift", "Doing nothing is still a choice, and it may quietly lock in by default."),
    ],
    optionAPros: [],
    optionACons: [],
    optionBPros: [],
    optionBCons: [],
    verdict:
      `Based on your timing (${req.timing}) and main obstacle (${req.obstacle}), ` +
      `"${target}" looks worth a careful next step, not a rushed leap.`,
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
      point("6. Aligns with timing", `If you need to decide ${req.timing.toLowerCase()}, this path can create movement.`),
      point("7. Identity signal", "It can express the kind of person or life you are trying to grow into."),
    ],
    optionACons: [
      point("1. Higher friction", `Obstacle "${req.obstacle}" may hit this option harder at first.`),
      point("2. Commitment pressure", "It can feel harder to reverse if the early weeks are rocky."),
      point("3. Upfront cost", "Time, money, or effort may spike before benefits appear."),
      point("4. Transition stress", "Changing lanes often adds temporary chaos even when the destination is good."),
      point("5. Over-optimism risk", "Excitement can underweight practical blockers you already named."),
      point("6. Social ripple", "People around you may need time to adjust to the change."),
      point("7. Recovery cost if wrong", "If it misfits, unwinding the choice may take extra energy."),
    ],
    optionBPros: [
      point("1. Continuity", `"${optionB}" preserves stability while you gather more information.`),
      point("2. Lower immediate stress", "It may reduce short-term pressure around your main obstacle."),
      point("3. Room to prepare", "You can strengthen finances, timing, or confidence before a bigger move."),
      point("4. Familiar systems", "Existing routines and tools already support this path."),
      point("5. Reversible by default", "Staying closer to the status quo usually keeps more exit options open."),
      point("6. Cognitive ease", "Less novelty means more bandwidth for other parts of life."),
      point("7. Steady baseline", "It can be a sane holding pattern while you watch for a clearer signal."),
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
      point("6. Motivation fade", "Without a new experiment, energy for the decision can drain away."),
      point("7. False calm", "Short-term relief can mask a mismatch that keeps resurfacing."),
    ],
    verdict:
      `Given obstacle "${req.obstacle}" and timing "${req.timing}", compare whether ` +
      `"${optionA}" unlocks enough upside to justify the friction versus staying with "${optionB}".`,
  };
}

function parseAnalysisJson(content: string, req: DecisionRequest): DecisionAnalysis | null {
  const trimmed = content.trim().replace(/^```json\s*/i, "").replace(/```$/i, "").trim();
  try {
    const parsed = JSON.parse(trimmed) as Record<string, unknown>;
    const verdict = typeof parsed.verdict === "string" ? parsed.verdict.trim() : "";
    if (!verdict) return null;

    if (req.mode === "single") {
      const pros = cleanPoints(parsed.pros);
      const cons = cleanPoints(parsed.cons);
      if (pros.length < ANALYSIS_POINTS_MIN || cons.length < ANALYSIS_POINTS_MIN) return null;
      return {
        mode: "single",
        target: req.target?.trim(),
        pros,
        cons,
        optionAPros: [],
        optionACons: [],
        optionBPros: [],
        optionBCons: [],
        verdict,
      };
    }

    const optionAPros = cleanPoints(parsed.optionAPros);
    const optionACons = cleanPoints(parsed.optionACons);
    const optionBPros = cleanPoints(parsed.optionBPros);
    const optionBCons = cleanPoints(parsed.optionBCons);
    if (
      optionAPros.length < ANALYSIS_POINTS_MIN ||
      optionACons.length < ANALYSIS_POINTS_MIN ||
      optionBPros.length < ANALYSIS_POINTS_MIN ||
      optionBCons.length < ANALYSIS_POINTS_MIN
    ) {
      return null;
    }
    return {
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
      `Return JSON with keys: pros (array of exactly ${n} {title, detail}), cons (array of exactly ${n} {title, detail}), verdict (string).`,
      'Titles should be short numbered labels like "1. Safety upgrade".',
      "Details must reference this specific decision, obstacle, and timing.",
      "Verdict: 1-3 calm sentences with a lean (positive / cautious / wait), no shame.",
    ].join("\n");
  }
  return [
    `Mode: comparison (this or that)`,
    `Option A: "${req.optionA?.trim()}"`,
    `Option B: "${req.optionB?.trim()}"`,
    `Main obstacle: "${req.obstacle.trim()}"`,
    `Preferred timing: "${req.timing.trim()}"`,
    `Return JSON with keys: optionAPros, optionACons, optionBPros, optionBCons (each an array of exactly ${n} {title, detail}), verdict (string).`,
    'Titles should be short numbered labels like "1. Lower maintenance".',
    "Details must reference these specific options, obstacle, and timing.",
    "Verdict: 1-3 calm sentences saying which option has a slight edge and why, or when waiting is wiser.",
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
    );
    const parsed = parseAnalysisJson(content, req);
    if (!parsed) return localFallback;
    const context = req.target || `${req.optionA} vs ${req.optionB}` || "decision";
    if (!isSafeCompassionateMessage(parsed.verdict, context, { requireTaskMention: false })) {
      parsed.verdict = localFallback.verdict;
    }
    return parsed;
  } catch {
    return localFallback;
  }
}
