import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:twiffel_app/src/models/decision_models.dart';
import 'package:twiffel_app/src/services/report_pdf_builder.dart';

List<AnalysisPoint> _points(String kind, int count) {
  return List<AnalysisPoint>.generate(
    count,
    (index) => AnalysisPoint(
      tagline: '$kind ${index + 1}: a longer title that may wrap in narrow columns',
      description:
          '$kind ${index + 1} detail for the Twiffel PDF report. '
          'This sentence is intentionally long so two-column layouts exercise '
          'MultiPage pagination instead of packing everything into one unsplittable widget.',
      weight: 90 - index * 8,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('builds a comparison PDF with option sections', () async {
    final bytes = await ReportPdfBuilder.build(
      DecisionAnalysis(
        optionA: 'Turbo plan',
        optionB: 'Standard plan',
        optionAPros: _points('A Pro', 7),
        optionACons: _points('A Con', 7),
        optionBPros: _points('B Pro', 7),
        optionBCons: _points('B Con', 7),
        verdictPoints: const [
          'Turbo has a slight edge if timing is tight.',
          'Steady wins if you need lower risk right now.',
          'Use the obstacle as the tie-breaker.',
          'A small test beats endless comparison.',
          'If neither clears the blocker, wait.',
        ],
      ),
    );

    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('US locale PDF uses Letter page size', () async {
    final bytes = await ReportPdfBuilder.build(
      DecisionAnalysis(
        optionA: 'Turbo plan',
        optionB: 'Standard plan',
        optionAPros: _points('A Pro', 1),
        optionACons: _points('A Con', 1),
        optionBPros: _points('B Pro', 1),
        optionBCons: _points('B Con', 1),
        verdictPoints: const ['Keep it simple.'],
      ),
      locale: const Locale('en', 'US'),
    );

    final pdf = String.fromCharCodes(bytes);
    expect(pdf.contains('612'), isTrue);
    expect(pdf.contains('792'), isTrue);
  });

  test('filename matches the email subject, with file-safe date and time', () async {
    final when = DateTime(2026, 8, 3, 19, 13, 45);

    final us = await ReportPdfBuilder.filenameFor(
      at: when,
      locale: const Locale('en', 'US'),
    );
    expect(us, 'Twiffel results 8-3-2026 7-13-45 PM.pdf');

    final it = await ReportPdfBuilder.filenameFor(
      at: when,
      locale: const Locale('it', 'IT'),
    );
    expect(it, 'Twiffel results 03-08-2026 19-13-45.pdf');
  });

  test('share subject uses Twiffel results prefix with locale date and time', () async {
    final when = DateTime(2026, 8, 3, 19, 13, 45);

    final us = await ReportPdfBuilder.shareSubjectFor(
      at: when,
      locale: const Locale('en', 'US'),
    );
    expect(us, 'Twiffel results 8/3/2026 7:13:45\u202FPM');

    final it = await ReportPdfBuilder.shareSubjectFor(
      at: when,
      locale: const Locale('it', 'IT'),
    );
    expect(it, 'Twiffel results 03/08/2026 19:13:45');
  });
}
