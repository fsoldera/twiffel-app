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
    "Exactly five complete sentences that match calculation.lean and cite concrete list points. Each item is one sentence ending with a period.",
  minItems: VERDICTS,
  maxItems: VERDICTS,
  items: {
    type: "string",
    description:
      "One complete verdict sentence ending with a period, using a fact from the lists.",
  },
} as const;

const singleCalculationSchema = {
  type: "object",
  additionalProperties: false,
  description:
    "Add the list weights here before writing verdict. net must equal proSum minus conSum.",
  properties: {
    proSum: {
      type: "integer",
      description: "Sum of all pro weights.",
    },
    conSum: {
      type: "integer",
      description: "Sum of all con weights.",
    },
    net: {
      type: "integer",
      description: "proSum minus conSum.",
    },
    lean: {
      type: "string",
      enum: ["go", "wait", "too_close"],
      description:
        "go if net is clearly positive, wait if net is clearly negative, too_close if the gap is small.",
    },
  },
  required: ["proSum", "conSum", "net", "lean"],
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

const singleAnalysisSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    pros: pointsArraySchema("Exactly five pros for the decision target."),
    cons: pointsArraySchema("Exactly five cons for the decision target."),
    calculation: singleCalculationSchema,
    verdict: verdictSchema,
  },
  required: ["pros", "cons", "calculation", "verdict"],
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
