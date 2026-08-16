import 'package:flutter_test/flutter_test.dart';

import 'package:twiffel_app/src/models/analysis_score.dart';
import 'package:twiffel_app/src/models/decision_models.dart';
import 'package:twiffel_app/src/pages/decision_copy.dart';

AnalysisPoint _point(int weight) {
  return AnalysisPoint(
    tagline: 'Point $weight',
    description: 'Detail $weight.',
    weight: weight,
  );
}

void main() {
  test('single net is pros minus cons, with a clear go-ahead lean', () {
    final score = AnalysisScore.fromAnalysis(
      DecisionAnalysis(
        mode: DecisionMode.single,
        target: 'Buy it?',
        pros: [_point(90), _point(80), _point(70)],
        cons: [_point(20), _point(10)],
        verdictPoints: const ['Go.'],
      ),
    );

    expect(score.netPrimary, 210);
    expect(score.proSumPrimary, 240);
    expect(score.conSumPrimary, 30);
    expect(score.leanPercent, closeTo(88.9, 0.1));
    expect(score.strength, LeanStrength.clear);
    expect(score.headline, DecisionCopy.analysisLeanClearTo('go ahead'));
    expect(score.towardCaption, contains('toward go ahead'));
  });

  test('single close nets stay too close', () {
    final score = AnalysisScore.fromAnalysis(
      DecisionAnalysis(
        mode: DecisionMode.single,
        target: 'Move?',
        pros: [_point(80)],
        cons: [_point(70)],
        verdictPoints: const ['Wait.'],
      ),
    );

    expect(score.netPrimary, 10);
    expect(score.strength, LeanStrength.tooClose);
    expect(score.headline, DecisionCopy.analysisLeanTooClose);
    expect(score.towardCaption, DecisionCopy.analysisLeanNearlyEven);
  });

  test('comparison uses signed nets and a lean percent toward A', () {
    final score = AnalysisScore.fromAnalysis(
      const DecisionAnalysis(
        mode: DecisionMode.comparison,
        optionA: 'keep the bike',
        optionB: 'buy a car',
        optionAPros: [
          AnalysisPoint(tagline: 'Cheap', description: 'Low cost.', weight: 90),
        ],
        optionACons: [
          AnalysisPoint(tagline: 'Slow', description: 'Takes time.', weight: 20),
        ],
        optionBPros: [
          AnalysisPoint(tagline: 'Fast', description: 'Saves time.', weight: 40),
        ],
        optionBCons: [
          AnalysisPoint(tagline: 'Cost', description: 'Costs more.', weight: 80),
        ],
        verdictPoints: ['Keep the bike.'],
      ),
    );

    expect(score.netPrimary, 70);
    expect(score.netSecondary, -40);
    expect(score.leanPercent, closeTo(100, 0.1));
    expect(score.strength, LeanStrength.clear);
    expect(score.headline, DecisionCopy.analysisLeanClearTo('keep the bike'));
    expect(score.towardCaption, contains('100% toward keep the bike'));
    expect(score.trackPercent, closeTo(0, 0.1));
    expect(formatSigned(score.netPrimary), '+70');
    expect(formatSigned(score.netSecondary), '-40');
    expect(score.primaryFavorPercent, 100);
    expect(score.secondaryFavorPercent, 0);
    expect(formatLeanPercent(score.primaryFavorPercent), '100%');
  });

  test('same-sign nets share 100 percent relative to each other', () {
    final score = AnalysisScore.fromAnalysis(
      const DecisionAnalysis(
        mode: DecisionMode.comparison,
        optionA: 'stay',
        optionB: 'go',
        optionAPros: [
          AnalysisPoint(tagline: 'Known', description: 'Familiar.', weight: 20),
        ],
        optionACons: [
          AnalysisPoint(tagline: 'Cost', description: 'Costs more.', weight: 50),
        ],
        optionBPros: [
          AnalysisPoint(tagline: 'Fresh', description: 'New place.', weight: 30),
        ],
        optionBCons: [
          AnalysisPoint(tagline: 'Risk', description: 'Less sure.', weight: 40),
        ],
        verdictPoints: ['Go.'],
      ),
    );

    expect(score.netPrimary, -30);
    expect(score.netSecondary, -10);
    expect(score.primaryFavorPercent, 25);
    expect(score.secondaryFavorPercent, 75);
    expect(
      score.primaryFavorPercent + score.secondaryFavorPercent,
      100,
    );
  });

  test('comparison B win puts the marker on the right and percent toward B', () {
    final score = AnalysisScore.fromAnalysis(
      const DecisionAnalysis(
        mode: DecisionMode.comparison,
        optionA: 'buy a dog',
        optionB: 'buy a cat',
        optionAPros: [
          AnalysisPoint(tagline: 'Loyal', description: 'A friend.', weight: 20),
        ],
        optionACons: [
          AnalysisPoint(tagline: 'Walks', description: 'Hard walks.', weight: 90),
        ],
        optionBPros: [
          AnalysisPoint(tagline: 'Easy', description: 'Low effort.', weight: 90),
        ],
        optionBCons: [
          AnalysisPoint(tagline: 'Aloof', description: 'Less company.', weight: 10),
        ],
        verdictPoints: ['Pick the cat.'],
      ),
    );

    expect(score.netPrimary, -70);
    expect(score.netSecondary, 80);
    expect(score.leansPrimary, isFalse);
    expect(score.towardFavoredPercent, 100);
    expect(score.trackPercent, closeTo(100, 0.1));
    expect(score.towardCaption, contains('toward buy a cat'));
  });

  test('signed weight labels keep stored values unsigned', () {
    expect(signedWeightLabel(72, favorable: true), '+72');
    expect(signedWeightLabel(72, favorable: false), '-72');
  });

  test('aligned verdict replaces sentences that pick the losing option', () {
    const analysis = DecisionAnalysis(
      mode: DecisionMode.comparison,
      optionA: 'Holidays in Liguria',
      optionB: 'Holidays in Marche',
      optionAPros: [
        AnalysisPoint(
          tagline: 'Known reviews',
          description: 'More write-ups reduce doubt.',
          weight: 40,
        ),
      ],
      optionACons: [
        AnalysisPoint(
          tagline: 'Higher cost',
          description: 'The trip costs more.',
          weight: 45,
        ),
      ],
      optionBPros: [
        AnalysisPoint(
          tagline: 'Quieter stay',
          description: 'The pace is calmer.',
          weight: 50,
        ),
      ],
      optionBCons: [
        AnalysisPoint(
          tagline: 'Fewer write-ups',
          description: 'Less is published about it.',
          weight: 35,
        ),
      ],
      verdictPoints: [
        'Liguria has a slight edge because its reviews help ease uncertainty.',
        'Marche leaves more doubt due to fewer known details about the region.',
        'This makes option A fit the main point more closely overall.',
        'Both regions have strong points but info tips the balance to Liguria.',
        'A decision on Liguria can feel more sure in light of the uncertainty.',
      ],
    );

    final score = AnalysisScore.fromAnalysis(analysis);
    expect(score.favoredName, 'Holidays in Marche');
    expect(verdictAgreesWithScore(analysis.verdictPoints, score), isFalse);

    final aligned = alignedVerdictPoints(analysis);
    expect(aligned.first, contains('Holidays in Marche'));
    expect(aligned.join(' '), isNot(contains('slight edge')));
    expect(aligned.join(' '), isNot(contains('option A fit')));
  });

  test('aligned verdict keeps sentences that already match the score', () {
    const analysis = DecisionAnalysis(
      mode: DecisionMode.comparison,
      optionA: 'keep the bike',
      optionB: 'buy a car',
      optionAPros: [
        AnalysisPoint(tagline: 'Cheap', description: 'Low cost.', weight: 90),
      ],
      optionACons: [
        AnalysisPoint(tagline: 'Slow', description: 'Takes time.', weight: 20),
      ],
      optionBPros: [
        AnalysisPoint(tagline: 'Fast', description: 'Saves time.', weight: 40),
      ],
      optionBCons: [
        AnalysisPoint(tagline: 'Cost', description: 'Costs more.', weight: 80),
      ],
      verdictPoints: [
        'Keep the bike because it costs less each month.',
        'The car adds more monthly strain.',
        'That fits the main money point more closely.',
        'Start with what you already have.',
        'You can revisit the car later if the gap stays wide.',
      ],
    );

    expect(
      verdictAgreesWithScore(
        analysis.verdictPoints,
        AnalysisScore.fromAnalysis(analysis),
      ),
      isTrue,
    );
    expect(alignedVerdictPoints(analysis), analysis.verdictPoints);
  });
}
