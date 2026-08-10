import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twiffel_app/src/copy/loading_response_texts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(LoadingResponseTexts.resetForTest);

  test('parseMarkdown reads bullet lines only', () {
    const source = '''
# Title

Edit only this file.

- First line...
- Second line...

## Notes
Not a bullet
- Third line...
''';

    expect(
      LoadingResponseTexts.parseMarkdown(source),
      <String>['First line...', 'Second line...', 'Third line...'],
    );
  });

  test('load reads the markdown asset', () async {
    await LoadingResponseTexts.load();
    expect(LoadingResponseTexts.lines, isNotEmpty);
    expect(
      LoadingResponseTexts.lines.first,
      'Twiffel is weighing the options...',
    );
    expect(
      LoadingResponseTexts.lines,
      everyElement(isNot(contains('\n'))),
    );
  });

  test('next returns every line once before reshuffling', () {
    final sample = <String>['a', 'b', 'c', 'd'];
    LoadingResponseTexts.resetForTest(
      random: Random(1),
      lines: sample,
    );

    final firstPass = <String>[
      for (var i = 0; i < sample.length; i++) LoadingResponseTexts.next(),
    ];

    expect(firstPass.toSet(), sample.toSet());
    expect(firstPass.length, sample.length);

    final secondPass = <String>[
      for (var i = 0; i < sample.length; i++) LoadingResponseTexts.next(),
    ];
    expect(secondPass.toSet(), sample.toSet());
  });

  test('next walks a provided deck in order', () {
    LoadingResponseTexts.resetForTest(
      lines: <String>['a', 'b', 'c'],
      deck: <String>['a', 'b', 'c'],
    );

    expect(LoadingResponseTexts.next(), 'a');
    expect(LoadingResponseTexts.next(), 'b');
    expect(LoadingResponseTexts.next(), 'c');
  });

  test('asset path is registered', () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    expect(
      manifest.listAssets(),
      contains(LoadingResponseTexts.assetPath),
    );
  });
}
