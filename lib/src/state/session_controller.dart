import 'package:common_app_kit/common_app_kit.dart';
import 'package:flutter/foundation.dart';

import '../models/decision_models.dart';
import '../services/ai_client.dart';
import '../services/analytics.dart';

enum SessionPhase { input, loading, ready, error }

/// Twiffel decision session: structured form input -> analysis result.
class SessionController extends ChangeNotifier {
  SessionController({
    required LicenseController license,
    AiClient? ai,
    Analytics? analytics,
  })  : _license = license,
        _ai = ai ?? AiClient(),
        _analytics = analytics ?? Analytics();

  final LicenseController _license;
  final AiClient _ai;
  final Analytics _analytics;

  SessionPhase _phase = SessionPhase.input;
  DecisionRequest? _request;
  DecisionAnalysis? _analysis;
  String? _inputError;

  SessionPhase get phase => _phase;
  DecisionRequest? get request => _request;
  DecisionAnalysis? get analysis => _analysis;
  String? get inputError => _inputError;

  Future<void> submitDecision(DecisionRequest request) async {
    final validation = validateTaskInput(request.validationText);
    if (!validation.isValid) {
      _inputError = validation.message;
      _phase = SessionPhase.error;
      _analysis = null;
      notifyListeners();
      return;
    }

    _inputError = null;
    _request = request;
    _analysis = null;
    _phase = SessionPhase.loading;
    notifyListeners();

    await _license.recordUse();
    _analytics.track('generate_request');

    final remote = await _ai.analyze(request);
    _analysis = remote ?? _localFallback(request);
    _phase = SessionPhase.ready;
    notifyListeners();
  }

  void reset() {
    _phase = SessionPhase.input;
    _request = null;
    _analysis = null;
    _inputError = null;
    notifyListeners();
  }

  DecisionAnalysis _localFallback(DecisionRequest request) {
    if (request.mode == DecisionMode.single) {
      final target = request.target ?? 'this decision';
      return DecisionAnalysis(
        mode: DecisionMode.single,
        target: target,
        pros: [
          AnalysisPoint(
            title: '1. Clearer direction',
            detail:
                'Naming "$target" makes the choice concrete enough to evaluate honestly.',
          ),
          AnalysisPoint(
            title: '2. Timeline awareness',
            detail:
                'Wanting this ${request.timing.toLowerCase()} helps you weigh urgency against waiting costs.',
          ),
          AnalysisPoint(
            title: '3. Obstacle is named',
            detail:
                'Focusing on "${request.obstacle}" keeps the analysis practical instead of vague worry.',
          ),
        ],
        cons: [
          AnalysisPoint(
            title: '1. Real trade-offs remain',
            detail:
                'Moving ahead on "$target" still means accepting costs, effort, or uncertainty.',
          ),
          AnalysisPoint(
            title: '2. Waiting has a cost too',
            detail:
                'Delaying can feel safer, but it may quietly spend time, energy, or opportunity.',
          ),
          AnalysisPoint(
            title: '3. Ambiguity can return',
            detail:
                'Without a next checkpoint, the same doubts are likely to resurface.',
          ),
        ],
        verdict:
            'Based on your timing (${request.timing}) and main obstacle (${request.obstacle}), '
            '"$target" looks worth a careful next step, not a rushed leap.',
      );
    }

    final optionA = request.optionA ?? 'Option A';
    final optionB = request.optionB ?? 'Option B';
    return DecisionAnalysis(
      mode: DecisionMode.comparison,
      optionA: optionA,
      optionB: optionB,
      optionAPros: [
        AnalysisPoint(
          title: '1. Forward movement',
          detail:
              '"$optionA" is the more change-oriented path if you want momentum.',
        ),
        AnalysisPoint(
          title: '2. Matches stated desire',
          detail: 'It may better reflect what you already feel drawn toward.',
        ),
        AnalysisPoint(
          title: '3. Forces clarity',
          detail:
              'Choosing it creates a concrete plan you can test against reality.',
        ),
      ],
      optionACons: [
        AnalysisPoint(
          title: '1. Higher friction',
          detail:
              'Obstacle "${request.obstacle}" may hit this option harder at first.',
        ),
        AnalysisPoint(
          title: '2. Commitment pressure',
          detail: 'It can feel harder to reverse if the early weeks are rocky.',
        ),
        AnalysisPoint(
          title: '3. Upfront cost',
          detail: 'Time, money, or effort may spike before benefits appear.',
        ),
      ],
      optionBPros: [
        AnalysisPoint(
          title: '1. Continuity',
          detail:
              '"$optionB" preserves stability while you gather more information.',
        ),
        AnalysisPoint(
          title: '2. Lower immediate stress',
          detail:
              'It may reduce short-term pressure around your main obstacle.',
        ),
        AnalysisPoint(
          title: '3. Room to prepare',
          detail:
              'You can strengthen finances, timing, or confidence before a bigger move.',
        ),
      ],
      optionBCons: [
        AnalysisPoint(
          title: '1. Delayed progress',
          detail: 'Staying put can quietly extend the indecision window.',
        ),
        AnalysisPoint(
          title: '2. Opportunity cost',
          detail:
              'If timing is "${request.timing}", waiting may conflict with your preferred window.',
        ),
        AnalysisPoint(
          title: '3. Habit lock-in',
          detail:
              'The status quo can become harder to leave the longer it continues.',
        ),
      ],
      verdict:
          'Given obstacle "${request.obstacle}" and timing "${request.timing}", compare whether '
          '"$optionA" unlocks enough upside to justify the friction versus staying with "$optionB".',
    );
  }
}
