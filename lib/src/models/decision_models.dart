import 'dart:convert';

enum DecisionMode { single, comparison }

class AnalysisPoint {
  const AnalysisPoint({required this.title, required this.detail});

  final String title;
  final String detail;

  factory AnalysisPoint.fromJson(Map<String, dynamic> json) {
    return AnalysisPoint(
      title: _jsonString(json, const ['title', 'heading', 'label']),
      detail: _jsonString(json, const ['detail', 'text', 'body', 'content']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'detail': detail,
      };
}

class DecisionRequest {
  const DecisionRequest({
    required this.mode,
    required this.obstacle,
    required this.timing,
    this.target,
    this.optionA,
    this.optionB,
  });

  final DecisionMode mode;
  final String? target;
  final String? optionA;
  final String? optionB;
  final String obstacle;
  final String timing;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'mode': mode == DecisionMode.single ? 'single' : 'comparison',
        if (target != null) 'target': target,
        if (optionA != null) 'optionA': optionA,
        if (optionB != null) 'optionB': optionB,
        'obstacle': obstacle,
        'timing': timing,
      };

  String get validationText {
    if (mode == DecisionMode.single) return target ?? '';
    return '${optionA ?? ''} ${optionB ?? ''}';
  }
}

class DecisionAnalysis {
  const DecisionAnalysis({
    required this.mode,
    required this.verdictPoints,
    this.target,
    this.optionA,
    this.optionB,
    this.pros = const <AnalysisPoint>[],
    this.cons = const <AnalysisPoint>[],
    this.optionAPros = const <AnalysisPoint>[],
    this.optionACons = const <AnalysisPoint>[],
    this.optionBPros = const <AnalysisPoint>[],
    this.optionBCons = const <AnalysisPoint>[],
  });

  final DecisionMode mode;
  final String? target;
  final String? optionA;
  final String? optionB;
  final List<AnalysisPoint> pros;
  final List<AnalysisPoint> cons;
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
            .map((e) => AnalysisPoint.fromJson(Map<String, dynamic>.from(e)))
            .where((p) => p.title.isNotEmpty && p.detail.isNotEmpty)
            .toList(growable: false);
        if (parsed.isNotEmpty) return parsed;
      }
      return const <AnalysisPoint>[];
    }

    final modeRaw = json['mode']?.toString();
    final mode =
        modeRaw == 'comparison' ? DecisionMode.comparison : DecisionMode.single;

    return DecisionAnalysis(
      mode: mode,
      target: json['target']?.toString(),
      optionA: json['optionA']?.toString() ?? json['option_a']?.toString(),
      optionB: json['optionB']?.toString() ?? json['option_b']?.toString(),
      pros: points(const ['pros']),
      cons: points(const ['cons']),
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
