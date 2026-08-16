/// Exact UI copy for the Twiffel decision routing + form screens.
abstract final class DecisionCopy {
  // Screen 1 – Routing
  static const String routingTitle = 'What kind of decision is this?';
  static const String routingSubtitle =
      'Choose the option that best matches your situation.';
  static const String pathATitle =
      'I want to decide whether to do or buy something';
  static const String pathAHelper =
      'Example: buy a new car, move to a new apartment, quit my job, start a diet, get a dog, stop smoking';
  static const String pathBTitle =
      'I want to choose between two options';
  static const String pathBHelper =
      'Example: buy a new car vs keep the old one, move to a new city vs stay, quit my job vs stay';
  static const String continueLabel = 'Continue';

  // Shared
  static const String generateAnalysis = 'Generate analysis';
  static const String nextLabel = 'NEXT';
  static const String previousLabel = 'PREV.';
  static const String otherLabel = 'Other: ___';
  static const String obstacleHelper =
      'Pick the single most important point to weigh.';
  static const String timingAsap = 'Now!';
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

  // Path A – Do or Buy
  static const String pathAFormTitle = 'Tell us about your decision';
  static const String pathAField1Label =
      'What exactly are you considering doing or buying?';
  static const String pathAField1Placeholder =
      'e.g. Buy a new car / Move to a new apartment / Quit my job';
  static const String pathAField1Helper =
      'Write a concrete action. Be as specific as you can.';
  static const String pathAObstacleLabel =
      'What is the main thing holding you back from deciding right now?';
  static const String pathAObstacleCost = 'Cost / money';
  static const String pathAObstacleTime = 'Time & practical effort';
  static const String pathAObstacleUncertainty =
      "Uncertainty if it's the right choice";
  static const String pathAObstacleFear = 'Fear of long-term commitment';
  static const String pathATimingLabel =
      'When would you ideally like this to happen?';

  // Path B – This or That (separate Option A / Option B fields)
  static const String pathBFormTitle =
      "Let's choose the right option together";
  static const String pathBOptionALabel = 'Option A - What is the first option?';
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
  static const String analysisTitleSingle = 'Your Decision Analysis';
  static const String analysisTitleComparison = 'Your Comparison';
  /// Fallback only; wait screen uses LoadingResponseTexts.next().
  static const String analysisLoading = 'Twiffel is thinking...';
  static const String analysisThinking = 'Thinking...';
  static const String analysisStartOver = 'Start over';
  static const String analysisStartNewDecision = 'Start new decision';
  static const String analysisShare = 'Share results';
  static const String analysisShareComparison = 'Share comparison results';
  static const String analysisShareSubjectPrefix = 'Twiffel results';
  static const String analysisShareCopied = 'Results copied to clipboard';
  static const String analysisShareFailed =
      'Could not prepare the PDF report. Please try again.';
  static const String analysisError = 'Something went wrong. Please try again.';
  static const String analysisPros = 'Pros';
  static const String analysisCons = 'Cons';
  static const String analysisVerdictLabel = 'THE VERDICT';
  static const String analysisSummaryTab = 'Summary';
  static const String analysisDetailsTab = 'Detailed Score';
  static const String analysisComparisonMode = 'COMPARISON MODE';
  static const String analysisSingleMode = 'SINGLE MODE';
  static const String analysisKeyParameters = 'Key parameters analyzed';
  static const String analysisScoreLabel = 'Score';
  static const String analysisLeanTooClose = 'Too close, weigh the nuances';
  static const String analysisLeanNearlyEven = 'The scores are nearly even';
  static const String analysisLeanGoAhead = 'go ahead';
  static const String analysisLeanWait = 'wait';
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

  // PDF report copy (aligned with Figma report-single-choice / report-comparison)
  static const String reportSingleSubtitle = 'Decision Analysis Report';
  static const String reportComparisonSubtitle = 'Option Comparison Report';
  static const String reportActiveQuestionLabel = 'Active Analysis Question';
  static const String reportProsArguments = 'Pros & Arguments';
  static const String reportConsTradeoffs = 'Cons & Trade-offs';
  static const String reportVerdictSingle = 'Summary Verdict';
  static const String reportVerdictComparison = 'Summary Verdict';
  static const String reportFavor = 'Favor';
  static const String reportLeanBreakdown = 'Lean breakdown';
  static const String reportProsWeight = 'Pros weight';
  static const String reportConsWeight = 'Cons weight';
  static const String reportPointWeight = 'Point weight';
  static const String reportProsDetailed = 'Pros: detailed comparison';
  static const String reportConsDetailed = 'Cons: detailed comparison';
  static const String reportProsDetailedSingle = 'Pros: detailed score';
  static const String reportConsDetailedSingle = 'Cons: detailed score';
  static const String reportDownload =
      "Don't sit with the next choice alone. Try Twiffel free.";
  static const String reportAppStore = 'App Store';
  static const String reportGooglePlay = 'Google Play';
  static const String reportAppStoreUrl = 'https://twiffel.app';
  static const String reportGooglePlayUrl =
      'https://play.google.com/store/apps/details?id=com.uthings.twiffel';
}
