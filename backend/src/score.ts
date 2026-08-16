import type { AnalysisPoint, DecisionAnalysis } from "./decision";

export type LeanStrength = "tooClose" | "slight" | "clear";

export interface AnalysisScore {
  isComparison: boolean;
  proSumPrimary: number;
  conSumPrimary: number;
  netPrimary: number;
  proSumSecondary: number;
  conSumSecondary: number;
  netSecondary: number;
  leanPercent: number;
  strength: LeanStrength;
  leansPrimary: boolean;
  primaryLabel: string;
  secondaryLabel: string;
  favoredName: string;
  headline: string;
}

const TOO_CLOSE_MARGIN = 8;
const SLIGHT_MARGIN = 18;

const WIN_CUES = [
  "edge",
  "advantage",
  "better",
  "tips the balance",
  "fit the main",
  "fits the main",
  "more closely",
  "smoother",
  "lean to",
  "lean toward",
  "more sure",
  "ahead",
  "winner",
  "go with",
  "pick ",
  "choose ",
];

const NAME_STOP_WORDS = new Set([
  "the",
  "and",
  "for",
  "with",
  "from",
  "into",
  "your",
  "this",
  "that",
  "holidays",
  "holiday",
  "buy",
  "keep",
]);

function sumWeights(points: AnalysisPoint[]): number {
  return points.reduce((total, point) => total + point.weight, 0);
}

function optionName(raw: string | undefined, fallback: string): string {
  const trimmed = raw?.trim() ?? "";
  return trimmed.length > 0 ? trimmed : fallback;
}

function strengthFor(percent: number): LeanStrength {
  const margin = Math.abs(percent - 50);
  if (margin < TOO_CLOSE_MARGIN) return "tooClose";
  if (margin < SLIGHT_MARGIN) return "slight";
  return "clear";
}

function formatSigned(value: number): string {
  return value > 0 ? `+${value}` : `${value}`;
}

function headlineFor(score: Omit<AnalysisScore, "headline" | "favoredName">): string {
  const favored = score.leansPrimary ? score.primaryLabel : score.secondaryLabel;
  if (score.strength === "tooClose") return "Too close, weigh the nuances";
  if (score.strength === "clear") return `Clear lean to ${favored}`;
  return `Slight lean to ${favored}`;
}

export function computeScore(analysis: DecisionAnalysis): AnalysisScore {
  if (analysis.mode === "comparison") {
    const proA = sumWeights(analysis.optionAPros);
    const conA = sumWeights(analysis.optionACons);
    const proB = sumWeights(analysis.optionBPros);
    const conB = sumWeights(analysis.optionBCons);
    const netA = proA - conA;
    const netB = proB - conB;
    const denom = Math.abs(netA) + Math.abs(netB);
    const percent = denom === 0 ? 50 : 50 + (50 * (netA - netB)) / denom;
    const clamped = Math.min(100, Math.max(0, percent));
    const base = {
      isComparison: true,
      proSumPrimary: proA,
      conSumPrimary: conA,
      netPrimary: netA,
      proSumSecondary: proB,
      conSumSecondary: conB,
      netSecondary: netB,
      leanPercent: clamped,
      strength: strengthFor(clamped),
      leansPrimary: netA >= netB,
      primaryLabel: optionName(analysis.optionA, "Option A"),
      secondaryLabel: optionName(analysis.optionB, "Option B"),
    };
    const favoredName = base.leansPrimary ? base.primaryLabel : base.secondaryLabel;
    return { ...base, favoredName, headline: headlineFor(base) };
  }

  const proSum = sumWeights(analysis.pros);
  const conSum = sumWeights(analysis.cons);
  const net = proSum - conSum;
  const denom = proSum + conSum;
  const percent = denom === 0 ? 50 : 50 + (50 * net) / denom;
  const clamped = Math.min(100, Math.max(0, percent));
  const base = {
    isComparison: false,
    proSumPrimary: proSum,
    conSumPrimary: conSum,
    netPrimary: net,
    proSumSecondary: 0,
    conSumSecondary: 0,
    netSecondary: 0,
    leanPercent: clamped,
    strength: strengthFor(clamped),
    leansPrimary: net >= 0,
    primaryLabel: "go ahead",
    secondaryLabel: "wait",
  };
  const favoredName = base.leansPrimary ? base.primaryLabel : base.secondaryLabel;
  return { ...base, favoredName, headline: headlineFor(base) };
}

function nameTokens(name: string): Set<string> {
  return new Set(
    name
      .toLowerCase()
      .split(/[^a-z0-9]+/)
      .filter((token) => token.length > 2 && !NAME_STOP_WORDS.has(token)),
  );
}

function distinctiveTokens(name: string, otherName: string): Set<string> {
  const self = nameTokens(name);
  const other = nameTokens(otherName);
  const unique = new Set([...self].filter((token) => !other.has(token)));
  return unique.size > 0 ? unique : self;
}

