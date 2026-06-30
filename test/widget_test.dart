import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:uthings_app_template/src/app.dart';

void main() {
  testWidgets('MyApp smoke test', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(const MyApp());
    await tester.pump();
    expect(find.text('My App'), findsOneWidget);
    expect(find.text('Template home screen'), findsOneWidget);
  });
}
