import type { DecisionMode } from "./decision";

/** Keep in sync with ANALYSIS_POINTS_TARGET / VERDICT_SENTENCES_TARGET in decision.ts. */
const POINTS = 5;
const VERDICTS = 5;

const pointSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    title: {
      type: "string",
      description: 'Short numbered label, for example "1. Lower maintenance".',
    },
    detail: {
      type: "string",
      description: "One concrete sentence tied to the user's options and obstacle.",
    },
  },
  required: ["title", "detail"],
} as const;

function pointsArraySchema(description: string) {
  return {
    type: "array",
    description,
    minItems: POINTS,
    maxItems: POINTS,
    items: pointSchema,
  } as const;
}

const verdictSchema = {
  type: "array",
  description:
    "Exactly five complete sentences with a clear lean. Each item is one sentence ending with a period.",
  minItems: VERDICTS,
  maxItems: VERDICTS,
  items: {
    type: "string",
    description: "One complete verdict sentence ending with a period.",
  },
} as const;

const singleAnalysisSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    verdict: verdictSchema,
    pros: pointsArraySchema("Exactly five pros for the decision target."),
    cons: pointsArraySchema("Exactly five cons for the decision target."),
  },
  required: ["verdict", "pros", "cons"],
} as const;

const comparisonAnalysisSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    verdict: verdictSchema,
    optionAPros: pointsArraySchema("Exactly five pros for option A."),
    optionACons: pointsArraySchema("Exactly five cons for option A."),
    optionBPros: pointsArraySchema("Exactly five pros for option B."),
    optionBCons: pointsArraySchema("Exactly five cons for option B."),
  },
  required: ["verdict", "optionAPros", "optionACons", "optionBPros", "optionBCons"],
} as const;

/** xAI Chat Completions structured output. Verdict is required, not optional JSON. */
export function analysisResponseFormat(mode: DecisionMode): {
  type: "json_schema";
  json_schema: {
    name: string;
    strict: true;
    schema: typeof singleAnalysisSchema | typeof comparisonAnalysisSchema;
  };
} {
  if (mode === "single") {
    return {
      type: "json_schema",
      json_schema: {
        name: "twiffel_single_analysis",
        strict: true,
        schema: singleAnalysisSchema,
      },
    };
  }
  return {
    type: "json_schema",
    json_schema: {
      name: "twiffel_comparison_analysis",
      strict: true,
      schema: comparisonAnalysisSchema,
    },
  };
}
