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
    "Exactly five complete sentences that match calculation.lean and cite concrete list points. Each item is one sentence ending with a period.",
  minItems: VERDICTS,
  maxItems: VERDICTS,
  items: {
    type: "string",
    description:
      "One complete verdict sentence ending with a period, using a fact from the lists.",
  },
} as const;

const comparisonCalculationSchema = {
  type: "object",
  additionalProperties: false,
  description:
    "Add the list weights here before writing verdict. Each net must equal that option's pro sum minus con sum.",
  properties: {
    optionAProSum: {
      type: "integer",
      description: "Sum of option A pro weights.",
    },
    optionAConSum: {
      type: "integer",
      description: "Sum of option A con weights.",
    },
    optionANet: {
      type: "integer",
      description: "optionAProSum minus optionAConSum.",
    },
    optionBProSum: {
      type: "integer",
      description: "Sum of option B pro weights.",
    },
    optionBConSum: {
      type: "integer",
      description: "Sum of option B con weights.",
    },
    optionBNet: {
      type: "integer",
      description: "optionBProSum minus optionBConSum.",
    },
    lean: {
      type: "string",
      enum: ["a", "b", "too_close"],
      description:
        "a if option A net is higher, b if option B net is higher, too_close if the nets are close.",
    },
  },
  required: [
    "optionAProSum",
    "optionAConSum",
    "optionANet",
    "optionBProSum",
    "optionBConSum",
    "optionBNet",
    "lean",
  ],
} as const;

const comparisonAnalysisSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    optionAPros: pointsArraySchema("Exactly five pros for option A."),
    optionACons: pointsArraySchema("Exactly five cons for option A."),
    optionBPros: pointsArraySchema("Exactly five pros for option B."),
    optionBCons: pointsArraySchema("Exactly five cons for option B."),
    calculation: comparisonCalculationSchema,
    verdict: verdictSchema,
  },
  required: [
    "optionAPros",
    "optionACons",
    "optionBPros",
    "optionBCons",
    "calculation",
    "verdict",
  ],
} as const;

const verdictOnlySchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    verdict: verdictSchema,
  },
  required: ["verdict"],
} as const;

export function verdictRewriteResponseFormat(): {
  type: "json_schema";
  json_schema: {
    name: string;
    strict: true;
    schema: typeof verdictOnlySchema;
  };
} {
  return {
    type: "json_schema",
    json_schema: {
      name: "twiffel_verdict_rewrite",
      strict: true,
      schema: verdictOnlySchema,
    },
  };
}

/** xAI Chat Completions structured output. Verdict is required, not optional JSON. */
export function analysisResponseFormat(): {
  type: "json_schema";
  json_schema: {
    name: string;
    strict: true;
    schema: typeof comparisonAnalysisSchema;
  };
} {
  return {
    type: "json_schema",
    json_schema: {
      name: "twiffel_comparison_analysis",
      strict: true,
      schema: comparisonAnalysisSchema,
    },
  };
}
