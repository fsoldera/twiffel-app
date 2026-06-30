import 'package:common_app_kit/common_app_kit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:uthings_app_template/src/config/app_config.dart';

void main() {
  test('license config uses template app name', () {
    expect(appLicenseConfig.appName, kAppName);
    expect(kAppName, 'My App');
  });

  test('validateTaskInput rejects self-harm', () {
    final result = validateTaskInput('i want to die');
    expect(result.isValid, isFalse);
    expect(result.reason, TaskInputRejectionReason.selfHarm);
  });
}
