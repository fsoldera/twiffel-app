import 'package:flutter_test/flutter_test.dart';

import 'package:twiffel_app/src/models/analysis_score.dart';
import 'package:twiffel_app/src/models/decision_models.dart';
import 'package:twiffel_app/src/pages/decision_copy.dart';

void main() {
  test('comparison uses signed nets and a lean percent toward A', () {
    final score = AnalysisScore.fromAnalysis(
      const DecisionAnalysis(
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
    expect(score.leanPercent, closeTo(86.23, 0.1));
    expect(score.strength, LeanStrength.clear);
    expect(score.headline, DecisionCopy.analysisLeanClearTo('keep the bike'));
    expect(score.towardCaption, contains('86% toward keep the bike'));
    expect(score.trackPercent, closeTo(13.77, 0.1));
    expect(formatSigned(score.netPrimary), '+70');
    expect(formatSigned(score.netSecondary), '-40');
    expect(score.primaryFavorPercent, 86);
    expect(score.secondaryFavorPercent, 14);
    expect(formatLeanPercent(score.primaryFavorPercent), '86%');
  });

  test('mixed lists keep a leftover share for the weaker option', () {
    final score = AnalysisScore.fromAnalysis(
      const DecisionAnalysis(
        optionA: 'buy an apple',
        optionB: 'buy a croissant',
        optionAPros: [
          AnalysisPoint(
            tagline: 'Healthy',
            description: 'Better fuel.',
            weight: 90,
          ),
        ],
        optionACons: [
          AnalysisPoint(
            tagline: 'Plain',
            description: 'Less treat.',
            weight: 20,
          ),
        ],
        optionBPros: [
          AnalysisPoint(
            tagline: 'Tasty',
            description: 'A treat.',
            weight: 40,
          ),
        ],
        optionBCons: [
          AnalysisPoint(
            tagline: 'Heavy',
            description: 'Less healthy.',
            weight: 80,
          ),
        ],
        verdictPoints: ['Buy an apple.'],
      ),
    );

    expect(score.primaryFavorPercent, 86);
    expect(score.secondaryFavorPercent, 14);
  });

  test('100 percent only when one option has no cons and the other has no pros',
      () {
    final score = AnalysisScore.fromAnalysis(
      const DecisionAnalysis(
        optionA: 'clear winner',
        optionB: 'no upside',
        optionAPros: [
          AnalysisPoint(tagline: 'Strong', description: 'All upside.', weight: 80),
        ],
        optionBCons: [
          AnalysisPoint(tagline: 'Weak', description: 'All downside.', weight: 20),
        ],
        verdictPoints: ['Pick the winner.'],
      ),
    );

    expect(score.primaryFavorPercent, 100);
    expect(score.secondaryFavorPercent, 0);
  });

  test('strong log stretch turns a linear 48/52 split into 43/57', () {
    expect(compressFavorPercent(52), closeTo(56.68, 0.05));
    expect(compressFavorPercent(48), closeTo(43.32, 0.05));
    expect(compressFavorPercent(50), 50);
    expect(compressFavorPercent(100), 100);
    expect(compressFavorPercent(0), 0);

    final score = AnalysisScore.fromAnalysis(
      const DecisionAnalysis(
        optionA: 'buy a dog',
        optionB: 'buy a cat',
        optionAPros: [
          AnalysisPoint(tagline: 'Loyal', description: 'A friend.', weight: 46),
        ],
        optionACons: [
          AnalysisPoint(tagline: 'Walks', description: 'Hard walks.', weight: 54),
        ],
        optionBPros: [
          AnalysisPoint(tagline: 'Easy', description: 'Low effort.', weight: 50),
        ],
        optionBCons: [
          AnalysisPoint(tagline: 'Aloof', description: 'Less company.', weight: 50),
        ],
        verdictPoints: ['Very close.'],
      ),
    );

    expect(score.primaryFavorPercent, 43);
    expect(score.secondaryFavorPercent, 57);
    expect(score.strength, LeanStrength.tooClose);
    expect(score.headline, DecisionCopy.analysisLeanTooClose);
  });

  test('same-sign nets share 100 percent relative to each other', () {
    final score = AnalysisScore.fromAnalysis(
      const DecisionAnalysis(
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
    expect(score.primaryFavorPercent, 32);
    expect(score.secondaryFavorPercent, 68);
    expect(
      score.primaryFavorPercent + score.secondaryFavorPercent,
      100,
    );
  });

  test('comparison B win puts the marker on the right and percent toward B', () {
    final score = AnalysisScore.fromAnalysis(
      const DecisionAnalysis(
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
    expect(score.leanPercent, closeTo(6.45, 0.1));
    expect(score.towardFavoredPercent, 94);
    expect(score.trackPercent, closeTo(93.55, 0.1));
    expect(score.towardCaption, contains('toward buy a cat'));
  });

  test('weight sign marks map 20-point steps from 1 to 5', () {
    expect(weightSignCount(1), 1);
    expect(weightSignCount(20), 1);
    expect(weightSignCount(21), 2);
    expect(weightSignCount(40), 2);
    expect(weightSignCount(80), 4);
    expect(weightSignCount(81), 5);
    expect(weightSignCount(100), 5);
    expect(weightSignLabel(90, favorable: true), '+++++');
    expect(weightSignLabel(20, favorable: false), '-');
    expect(weightSignLabel(80, favorable: false), '----');
  });

  test('aligned verdict replaces sentences that pick the losing option', () {
    const analysis = DecisionAnalysis(
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
          weight: 80,
        ),
      ],
      optionBPros: [
        AnalysisPoint(
          tagline: 'Quieter stay',
          description: 'The pace is calmer.',
          weight: 90,
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
