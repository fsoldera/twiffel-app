import type { DecisionMode } from "./decision";

/** Keep in sync with ANALYSIS_POINTS_TARGET / VERDICT_SENTENCES_TARGET in decision.ts. */
const POINTS = 5;
const VERDICTS = 5;

const pointSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    tagline: {
      type: "string",
      description: "Short label, 2 to 6 common words. No number prefix. No period.",
    },
    description: {
      type: "string",
      description:
        "One short plain sentence ending with a period, tied to the options and the most important point to consider.",
    },
    weight: {
      type: "integer",
      minimum: 1,
      maximum: 100,
      description:
        "How much this point should count in the evaluation, from 1 (weak) to 100 (decisive).",
    },
  },
  required: ["tagline", "description", "weight"],
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
    "Exactly five complete sentences with a clear lean based on the user's most important point to consider. Each item is one sentence ending with a period.",
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
