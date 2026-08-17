import 'dart:convert';

class AnalysisPoint {
  const AnalysisPoint({
    required this.tagline,
    required this.description,
    required this.weight,
  });

  final String tagline;
  final String description;

  /// Importance of this point in the evaluation, from 1 (weak) to 100 (decisive).
  final int weight;

  /// Legacy alias used by older UI helpers.
  String get title => tagline;

  /// Legacy alias used by older UI helpers.
  String get detail => description;

  factory AnalysisPoint.fromJson(Map<String, dynamic> json) {
    final tagline = _jsonString(json, const [
      'tagline',
      'title',
      'heading',
      'label',
    ]);
    final description = _jsonString(json, const [
      'description',
      'detail',
      'text',
      'body',
      'content',
    ]);
    final weight = _jsonWeight(json);
    if (tagline.isEmpty || description.isEmpty || weight == null) {
      throw const FormatException('Analysis point must have tagline, description, and weight.');
    }
    return AnalysisPoint(
      tagline: tagline,
      description: description,
      weight: weight,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'tagline': tagline,
        'description': description,
        'weight': weight,
      };
}

class DecisionRequest {
  const DecisionRequest({
    required this.optionA,
    required this.optionB,
    required this.obstacle,
    required this.timing,
  });

  final String optionA;
  final String optionB;
  final String obstacle;
  final String timing;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'mode': 'comparison',
        'optionA': optionA,
        'optionB': optionB,
        'obstacle': obstacle,
        'timing': timing,
      };

  String get validationText => '$optionA $optionB';
}

class DecisionAnalysis {
  const DecisionAnalysis({
    required this.optionA,
    required this.optionB,
    required this.verdictPoints,
    this.optionAPros = const <AnalysisPoint>[],
    this.optionACons = const <AnalysisPoint>[],
    this.optionBPros = const <AnalysisPoint>[],
    this.optionBCons = const <AnalysisPoint>[],
  });

  final String optionA;
  final String optionB;
  final List<AnalysisPoint> optionAPros;
  final List<AnalysisPoint> optionACons;
  final List<AnalysisPoint> optionBPros;
  final List<AnalysisPoint> optionBCons;

  /// Exactly the bullet lines shown in the UI (prefer API array, no re-split).
  final List<String> verdictPoints;

  /// Joined form for PDF / legacy helpers.
  String get verdict => verdictPoints.join('\n\n');

  factory DecisionAnalysis.fromJson(Map<String, dynamic> json) {
    List<AnalysisPoint> points(List<String> keys) {
      for (final key in keys) {
        final raw = json[key];
        if (raw is! List) continue;
        final parsed = raw
            .whereType<Map>()
            .map((e) {
              try {
                return AnalysisPoint.fromJson(Map<String, dynamic>.from(e));
              } on FormatException {
                return null;
              }
            })
            .whereType<AnalysisPoint>()
            .toList();
        if (parsed.isEmpty) continue;
        parsed.sort((a, b) => b.weight.compareTo(a.weight));
        return List<AnalysisPoint>.unmodifiable(parsed);
      }
      return const <AnalysisPoint>[];
    }

    return DecisionAnalysis(
      optionA: json['optionA']?.toString() ?? json['option_a']?.toString() ?? '',
      optionB: json['optionB']?.toString() ?? json['option_b']?.toString() ?? '',
      optionAPros: points(const ['optionAPros', 'option_a_pros']),
      optionACons: points(const ['optionACons', 'option_a_cons']),
      optionBPros: points(const ['optionBPros', 'option_b_pros']),
      optionBCons: points(const ['optionBCons', 'option_b_cons']),
      verdictPoints: verdictPointsFromJson(json['verdict']),
    );
  }
}

/// Pulls the analysis object from `{ "analysis": ... }` or a bare analysis map.
Map<String, dynamic> unwrapAnalysisMap(Map<dynamic, dynamic> data) {
  final analysis = data['analysis'];
  if (analysis is Map) {
    return Map<String, dynamic>.from(analysis);
  }
  if (analysis is String) {
    final decoded = jsonDecode(analysis);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  }
  return Map<String, dynamic>.from(data);
}

String _jsonString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return '';
}

int? _jsonWeight(Map<String, dynamic> json) {
  final raw = json['weight'] ?? json['score'];
  int? parsed;
  if (raw is int) {
    parsed = raw;
  } else if (raw is num) {
    parsed = raw.round();
  } else if (raw is String) {
    parsed = int.tryParse(raw.trim());
  }
  if (parsed == null) return null;
  if (parsed < 1 || parsed > 100) return parsed.clamp(1, 100);
  return parsed;
}

/// Parses API `verdict` as a string[] (preferred) or legacy string.
List<String> verdictPointsFromJson(Object? raw) {
  if (raw is List) {
    return raw
        .map(_verdictItemToString)
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
  }
  if (raw is String) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('[')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          return verdictPointsFromJson(decoded);
        }
      } catch (_) {
        // Fall through to paragraph split.
      }
    }
    return verdictParagraphs(raw);
  }
  return const <String>[];
}

String _verdictItemToString(Object? item) {
  if (item is String) return item.trim();
  if (item is Map) {
    final map = Map<String, dynamic>.from(item);
    return _jsonString(map, const ['text', 'sentence', 'content', 'detail', 'verdict']);
  }
  return item?.toString().trim() ?? '';
}

/// Legacy splitter for string verdicts (newline-separated, else sentences).
List<String> verdictParagraphs(String verdict) {
  final trimmed = verdict.trim();
  if (trimmed.isEmpty) return const <String>[];
  if (trimmed.contains('\n')) {
    return trimmed
        .split(RegExp(r'\n+'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
  }
  return trimmed
      .split(RegExp(r'(?<=[.!?])\s+'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
}
