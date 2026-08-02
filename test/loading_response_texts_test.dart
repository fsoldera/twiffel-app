import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:twiffel_app/src/copy/loading_response_texts.dart';

void main() {
  tearDown(LoadingResponseTexts.resetForTest);

  test('next returns every line once before reshuffling', () {
    LoadingResponseTexts.resetForTest(random: Random(1));

    final firstPass = <String>[
      for (var i = 0; i < LoadingResponseTexts.lines.length; i++)
        LoadingResponseTexts.next(),
    ];

    expect(firstPass.toSet(), LoadingResponseTexts.lines.toSet());
    expect(firstPass.length, LoadingResponseTexts.lines.length);

    // Second pass is a fresh shuffle of the full set.
    final secondPass = <String>[
      for (var i = 0; i < LoadingResponseTexts.lines.length; i++)
        LoadingResponseTexts.next(),
    ];
    expect(secondPass.toSet(), LoadingResponseTexts.lines.toSet());
  });

  test('next walks a provided deck in order', () {
    LoadingResponseTexts.resetForTest(
      deck: <String>['a', 'b', 'c'],
    );

    expect(LoadingResponseTexts.next(), 'a');
    expect(LoadingResponseTexts.next(), 'b');
    expect(LoadingResponseTexts.next(), 'c');
  });
}
