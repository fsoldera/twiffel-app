/// Exact UI copy for the Twiffel comparison form and results screens.
abstract final class DecisionCopy {
  // Shared
  static const String generateAnalysis = 'Generate analysis';
  static String inputPhaseStepLabel(int stepIndex) =>
      'Step ${stepIndex + 1} of 3';
  static const String nextLabel = 'NEXT';
  static const String previousLabel = 'PREV.';
  static const String otherLabel = 'Other: ___';
  static const String obstacleHelper =
      'Pick the single most important point to weigh.';
  static const String timingAsap = 'Now';
  static const String timingMonths = 'In 1–3 months';
  static const String timingLater = 'Later / Flexible';
  static const String timingDateRange = 'Specific date range';
  static const String timingPickDates = 'Pick date range';
  static const String timingHelper =
      'This helps us calculate the cost of waiting.';
  static const String optionsStepTitle =
      "Let's choose the right option together";
  static const String considerationStepTitle =
      'What is the most important point to consider?';
  static const String timingStepTitle =
      'When do you need to use this decision?';

  static const String pathBFormTitle = "Let's choose the right option together";
  static const String pathBOptionALabel =
      'Option A - What is the first option?';
  static const String pathBOptionAPlaceholder = 'e.g. Buy a new car';
  static const String pathBOptionAHelper = 'Describe the first option clearly.';
  static const String pathBOptionBLabel =
      'Option B - What is the second option?';
  static const String pathBOptionBPlaceholder = 'e.g. Keep the old one';
  static const String pathBOptionBHelper = 'Describe the alternative option.';
  static const String pathBObstacleLabel =
      'What is the most important point to consider?';
  static const String pathBObstacleCost = 'Cost / money';
  static const String pathBObstacleTime = 'Time & practical effort';
  static const String pathBObstacleUncertainty =
      'Uncertainty which option is better';
  static const String pathBObstacleFear =
      'Fear of making the wrong long-term choice';
  static const String pathBTimingLabel =
      'When do you need to use this decision?';

  // Analysis results
  /// Fallback only; wait screen uses LoadingResponseTexts.next().
  static const String analysisLoading = 'Twiffel is thinking...';
  static const String analysisThinking = 'Thinking...';
  static const String analysisStartOver = 'Start over';
  static const String analysisStartNewDecision = 'Start new decision';
  static const String analysisShare = 'Save & Share';
  static const String analysisShareSubject =
      'Something I thought through with Twiffel';
  static const String analysisShareFilenamePrefix = 'Twiffel results';
  static const String analysisShareBody =
      'Twiffel put this together for me. Try it yourself if you want a clearer read on a choice, then share it around, friends and family often see something you missed.';
  static const String analysisShareCopied = 'Results copied to clipboard';
  static const String analysisShareFailed =
      'Could not prepare the PDF report. Please try again.';
  static const String analysisError = 'Something went wrong. Please try again.';
  static const String analysisPros = 'Pros';
  static const String analysisCons = 'Cons';
  static const String analysisVerdictLabel = 'THE VERDICT';
  static const String analysisSummaryTab = 'SUMMARY';
  static const String analysisDetailsTab = 'DETAILS';
  static const String analysisComparisonMode = 'COMPARISON MODE';
  static const String analysisKeyParameters = 'Key parameters analyzed';
  static const String analysisScoreLabel = 'Score';
  static const String analysisLeanTooClose = 'Very close, weigh the nuances';
  static const String analysisLeanNearlyEven = 'The scores are nearly even';
  static const String analysisLeanNet = 'Net';
  static String analysisLeanClearTo(String name) => 'Clear lean to $name';
  static String analysisLeanSlightTo(String name) => 'Slight lean to $name';
  static String analysisLeanPercentToward(int percent, String name) =>
      '$percent% toward $name';
  static const String analysisSeeProsCons = 'See pros & cons';
  static const String analysisQuestionLabel = 'Question';
  static const String analysisOptionALabel = 'Option A';
  static const String analysisOptionBLabel = 'Option B';
  static const String analysisCancel = 'Cancel';
  static const String analysisVsWord = 'VS';
  static const String analysisStartOverTitle = 'Start over?';
  static const String analysisStartOverBody =
      'This discards the current analysis. You can generate a new one anytime.';
  static const String analysisStartOverBodyPdf =
      'You can also save the results as a PDF file and use it later.';
  static const String analysisStartOverConfirm = 'Start over';
  static const String analysisStartOverKeep = 'Keep results';

  // PDF report copy
  static const String reportComparisonSubtitle = 'Option Comparison Report';
  static const String reportProsArguments = 'Pros & Arguments';
  static const String reportConsTradeoffs = 'Cons & Trade-offs';
  static const String reportVerdictComparison = 'Summary Verdict';
  static const String reportLeanSlightToOption = 'Slight lean to option';
  static const String reportLeanClearToOption = 'Clear lean to option';
  static const String reportParametersHeading = 'Key parameters';
  static const String reportConsiderationLabel =
      'Most important point to consider';
  static const String reportTimingLabel = 'Timing';
  static const String reportFavor = 'Favor';
  static const String reportPointWeight = 'Point weight';
  static const String reportProsDetailed = 'Pros: detailed comparison';
  static const String reportConsDetailed = 'Cons: detailed comparison';
  static const String reportDownload =
      "Don't sit with the next choice alone. Try Twiffel free.";
  static const String reportAppStore = 'App Store';
  static const String reportGooglePlay = 'Google Play';
  static const String reportAppStoreUrl = 'https://twiffel.app';
  static const String reportGooglePlayUrl =
      'https://play.google.com/store/apps/details?id=com.uthings.twiffel';
}
