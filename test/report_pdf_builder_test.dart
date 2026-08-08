import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:twiffel_app/src/models/decision_models.dart';
import 'package:twiffel_app/src/services/report_pdf_builder.dart';

List<AnalysisPoint> _points(String kind, int count) {
  return List<AnalysisPoint>.generate(
    count,
    (index) => AnalysisPoint(
      title: '$kind ${index + 1}: a longer title that may wrap in narrow columns',
      detail:
          '$kind ${index + 1} detail for the Twiffel PDF report. '
          'This sentence is intentionally long so two-column layouts exercise '
          'MultiPage pagination instead of packing everything into one unsplittable widget.',
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('builds a single-choice PDF with 7 pros and 7 cons', () async {
    final bytes = await ReportPdfBuilder.build(
      DecisionAnalysis(
        mode: DecisionMode.single,
        target: 'Should I buy the MacBook Pro 16?',
        pros: _points('Pro', 7),
        cons: _points('Con', 7),
        verdict: 'A careful next step beats a rushed leap.',
      ),
    );

    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('builds a comparison PDF with option sections', () async {
    final bytes = await ReportPdfBuilder.build(
      DecisionAnalysis(
        mode: DecisionMode.comparison,
        optionA: 'Turbo plan',
        optionB: 'Standard plan',
        optionAPros: _points('A Pro', 7),
        optionACons: _points('A Con', 7),
        optionBPros: _points('B Pro', 7),
        optionBCons: _points('B Con', 7),
        verdict: 'Turbo has a slight edge if timing is tight.',
      ),
    );

    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('filename uses Twiffel_results prefix with locale date and time', () async {
    final when = DateTime(2026, 8, 3, 19, 13, 45);

    final us = await ReportPdfBuilder.filenameFor(
      at: when,
      locale: const Locale('en', 'US'),
    );
    expect(us, 'Twiffel_results_8-3-2026_7-13-45_PM.pdf');

    final it = await ReportPdfBuilder.filenameFor(
      at: when,
      locale: const Locale('it', 'IT'),
    );
    expect(it, 'Twiffel_results_03-08-2026_19-13-45.pdf');
  });
}
