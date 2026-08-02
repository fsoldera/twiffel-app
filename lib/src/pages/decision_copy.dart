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
  static const String otherLabel = 'Other: ___';
  static const String obstacleHelper = 'Choose the biggest obstacle.';
  static const String timingAsap = 'As soon as possible';
  static const String timingMonths = 'In 1–3 months';
  static const String timingLater = 'Later / Flexible';
  static const String timingHelper =
      'This helps us calculate the cost of waiting.';

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
  static const String pathBFormTitle = 'Tell us about your options';
  static const String pathBOptionALabel = 'Option A - What is the first option?';
  static const String pathBOptionAPlaceholder = 'e.g. Buy a new car';
  static const String pathBOptionAHelper = 'Describe the first option clearly.';
  static const String pathBOptionBLabel =
      'Option B - What is the second option?';
  static const String pathBOptionBPlaceholder = 'e.g. Keep the old one';
  static const String pathBOptionBHelper = 'Describe the alternative option.';
  static const String pathBObstacleLabel =
      'What is the main thing holding you back from deciding right now?';
  static const String pathBObstacleCost = 'Cost / money';
  static const String pathBObstacleTime = 'Time & practical effort';
  static const String pathBObstacleUncertainty =
      'Uncertainty which option is better';
  static const String pathBObstacleFear =
      'Fear of making the wrong long-term choice';
  static const String pathBTimingLabel = 'When do you need to decide?';

  // Analysis results
  static const String analysisTitleSingle = 'Your Decision Analysis';
  static const String analysisTitleComparison = 'Your Comparison';
  /// Fallback only; wait screen uses LoadingResponseTexts.next().
  static const String analysisLoading = 'Twiffel is thinking...';
  static const String analysisStartOver = 'Start over';
  static const String analysisShare = 'Share results';
  static const String analysisShareCopied = 'Results copied to clipboard';
  static const String analysisError = 'Something went wrong. Please try again.';
  static const String analysisPros = 'Pros';
  static const String analysisCons = 'Cons';
  static const String analysisSwipeHint = 'Swipe to switch';
  static const String analysisVerdictLabel = 'AI Summary Verdict';
  static const String analysisTargetLabel = 'Target';
  static const String analysisOptionALabel = 'Option A';
  static const String analysisOptionBLabel = 'Option B';
}
