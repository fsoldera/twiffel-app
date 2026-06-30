import 'package:common_app_kit/common_app_kit.dart';
import 'package:flutter/foundation.dart';

import '../services/ai_client.dart';
import '../services/analytics.dart';

enum SessionPhase { input, loading, ready, error }

/// Minimal example state machine. Replace with your app's flow.
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
  String _input = '';
  String? _inputError;
  List<String> _steps = const <String>[];

  SessionPhase get phase => _phase;
  String get input => _input;
  String? get inputError => _inputError;
  List<String> get steps => _steps;

  Future<void> submit(String raw) async {
    final text = raw.trim();
    final validation = validateTaskInput(text);
    if (!validation.isValid) {
      _inputError = validation.message;
      _phase = SessionPhase.error;
      _steps = const <String>[];
      notifyListeners();
      return;
    }
    if (text.isEmpty) return;

    _inputError = null;
    _input = text;
    _phase = SessionPhase.loading;
    notifyListeners();

    await _license.recordUse();
    _analytics.track('generate_request');

    final remote = await _ai.generateSteps(text);
    if (remote != null) {
      final safe = remote.where(isSafePracticalStep).toList(growable: false);
      _steps = safe.length >= 3 ? safe.take(3).toList(growable: false) : _localFallbackSteps();
    } else {
      _steps = _localFallbackSteps();
    }

    _phase = SessionPhase.ready;
    notifyListeners();
  }

  void reset() {
    _phase = SessionPhase.input;
    _input = '';
    _inputError = null;
    _steps = const <String>[];
    notifyListeners();
  }

  List<String> _localFallbackSteps() => const <String>[
        'Stand up and move to where you can begin.',
        'Gather one thing you need.',
        'Do one small action for 30 seconds.',
      ];
}
