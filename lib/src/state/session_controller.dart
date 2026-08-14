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
  int _submitGeneration = 0;

  SessionPhase get phase => _phase;
  DecisionRequest? get request => _request;
  DecisionAnalysis? get analysis => _analysis;
  String? get inputError => _inputError;

  Future<void> submitDecision(DecisionRequest request) async {
    // Content-safety on every free-text field before any AI call.
    final texts = <String>[
      if (request.target != null && request.target!.trim().isNotEmpty)
        request.target!.trim(),
      if (request.optionA != null && request.optionA!.trim().isNotEmpty)
        request.optionA!.trim(),
      if (request.optionB != null && request.optionB!.trim().isNotEmpty)
        request.optionB!.trim(),
      request.obstacle.trim(),
      request.timing.trim(),
    ];
    for (final text in texts) {
      final validation = validateTaskInput(text);
      if (!validation.isValid) {
        _inputError = validation.message;
        _phase = SessionPhase.error;
        _analysis = null;
        notifyListeners();
        return;
      }
    }

    final generation = ++_submitGeneration;
    _inputError = null;
    _request = request;
    _analysis = null;
    _phase = SessionPhase.loading;
    notifyListeners();

    await _license.recordUse();
    _analytics.track('generate_request');

    // Keep the wait screen up for at least 4s even when AI returns sooner.
    const minLoading = Duration(seconds: 4);
    final remoteFuture = _ai.analyze(request);
    await Future.wait<Object?>([
      remoteFuture,
      Future<void>.delayed(minLoading),
    ]);
    if (generation != _submitGeneration) return;
    final outcome = await remoteFuture;
    if (generation != _submitGeneration) return;
    if (outcome.analysis != null) {
      _analysis = outcome.analysis;
      _phase = SessionPhase.ready;
    } else if (!_ai.isConfigured || outcome.transportFailed) {
      _analysis = _localFallback(request);
      _phase = SessionPhase.ready;
    } else {
      _analysis = null;
      _inputError = outcome.errorMessage;
      _phase = SessionPhase.error;
    }
    notifyListeners();
  }

  /// Abandon an in-flight analysis. Late AI results are ignored.
  void cancelAnalysis() {
    if (_phase != SessionPhase.loading) return;
    _submitGeneration++;
    reset();
  }

  void reset() {
    _phase = SessionPhase.input;
    _request = null;
    _analysis = null;
    _inputError = null;
    notifyListeners();
  }

  @visibleForTesting
  void debugSetReady(DecisionAnalysis analysis) {
    _analysis = analysis;
    _phase = SessionPhase.ready;
    _inputError = null;
    notifyListeners();
  }

  DecisionAnalysis _localFallback(DecisionRequest request) {
    if (request.mode == DecisionMode.single) {
      final target = request.target ?? 'this decision';
      final timing = request.timing.toLowerCase();
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
                'Wanting this $timing helps you weigh urgency against waiting costs.',
          ),
          AnalysisPoint(
            title: '3. Obstacle is named',
            detail:
                'Focusing on "${request.obstacle}" keeps the analysis practical instead of vague worry.',
          ),
          AnalysisPoint(
            title: '4. Values come into view',
            detail:
                'Working through "$target" surfaces what you care about protecting most.',
          ),
          AnalysisPoint(
            title: '5. Decision becomes testable',
            detail:
                'You can define a small next check instead of staying in mental loops.',
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
          AnalysisPoint(
            title: '4. Obstacle may intensify',
            detail:
                'If "${request.obstacle}" is ignored, pressure can grow even while you wait.',
          ),
          AnalysisPoint(
            title: '5. Perfect certainty is unlikely',
            detail:
                'You may never feel 100% ready, so waiting for that signal can stall you.',
          ),
        ],
        verdictPoints: [
          'Based on your timing (${request.timing}) and main obstacle (${request.obstacle}), "$target" deserves a clear lean.',
          'The named obstacle is real, so treat it as the main constraint rather than a vague worry.',
          'A careful next step beats waiting for perfect certainty that may never arrive.',
          'Keep the move small enough to reverse if early feedback looks wrong.',
          'If the obstacle still blocks every path, waiting is wiser than forcing a leap.',
        ],
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
        AnalysisPoint(
          title: '4. Learning speed',
          detail:
              'You get faster feedback on whether this path fits your real constraints.',
        ),
        AnalysisPoint(
          title: '5. Motivational lift',
          detail:
              'Acting on the option you lean toward can reduce rumination.',
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
        AnalysisPoint(
          title: '4. Transition stress',
          detail:
              'Changing lanes often adds temporary chaos even when the destination is good.',
        ),
        AnalysisPoint(
          title: '5. Over-optimism risk',
          detail:
              'Excitement can underweight practical blockers you already named.',
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
        AnalysisPoint(
          title: '4. Familiar systems',
          detail: 'Existing routines and tools already support this path.',
        ),
        AnalysisPoint(
          title: '5. Reversible by default',
          detail:
              'Staying closer to the status quo usually keeps more exit options open.',
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
        AnalysisPoint(
          title: '4. Quiet regret risk',
          detail:
              'You may later wish you had tested the other path sooner.',
        ),
        AnalysisPoint(
          title: '5. Obstacle persists',
          detail:
              'Avoiding change does not dissolve "${request.obstacle}" by itself.',
        ),
      ],
      verdictPoints: [
        'Given obstacle "${request.obstacle}" and timing "${request.timing}", weigh "$optionA" against "$optionB" with a clear lean.',
        '"$optionA" wins if the upside clearly outruns the friction you already named.',
        '"$optionB" wins if stability and lower stress matter more in this window.',
        'Use the obstacle as the tie-breaker instead of chasing a perfect feeling.',
        'If neither option clears the obstacle soon enough, waiting is the wiser call.',
      ],
    );
  }
}
