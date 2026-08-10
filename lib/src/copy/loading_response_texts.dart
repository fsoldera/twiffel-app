import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One loading line per analysis request, drawn from a shuffled deck.
///
/// Source of truth: [assetPath]. Edit only that markdown file.
class LoadingResponseTexts {
  LoadingResponseTexts._();

  static const assetPath = 'assets/copy/loading_response_texts.md';

  static const String _fallbackLine = 'Twiffel is weighing the options...';

  static List<String> _lines = const <String>[];
  static List<String>? _deck;
  static int _cursor = 0;
  static Random _random = Random();

  /// Lines loaded from the markdown asset (empty before [load]).
  static List<String> get lines => List<String>.unmodifiable(_lines);

  /// Parses `- bullet` lines from the markdown source.
  @visibleForTesting
  static List<String> parseMarkdown(String source) {
    final parsed = <String>[];
    for (final raw in source.split('\n')) {
      final line = raw.trim();
      if (!line.startsWith('- ')) continue;
      final text = line.substring(2).trim();
      if (text.isNotEmpty) parsed.add(text);
    }
    return parsed;
  }

  /// Load bullets from [assetPath]. Call once at app startup.
  static Future<void> load({AssetBundle? bundle}) async {
    final raw = await (bundle ?? rootBundle).loadString(assetPath);
    applyLoadedLines(parseMarkdown(raw));
  }

  @visibleForTesting
  static void applyLoadedLines(List<String> loaded) {
    _lines = List<String>.of(loaded);
    _deck = null;
    _cursor = 0;
  }

  /// Next line from the shuffled deck (reshuffles when exhausted).
  static String next() {
    if (_lines.isEmpty) return _fallbackLine;
    if (_deck == null || _cursor >= _deck!.length) {
      _reshuffle();
    }
    return _deck![_cursor++];
  }

  static void _reshuffle() {
    _deck = List<String>.of(_lines)..shuffle(_random);
    _cursor = 0;
  }

  @visibleForTesting
  static void resetForTest({
    Random? random,
    List<String>? deck,
    List<String>? lines,
  }) {
    _random = random ?? Random();
    if (lines != null) {
      _lines = List<String>.of(lines);
    }
    _deck = deck;
    _cursor = 0;
  }
}
