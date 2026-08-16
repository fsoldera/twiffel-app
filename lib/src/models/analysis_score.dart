import '../pages/decision_copy.dart';
import 'decision_models.dart';

/// How far the computed lean sits from a 50/50 split.
enum LeanStrength { tooClose, slight, clear }

/// Client-computed score from stored 1-100 weights. The model never writes this.
class AnalysisScore {
  const AnalysisScore({
    required this.isComparison,
    required this.proSumPrimary,
    required this.conSumPrimary,
    required this.netPrimary,
    required this.proSumSecondary,
    required this.conSumSecondary,
    required this.netSecondary,
    required this.leanPercent,
    required this.strength,
    required this.leansPrimary,
    required this.primaryLabel,
    required this.secondaryLabel,
  });

  final bool isComparison;
  final int proSumPrimary;
  final int conSumPrimary;
  final int netPrimary;
  final int proSumSecondary;
  final int conSumSecondary;
  final int netSecondary;

  /// 0-100. Comparison: toward option A. Single: toward go ahead.
  final double leanPercent;
  final LeanStrength strength;

  /// Comparison: option A is ahead. Single: net is not negative.
  final bool leansPrimary;
  final String primaryLabel;
  final String secondaryLabel;

  static const double tooCloseMargin = 8;
  static const double slightMargin = 18;

  factory AnalysisScore.fromAnalysis(DecisionAnalysis analysis) {
    if (analysis.mode == DecisionMode.comparison) {
      final proA = sumWeights(analysis.optionAPros);
      final conA = sumWeights(analysis.optionACons);
      final proB = sumWeights(analysis.optionBPros);
      final conB = sumWeights(analysis.optionBCons);
      final netA = proA - conA;
      final netB = proB - conB;
      final denom = netA.abs() + netB.abs();
      final percent = denom == 0 ? 50.0 : 50 + 50 * (netA - netB) / denom;
      return AnalysisScore(
        isComparison: true,
        proSumPrimary: proA,
        conSumPrimary: conA,
        netPrimary: netA,
        proSumSecondary: proB,
        conSumSecondary: conB,
        netSecondary: netB,
        leanPercent: percent.clamp(0, 100),
        strength: strengthFor(percent),
        leansPrimary: netA >= netB,
        primaryLabel: _optionName(
          analysis.optionA,
          DecisionCopy.analysisOptionALabel,
        ),
        secondaryLabel: _optionName(
          analysis.optionB,
          DecisionCopy.analysisOptionBLabel,
        ),
      );
    }

    final proSum = sumWeights(analysis.pros);
    final conSum = sumWeights(analysis.cons);
    final net = proSum - conSum;
    final denom = proSum + conSum;
    final percent = denom == 0 ? 50.0 : 50 + 50 * net / denom;
    return AnalysisScore(
      isComparison: false,
      proSumPrimary: proSum,
      conSumPrimary: conSum,
      netPrimary: net,
      proSumSecondary: 0,
      conSumSecondary: 0,
      netSecondary: 0,
      leanPercent: percent.clamp(0, 100),
      strength: strengthFor(percent),
      leansPrimary: net >= 0,
      primaryLabel: DecisionCopy.analysisLeanGoAhead,
      secondaryLabel: DecisionCopy.analysisLeanWait,
    );
  }

  int get leanPercentRounded => leanPercent.round().clamp(0, 100);

  /// Share of favor toward option A / go ahead. Pair always sums to 100.
  int get primaryFavorPercent => leanPercentRounded;

  /// Share of favor toward option B / wait.
  int get secondaryFavorPercent => 100 - primaryFavorPercent;

  /// Marker position from the left, 0-100.
  /// Comparison: left is option A, right is option B.
  /// Single: left is wait, right is go ahead.
  double get trackPercent {
    if (isComparison) return (100 - leanPercent).clamp(0, 100);
    return leanPercent;
  }

  int get towardFavoredPercent {
    final towardPrimary = leanPercentRounded;
    return leansPrimary ? towardPrimary : (100 - towardPrimary);
  }

  String get favoredName => leansPrimary ? primaryLabel : secondaryLabel;

  String get trackLeftLabel =>
      isComparison ? primaryLabel : DecisionCopy.analysisLeanWait;

  String get trackRightLabel =>
      isComparison ? secondaryLabel : DecisionCopy.analysisLeanGoAhead;

  String get headline {
    if (strength == LeanStrength.tooClose) {
      return DecisionCopy.analysisLeanTooClose;
    }
    return strength == LeanStrength.clear
        ? DecisionCopy.analysisLeanClearTo(favoredName)
        : DecisionCopy.analysisLeanSlightTo(favoredName);
  }

  String get towardCaption {
    if (strength == LeanStrength.tooClose) {
      return DecisionCopy.analysisLeanNearlyEven;
    }
    return DecisionCopy.analysisLeanPercentToward(
      towardFavoredPercent,
      favoredName,
    );
  }

  static LeanStrength strengthFor(double percent) {
    final margin = (percent - 50).abs();
    if (margin < tooCloseMargin) return LeanStrength.tooClose;
    if (margin < slightMargin) return LeanStrength.slight;
    return LeanStrength.clear;
  }
}

int sumWeights(List<AnalysisPoint> points) {
  var total = 0;
  for (final point in points) {
    total += point.weight;
  }
  return total;
}

int netScore(List<AnalysisPoint> pros, List<AnalysisPoint> cons) {
  return sumWeights(pros) - sumWeights(cons);
}

