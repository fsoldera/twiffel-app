import 'package:common_app_kit/common_app_kit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:twiffel_app/src/config/app_config.dart';

void main() {
  test('license config uses Twiffel app name', () {
    expect(appLicenseConfig.appName, kAppName);
    expect(kAppName, 'Twiffel');
  });

  test('validateTaskInput rejects self-harm', () {
    final result = validateTaskInput('i want to die');
    expect(result.isValid, isFalse);
    expect(result.reason, TaskInputRejectionReason.selfHarm);
  });
}
