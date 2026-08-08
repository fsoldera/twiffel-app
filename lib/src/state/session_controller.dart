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

    // Keep the wait screen up for at least 4s even when AI returns sooner.
    const minLoading = Duration(seconds: 4);
    final remoteFuture = _ai.analyze(request);
    await Future.wait<Object?>([
      remoteFuture,
      Future<void>.delayed(minLoading),
    ]);
    final remote = await remoteFuture;
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
          AnalysisPoint(
            title: '6. Trade-offs get specific',
            detail:
                'Pros and cons stop being abstract once the action and timing are named.',
          ),
          AnalysisPoint(
            title: '7. Agency stays with you',
            detail:
                'The analysis supports your judgment rather than replacing it.',
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
          AnalysisPoint(
            title: '6. Emotional load',
            detail:
                'Replaying the choice can drain focus that could go to a small experiment.',
          ),
          AnalysisPoint(
            title: '7. Status quo drift',
            detail:
                'Doing nothing is still a choice, and it may quietly lock in by default.',
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
        AnalysisPoint(
          title: '6. Aligns with timing',
          detail:
              'If you need to decide ${request.timing.toLowerCase()}, this path can create movement.',
        ),
        AnalysisPoint(
          title: '7. Identity signal',
          detail:
              'It can express the kind of person or life you are trying to grow into.',
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
        AnalysisPoint(
          title: '6. Social ripple',
          detail:
              'People around you may need time to adjust to the change.',
        ),
        AnalysisPoint(
          title: '7. Recovery cost if wrong',
          detail:
              'If it misfits, unwinding the choice may take extra energy.',
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
        AnalysisPoint(
          title: '6. Cognitive ease',
          detail:
              'Less novelty means more bandwidth for other parts of life.',
        ),
        AnalysisPoint(
          title: '7. Steady baseline',
          detail:
              'It can be a sane holding pattern while you watch for a clearer signal.',
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
        AnalysisPoint(
          title: '6. Motivation fade',
          detail:
              'Without a new experiment, energy for the decision can drain away.',
        ),
        AnalysisPoint(
          title: '7. False calm',
          detail:
              'Short-term relief can mask a mismatch that keeps resurfacing.',
        ),
      ],
      verdict:
          'Given obstacle "${request.obstacle}" and timing "${request.timing}", compare whether '
          '"$optionA" unlocks enough upside to justify the friction versus staying with "$optionB".',
    );
  }
}