function textRefersTo(text: string, name: string, otherName: string): boolean {
  const lower = text.toLowerCase();
  if (name && lower.includes(name.toLowerCase())) return true;
  for (const token of distinctiveTokens(name, otherName)) {
    if (new RegExp(`\\b${token.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\b`).test(lower)) {
      return true;
    }
  }
  return false;
}

function hasWinCue(text: string): boolean {
  const lower = text.toLowerCase();
  return WIN_CUES.some((cue) => lower.includes(cue));
}

function claimsWin(text: string, name: string, otherName: string): boolean {
  return textRefersTo(text, name, otherName) && hasWinCue(text);
}

function claimsOptionLetter(text: string, optionA: boolean): boolean {
  const letter = optionA ? "option a" : "option b";
  return text.toLowerCase().includes(letter) && hasWinCue(text);
}

export function verdictAgreesWithScore(verdict: string[], score: AnalysisScore): boolean {
  if (verdict.length === 0) return true;
  if (score.strength === "tooClose") return true;
  const loser = score.leansPrimary ? score.secondaryLabel : score.primaryLabel;
  for (const sentence of verdict) {
    if (claimsWin(sentence, loser, score.favoredName)) return false;
    if (score.isComparison && claimsOptionLetter(sentence, !score.leansPrimary)) return false;
  }
  return true;
}

export function fallbackVerdictPoints(analysis: DecisionAnalysis, score: AnalysisScore): string[] {
  if (score.strength === "tooClose") {
    return [
      `${score.headline}.`,
      "The listed weights land almost even.",
      "The details show which points carry the most weight.",
      "Use those points to see what still feels unresolved.",
      "If a key fact is still missing, resubmit with more details.",
    ];
  }

  if (!score.isComparison) {
    const side = score.leansPrimary ? analysis.pros : analysis.cons;
    const reason =
      side.length === 0
        ? "The listed weights point that way once they are added up."
        : `The strongest listed point is ${side[0].tagline}.`;
    return [
      `${score.headline}.`,
      `Pros add up to ${formatSigned(score.proSumPrimary)}, cons to ${formatSigned(-score.conSumPrimary)}.`,
      `That leaves a net of ${formatSigned(score.netPrimary)}.`,
      reason,
      "The details show every weighted point.",
    ];
  }

  const winnerPros = score.leansPrimary ? analysis.optionAPros : analysis.optionBPros;
  const loserCons = score.leansPrimary ? analysis.optionBCons : analysis.optionACons;
  const loserName = score.leansPrimary ? score.secondaryLabel : score.primaryLabel;
  const winnerNet = score.leansPrimary ? score.netPrimary : score.netSecondary;
  const loserNet = score.leansPrimary ? score.netSecondary : score.netPrimary;
  const winnerReason =
    winnerPros.length === 0
      ? `Its listed weights add up higher than ${loserName}.`
      : `The strongest listed point for ${score.favoredName} is ${winnerPros[0].tagline}.`;
  const loserReason =
    loserCons.length === 0
      ? `${loserName} scores lower once pros and cons are added up.`
      : `The heaviest listed concern for ${loserName} is ${loserCons[0].tagline}.`;

  return [
    `${score.headline}.`,
    `Its net is ${formatSigned(winnerNet)}, against ${formatSigned(loserNet)} for ${loserName}.`,
    winnerReason,
    loserReason,
    "The details show every weighted point.",
  ];
}

export function verifiedCalculation(score: AnalysisScore): Record<string, unknown> {
  if (score.isComparison) {
    return {
      optionAProSum: score.proSumPrimary,
      optionAConSum: score.conSumPrimary,
      optionANet: score.netPrimary,
      optionBProSum: score.proSumSecondary,
      optionBConSum: score.conSumSecondary,
      optionBNet: score.netSecondary,
      lean:
        score.strength === "tooClose" ? "too_close" : score.leansPrimary ? "a" : "b",
      headline: score.headline,
    };
  }
  return {
    proSum: score.proSumPrimary,
    conSum: score.conSumPrimary,
    net: score.netPrimary,
    lean:
      score.strength === "tooClose" ? "too_close" : score.leansPrimary ? "go" : "wait",
    headline: score.headline,
  };
}

export function scoreSummaryLines(score: AnalysisScore): string[] {
  if (score.isComparison) {
    return [
      `${score.primaryLabel} net: ${formatSigned(score.netPrimary)}`,
      `${score.secondaryLabel} net: ${formatSigned(score.netSecondary)}`,
      `Required lean: ${score.headline}`,
    ];
  }
  return [
    `Pros sum: ${formatSigned(score.proSumPrimary)}`,
    `Cons sum: ${formatSigned(-score.conSumPrimary)}`,
    `Net: ${formatSigned(score.netPrimary)}`,
    `Required lean: ${score.headline}`,
  ];
}