String formatSigned(int value) {
  if (value > 0) return '+$value';
  return '$value';
}

String formatLeanPercent(int percent) => '$percent%';

String signedWeightLabel(int weight, {required bool favorable}) {
  return favorable ? '+$weight' : '-$weight';
}

String _optionName(String? raw, String fallback) {
  final trimmed = raw?.trim() ?? '';
  return trimmed.isEmpty ? fallback : trimmed;
}

const _winCues = <String>[
  'edge',
  'advantage',
  'better',
  'tips the balance',
  'fit the main',
  'fits the main',
  'more closely',
  'smoother',
  'lean to',
  'lean toward',
  'more sure',
  'ahead',
  'winner',
  'go with',
  'pick ',
  'choose ',
];

final _nameStopWords = <String>{
  'the',
  'and',
  'for',
  'with',
  'from',
  'into',
  'your',
  'this',
  'that',
  'holidays',
  'holiday',
  'buy',
  'keep',
};

/// Distinctive tokens so "Liguria" matches "Holidays in Liguria".
Set<String> distinctiveNameTokens(String name, String otherName) {
  final self = _nameTokens(name);
  final other = _nameTokens(otherName);
  final unique = self.difference(other);
  return unique.isEmpty ? self : unique;
}

Set<String> _nameTokens(String name) {
  return name
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((token) => token.length > 2 && !_nameStopWords.contains(token))
      .toSet();
}

bool _textRefersTo(String text, String name, String otherName) {
  final lower = text.toLowerCase();
  final full = name.toLowerCase();
  if (full.isNotEmpty && lower.contains(full)) return true;
  for (final token in distinctiveNameTokens(name, otherName)) {
    if (RegExp('\\b${RegExp.escape(token)}\\b').hasMatch(lower)) return true;
  }
  return false;
}

bool _hasWinCue(String text) {
  final lower = text.toLowerCase();
  return _winCues.any(lower.contains);
}

bool _claimsWin(String text, String name, String otherName) {
  if (!_textRefersTo(text, name, otherName)) return false;
  return _hasWinCue(text);
}

bool _claimsOptionLetter(String text, {required bool optionA}) {
  final lower = text.toLowerCase();
  final letter = optionA ? 'option a' : 'option b';
  return lower.contains(letter) && _hasWinCue(lower);
}

/// True when the model sentences pick the same side as the computed score.
bool verdictAgreesWithScore(List<String> verdictPoints, AnalysisScore score) {
  if (verdictPoints.isEmpty) return true;
  if (score.strength == LeanStrength.tooClose) return true;

  final winner = score.favoredName;
  final loser = score.leansPrimary ? score.secondaryLabel : score.primaryLabel;

  for (final sentence in verdictPoints) {
    if (_claimsWin(sentence, loser, winner)) return false;
    if (score.isComparison &&
        _claimsOptionLetter(sentence, optionA: !score.leansPrimary)) {
      return false;
    }
  }
  return true;
}

List<String> fallbackVerdictPoints(
  DecisionAnalysis analysis,
  AnalysisScore score,
) {
  if (score.strength == LeanStrength.tooClose) {
    return <String>[
      '${score.headline}.',
      'The listed weights land almost even.',
      'Open Details to see which points carry the most weight.',
      'Use those points to see what still feels unresolved.',
      'If a key fact is still missing, resubmit with more details.',
    ];
  }

  if (!score.isComparison) {
    final side = score.leansPrimary ? analysis.pros : analysis.cons;
    final reason = side.isEmpty
        ? 'The listed weights point that way once they are added up.'
        : 'The strongest listed point is ${side.first.tagline}.';
    return <String>[
      '${score.headline}.',
      'Pros add up to ${formatSigned(score.proSumPrimary)}, cons to ${formatSigned(-score.conSumPrimary)}.',
      'That leaves a net of ${formatSigned(score.netPrimary)}.',
      reason,
      'Open Details to see every weighted point.',
    ];
  }

  final winnerPros =
      score.leansPrimary ? analysis.optionAPros : analysis.optionBPros;
  final loserCons =
      score.leansPrimary ? analysis.optionBCons : analysis.optionACons;
  final winnerReason = winnerPros.isEmpty
      ? 'Its listed weights add up higher than ${score.leansPrimary ? score.secondaryLabel : score.primaryLabel}.'
      : 'The strongest listed point for ${score.favoredName} is ${winnerPros.first.tagline}.';
  final loserReason = loserCons.isEmpty
      ? '${score.leansPrimary ? score.secondaryLabel : score.primaryLabel} scores lower once pros and cons are added up.'
      : 'The heaviest listed concern for ${score.leansPrimary ? score.secondaryLabel : score.primaryLabel} is ${loserCons.first.tagline}.';

  return <String>[
    '${score.headline}.',
    'Its net is ${formatSigned(score.leansPrimary ? score.netPrimary : score.netSecondary)}, against ${formatSigned(score.leansPrimary ? score.netSecondary : score.netPrimary)} for ${score.leansPrimary ? score.secondaryLabel : score.primaryLabel}.',
    winnerReason,
    loserReason,
    'Open Details to see every weighted point.',
  ];
}

/// Verdict bullets that are allowed to appear under the score card.
List<String> alignedVerdictPoints(DecisionAnalysis analysis) {
  final score = AnalysisScore.fromAnalysis(analysis);
  if (verdictAgreesWithScore(analysis.verdictPoints, score)) {
    return analysis.verdictPoints;
  }
  return fallbackVerdictPoints(analysis, score);
}
