import 'dart:math' as math;

import '../pages/decision_copy.dart';
import 'decision_models.dart';

/// How far the computed lean sits from a 50/50 split.
enum LeanStrength { tooClose, slight, clear }

/// Client-computed score from stored 1-100 weights. The model never writes this.
class AnalysisScore {
  const AnalysisScore({
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

  final int proSumPrimary;
  final int conSumPrimary;
  final int netPrimary;
  final int proSumSecondary;
  final int conSumSecondary;
  final int netSecondary;

  /// 0-100 toward option A.
  final double leanPercent;
  final LeanStrength strength;

  /// Option A is ahead.
  final bool leansPrimary;
  final String primaryLabel;
  final String secondaryLabel;

  static const double tooCloseMargin = 8;
  static const double slightMargin = 18;

  factory AnalysisScore.fromAnalysis(DecisionAnalysis analysis) {
    final proA = sumWeights(analysis.optionAPros);
    final conA = sumWeights(analysis.optionACons);
    final proB = sumWeights(analysis.optionBPros);
    final conB = sumWeights(analysis.optionBCons);
    final netA = proA - conA;
    final netB = proB - conB;
    final totalWeight = proA + conA + proB + conB;
    // Share 100% by the listed weight mass, then stretch small leans away
    // from 50 so a close call is easier to read. Keep in sync with
    // backend/src/score.ts compressFavorPercent.
    final linear =
        totalWeight == 0 ? 50.0 : 50 + 50 * (netA - netB) / totalWeight;
    final percent = compressFavorPercent(linear.clamp(0, 100));
    return AnalysisScore(
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

  int get leanPercentRounded => leanPercent.round().clamp(0, 100);

  /// Share of favor toward option A. Pair always sums to 100.
  int get primaryFavorPercent => leanPercentRounded;

  /// Share of favor toward option B.
  int get secondaryFavorPercent => 100 - primaryFavorPercent;

  /// Share of total pro weight on option A. Pair always sums to 100.
  int get primaryProsPercent => _sharePercent(proSumPrimary, proSumSecondary);

  int get secondaryProsPercent => 100 - primaryProsPercent;

  /// Share of total con weight on option A. Pair always sums to 100.
  int get primaryConsPercent => _sharePercent(conSumPrimary, conSumSecondary);

  int get secondaryConsPercent => 100 - primaryConsPercent;

  static int _sharePercent(int left, int right) {
    final total = left + right;
    if (total <= 0) return 50;
    return ((left / total) * 100).round().clamp(0, 100);
  }

  /// Marker position from the left, 0-100. Left is option A, right is option B.
  double get trackPercent => (100 - leanPercent).clamp(0, 100);

  int get towardFavoredPercent {
    final towardPrimary = leanPercentRounded;
    return leansPrimary ? towardPrimary : (100 - towardPrimary);
  }

  String get favoredName => leansPrimary ? primaryLabel : secondaryLabel;

  String get trackLeftLabel => primaryLabel;

  String get trackRightLabel => secondaryLabel;

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

/// Stretch small leans away from 50 so a close call is easier to read.
/// k=9 maps a linear 52/48 split to about 57/43. Keep in sync with
/// [compressFavorPercent] in backend/src/score.ts.
const favorLogK = 9.0;

double compressFavorPercent(double linearPercent) {
  final clamped = linearPercent.clamp(0.0, 100.0);
  final signed = (clamped - 50) / 50;
  if (signed == 0) return 50;
  final t = signed.abs();
  final curved = math.log(1 + favorLogK * t) / math.log(1 + favorLogK);
  return (50 + 50 * signed.sign * curved).clamp(0.0, 100.0);
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

/// Inverse of [compressFavorPercent]: pull typical mid-high weights down the
/// 1-5 star scale so 1 and 2 stars show up. Same k as the favor split.
double compressWeightForStars(int weight) {
  final t = weight.clamp(1, 100) / 100.0;
  final curved = (math.pow(1 + favorLogK, t) - 1) / favorLogK;
  return (curved * 100).clamp(0.0, 100.0);
}

/// One mark per 20 display points after the log remap, 1 to 5.
int weightSignCount(int weight) {
  final display = compressWeightForStars(weight).round().clamp(1, 100);
  return ((display + 19) ~/ 20).clamp(1, 5);
}

String weightSignLabel(int weight, {required bool favorable}) {
  final mark = favorable ? '+' : '-';
  return List.filled(weightSignCount(weight), mark).join();
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
    if (_claimsOptionLetter(sentence, optionA: !score.leansPrimary)) {
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
