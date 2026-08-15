import 'package:common_app_kit/common_app_kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:twiffel_app/src/config/app_config.dart';
import 'package:twiffel_app/src/models/decision_models.dart';
import 'package:twiffel_app/src/pages/decision_copy.dart';
import 'package:twiffel_app/src/state/session_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cancelAnalysis ignores late submit results', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final license = LicenseController(appLicenseConfig);
    await license.init();
    final session = SessionController(license: license);

    final submit = session.submitDecision(
      const DecisionRequest(
        mode: DecisionMode.comparison,
        optionA: 'buy a dog',
        optionB: 'buy a cat',
        obstacle: 'Cost / money',
        timing: DecisionCopy.timingAsap,
      ),
    );

    // Allow the controller to enter loading.
    await Future<void>.delayed(Duration.zero);
    expect(session.phase, SessionPhase.loading);

    session.cancelAnalysis();
    expect(session.phase, SessionPhase.input);
    expect(session.analysis, isNull);

    await submit;
    expect(session.phase, SessionPhase.input);
    expect(session.analysis, isNull);
  });
}
