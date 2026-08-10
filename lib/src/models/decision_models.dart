enum DecisionMode { single, comparison }

class AnalysisPoint {
  const AnalysisPoint({required this.title, required this.detail});

  final String title;
  final String detail;

  factory AnalysisPoint.fromJson(Map<String, dynamic> json) {
    return AnalysisPoint(
      title: (json['title'] ?? '').toString(),
      detail: (json['detail'] ?? '').toString(),
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
    List<AnalysisPoint> points(String key) {
      final raw = json[key];
      if (raw is! List) return const <AnalysisPoint>[];
      return raw
          .whereType<Map>()
          .map((e) => AnalysisPoint.fromJson(Map<String, dynamic>.from(e)))
          .where((p) => p.title.isNotEmpty && p.detail.isNotEmpty)
          .toList(growable: false);
    }

    final modeRaw = json['mode']?.toString();
    final mode =
        modeRaw == 'comparison' ? DecisionMode.comparison : DecisionMode.single;

    return DecisionAnalysis(
      mode: mode,
      target: json['target']?.toString(),
      optionA: json['optionA']?.toString(),
      optionB: json['optionB']?.toString(),
      pros: points('pros'),
      cons: points('cons'),
      optionAPros: points('optionAPros'),
      optionACons: points('optionACons'),
      optionBPros: points('optionBPros'),
      optionBCons: points('optionBCons'),
      verdictPoints: verdictPointsFromJson(json['verdict']),
    );
  }
}

/// Parses API `verdict` as a string[] (preferred) or legacy string.
List<String> verdictPointsFromJson(Object? raw) {
  if (raw is List) {
    return raw
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
  }
  if (raw is String) {
    return verdictParagraphs(raw);
  }
  return const <String>[];
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
