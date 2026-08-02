import { DECISION_ANALYSIS_SYSTEM_PROMPT } from "./prompts";
import { isSafeCompassionateMessage } from "./tone";
import { callXaiChat, type Env } from "./ai";

export type DecisionMode = "single" | "comparison";

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

function cleanPoints(raw: unknown, min = 3): AnalysisPoint[] {
  if (!Array.isArray(raw)) return [];
  const points = raw.map(cleanPoint).filter((p): p is AnalysisPoint => p != null);
  return points.slice(0, Math.max(min, 3));
}

function fallbackSingle(req: DecisionRequest): DecisionAnalysis {
  const target = (req.target || "this decision").trim();
  return {
    mode: "single",
    target,
    pros: [
      {
        title: "1. Clearer direction",
        detail: `Naming "${target}" makes the choice concrete enough to evaluate honestly.`,
      },
      {
        title: "2. Timeline awareness",
        detail: `Wanting this ${req.timing.toLowerCase()} helps you weigh urgency against waiting costs.`,
      },
      {
        title: "3. Obstacle is named",
        detail: `Focusing on "${req.obstacle}" keeps the analysis practical instead of vague worry.`,
      },
    ],
    cons: [
      {
        title: "1. Real trade-offs remain",
        detail: `Moving ahead on "${target}" still means accepting costs, effort, or uncertainty.`,
      },
      {
        title: "2. Waiting has a cost too",
        detail: "Delaying can feel safer, but it may quietly spend time, energy, or opportunity.",
      },
      {
        title: "3. Ambiguity can return",
        detail: "Without a next checkpoint, the same doubts are likely to resurface.",
      },
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
      {
        title: "1. Forward movement",
        detail: `"${optionA}" is the more change-oriented path if you want momentum.`,
      },
      {
        title: "2. Matches stated desire",
        detail: "It may better reflect what you already feel drawn toward.",
      },
      {
        title: "3. Forces clarity",
        detail: "Choosing it creates a concrete plan you can test against reality.",
      },
    ],
    optionACons: [
      {
        title: "1. Higher friction",
        detail: `Obstacle "${req.obstacle}" may hit this option harder at first.`,
      },
      {
        title: "2. Commitment pressure",
        detail: "It can feel harder to reverse if the early weeks are rocky.",
      },
      {
        title: "3. Upfront cost",
        detail: "Time, money, or effort may spike before benefits appear.",
      },
    ],
    optionBPros: [
      {
        title: "1. Continuity",
        detail: `"${optionB}" preserves stability while you gather more information.`,
      },
      {
        title: "2. Lower immediate stress",
        detail: "It may reduce short-term pressure around your main obstacle.",
      },
      {
        title: "3. Room to prepare",
        detail: "You can strengthen finances, timing, or confidence before a bigger move.",
      },
    ],
    optionBCons: [
      {
        title: "1. Delayed progress",
        detail: "Staying put can quietly extend the indecision window.",
      },
      {
        title: "2. Opportunity cost",
        detail: `If timing is "${req.timing}", waiting may conflict with your preferred window.`,
      },
      {
        title: "3. Habit lock-in",
        detail: "The status quo can become harder to leave the longer it continues.",
      },
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
      if (pros.length < 3 || cons.length < 3) return null;
      return {
        mode: "single",
        target: req.target?.trim(),
        pros: pros.slice(0, 3),
        cons: cons.slice(0, 3),
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
      optionAPros.length < 3 ||
      optionACons.length < 3 ||
      optionBPros.length < 3 ||
      optionBCons.length < 3
    ) {
      return null;
    }
    return {
      mode: "comparison",
      optionA: req.optionA?.trim(),
      optionB: req.optionB?.trim(),
      pros: [],
      cons: [],
      optionAPros: optionAPros.slice(0, 3),
      optionACons: optionACons.slice(0, 3),
      optionBPros: optionBPros.slice(0, 3),
      optionBCons: optionBCons.slice(0, 3),
      verdict,
    };
  } catch {
    return null;
  }
}

function buildUserPrompt(req: DecisionRequest): string {
  if (req.mode === "single") {
    return [
      `Mode: single (do or buy)`,
      `Decision target: "${req.target?.trim()}"`,
      `Main obstacle: "${req.obstacle.trim()}"`,
      `Preferred timing: "${req.timing.trim()}"`,
      "Return JSON with keys: pros (array of 3 {title, detail}), cons (array of 3 {title, detail}), verdict (string).",
      "Titles should be short numbered labels like \"1. Safety upgrade\".",
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
    "Return JSON with keys: optionAPros, optionACons, optionBPros, optionBCons (each an array of 3 {title, detail}), verdict (string).",
    "Titles should be short numbered labels like \"1. Lower maintenance\".",
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
